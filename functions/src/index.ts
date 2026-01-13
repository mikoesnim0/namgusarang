import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import axios from "axios";

admin.initializeApp();

/**
 * Callable: authWithKakao
 * Request: { accessToken: string }
 * Response: { firebaseToken: string }
 *
 * Region must match the client: asia-northeast3
 */
export const authWithKakao = functions
  .region("asia-northeast3")
  .https.onCall(async (data) => {
    const accessToken = data?.accessToken;
    if (typeof accessToken !== "string" || accessToken.length === 0) {
      throw new functions.https.HttpsError("invalid-argument", "Token missing");
    }

    try {
      // 1) Verify Kakao token by calling Kakao API
      let kakaoRes;
      try {
        kakaoRes = await axios.get("https://kapi.kakao.com/v2/user/me", {
          headers: { Authorization: `Bearer ${accessToken}` },
          timeout: 10_000,
        });
      } catch (e: any) {
        const status = e?.response?.status;
        const kakaoBody = e?.response?.data;
        // Don't log the access token. Log only status/body for debugging.
        console.error("Kakao token verify failed", {
          status,
          kakaoBody,
        });

        if (status === 401) {
          throw new functions.https.HttpsError(
            "unauthenticated",
            "Invalid Kakao access token (401). Check Kakao app settings (bundle id / key hash) and try again."
          );
        }
        if (status === 403) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "Kakao token rejected (403). Check Kakao app settings/permissions."
          );
        }
        throw new functions.https.HttpsError(
          "internal",
          "Failed to verify Kakao token.",
          {
            status,
            kakaoBody,
          }
        );
      }

      const kakaoUser = kakaoRes.data as {
        id: string | number;
        kakao_account?: {
          email?: string;
          profile?: {
            nickname?: string;
            thumbnail_image_url?: string;
          };
        };
      };

      if (kakaoUser?.id === undefined || kakaoUser?.id === null) {
        throw new functions.https.HttpsError(
          "internal",
          "Kakao user id missing from /v2/user/me response.",
          { kakaoUser }
        );
      }

      const uid = `kakao:${kakaoUser.id}`;

      // 2) Upsert Firebase Auth user profile
      const displayName = kakaoUser.kakao_account?.profile?.nickname;
      const photoURL = kakaoUser.kakao_account?.profile?.thumbnail_image_url;
      const kakaoEmail = kakaoUser.kakao_account?.email ?? null;

      try {
        await admin.auth().updateUser(uid, {
          displayName,
          photoURL,
          // If Kakao provides email, keep Firebase Auth user in sync too.
          ...(kakaoEmail ? { email: kakaoEmail } : {}),
        });
      } catch (e) {
        try {
          await admin.auth().createUser({
            uid,
            displayName,
            photoURL,
            ...(kakaoEmail ? { email: kakaoEmail } : {}),
          });
        } catch (createErr) {
          console.error("Failed to upsert Firebase user", createErr);
          throw new functions.https.HttpsError(
            "internal",
            "Failed to upsert Firebase user.",
            {
              message: String((createErr as any)?.message ?? createErr),
              code: (createErr as any)?.code,
            }
          );
        }
      }

      // 2-1) Upsert Firestore user profile so client can immediately show email/nickname on first login.
      try {
        const now = admin.firestore.FieldValue.serverTimestamp();
        await admin.firestore().collection("users").doc(uid).set(
          {
            uid,
            email: kakaoEmail,
            nickname: displayName ?? null,
            photoUrl: photoURL ?? null,
            provider: "kakao",
            lastLogin: now,
            createdAt: now,
          },
          { merge: true }
        );
      } catch (e) {
        console.error("Failed to upsert Firestore user doc", e);
        // Non-fatal: auth can still proceed; client will upsert too.
      }

      // 3) Issue Firebase custom token
      let firebaseToken: string;
      try {
        firebaseToken = await admin.auth().createCustomToken(uid, {
          provider: "kakao",
        });
      } catch (e) {
        console.error("Failed to create Firebase custom token", e);
        throw new functions.https.HttpsError(
          "internal",
          "Failed to create Firebase custom token.",
          {
            message: String((e as any)?.message ?? e),
            code: (e as any)?.code,
          }
        );
      }

      return {
        firebaseToken,
        kakaoEmail,
        kakaoNickname: displayName ?? null,
        kakaoPhotoURL: photoURL ?? null,
      };
    } catch (err: any) {
      // Preserve explicit HttpsError
      if (err instanceof functions.https.HttpsError) throw err;

      console.error("Unhandled error in authWithKakao", err);
      throw new functions.https.HttpsError("internal", "Unhandled error", {
        name: String(err?.name ?? ""),
        message: String(err?.message ?? err),
        // Stack can be long; keep it for debugging.
        stack: String(err?.stack ?? ""),
      });
    }
  });

