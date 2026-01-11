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
      const kakaoRes = await axios.get("https://kapi.kakao.com/v2/user/me", {
        headers: { Authorization: `Bearer ${accessToken}` },
      });

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

      const uid = `kakao:${kakaoUser.id}`;

      // Optional: upsert Firebase Auth user profile
      const displayName = kakaoUser.kakao_account?.profile?.nickname;
      const photoURL = kakaoUser.kakao_account?.profile?.thumbnail_image_url;

      try {
        await admin.auth().updateUser(uid, {
          displayName,
          photoURL,
        });
      } catch (e) {
        await admin.auth().createUser({
          uid,
          displayName,
          photoURL,
        });
      }

      const firebaseToken = await admin.auth().createCustomToken(uid, {
        provider: "kakao",
      });

      return { firebaseToken };
    } catch (e) {
      throw new functions.https.HttpsError("unauthenticated", "Auth Failed");
    }
  });

