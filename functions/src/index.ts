import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import axios from "axios";
import { google } from "googleapis";

admin.initializeApp();

// ---------------------------------------------------------------------------
// Google Play Developer API client (for server-side receipt verification)
// Uses Application Default Credentials (ADC) in Cloud Functions runtime.
// Requires: Service account with "Android Publisher" role in Google Play Console.
// ---------------------------------------------------------------------------
const androidPublisher = google.androidpublisher({
  version: "v3",
  auth: new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  }),
});

const PACKAGE_NAME = "com.doyakmin.hangookji.namgu";

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
      // 카카오 기본 닉네임("닉네임")은 의미 없는 값이므로 무시
      const rawNickname = kakaoUser.kakao_account?.profile?.nickname;
      const displayName =
        rawNickname && rawNickname !== "닉네임" ? rawNickname : undefined;
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
      // nickname/photoUrl이 없으면 기존 Firestore 값을 보존 (merge: true + 필드 생략)
      try {
        const now = admin.firestore.FieldValue.serverTimestamp();
        const userDoc: Record<string, any> = {
          uid,
          provider: "kakao",
          lastLogin: now,
          createdAt: now,
        };
        if (kakaoEmail) userDoc.email = kakaoEmail;
        if (displayName) userDoc.nickname = displayName;
        if (photoURL) userDoc.photoUrl = photoURL;

        await admin.firestore().collection("users").doc(uid).set(
          userDoc,
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

// ---------------------------------------------------------------------------
// Friends system (uid-based, bidirectional, nickname-change supported)
// Region must match the client: asia-northeast3
// ---------------------------------------------------------------------------

const REGION = "asia-northeast3";

const nicknamePattern = /^[0-9A-Za-z가-힣]{2,12}$/;

function requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "Login required");
  }
  return uid;
}

function normalizeNickname(nickname: string): { nickname: string; lower: string } {
  const n = String(nickname ?? "").trim();
  const compact = n.replace(/\s+/g, "");
  return { nickname: compact, lower: compact.toLowerCase() };
}

type ProfileSnapshot = {
  uid: string;
  nickname: string;
  nicknameLower: string;
  photoUrl?: string | null;
  level?: number | null;
  profileIndex?: number | null;
};

async function readProfileForSnapshot(
  tx: FirebaseFirestore.Transaction,
  uid: string
): Promise<ProfileSnapshot | null> {
  const db = admin.firestore();
  const pubRef = db.collection("public_users").doc(uid);
  const pubSnap = await tx.get(pubRef);
  if (pubSnap.exists) {
    const d = pubSnap.data() || {};
    return {
      uid,
      nickname: String(d.nickname ?? "").trim(),
      nicknameLower: String(d.nicknameLower ?? "").trim(),
      photoUrl: d.photoUrl ?? null,
      level: typeof d.level === "number" ? d.level : null,
      profileIndex: typeof d.profileIndex === "number" ? d.profileIndex : null,
    };
  }

  // Fallback: read from users/{uid} (admin only).
  const userRef = db.collection("users").doc(uid);
  const userSnap = await tx.get(userRef);
  if (!userSnap.exists) return null;
  const d = userSnap.data() || {};
  const nickname = String(d.nickname ?? "").trim();
  const nicknameLower = String(d.nicknameLower ?? "").trim() || nickname.toLowerCase();
  return {
    uid,
    nickname,
    nicknameLower,
    photoUrl: d.photoUrl ?? null,
    level: typeof d.level === "number" ? d.level : null,
    profileIndex: typeof d.profileIndex === "number" ? d.profileIndex : null,
  };
}

function requestInRef(toUid: string, fromUid: string) {
  return admin
    .firestore()
    .collection("users")
    .doc(toUid)
    .collection("friend_requests_in")
    .doc(fromUid);
}

function requestOutRef(fromUid: string, toUid: string) {
  return admin
    .firestore()
    .collection("users")
    .doc(fromUid)
    .collection("friend_requests_out")
    .doc(toUid);
}

function friendRef(uid: string, friendUid: string) {
  return admin.firestore().collection("users").doc(uid).collection("friends").doc(friendUid);
}

async function sendFriendRequestInternal(fromUid: string, toUid: string) {
  const db = admin.firestore();
  await db.runTransaction(async (tx) => {
    const to = await readProfileForSnapshot(tx, toUid);
    if (!to) throw new functions.https.HttpsError("not-found", "User not found");

    const from = await readProfileForSnapshot(tx, fromUid);
    if (!from) throw new functions.https.HttpsError("failed-precondition", "User profile missing");

    const alreadyFriend = await tx.get(friendRef(fromUid, toUid));
    if (alreadyFriend.exists) {
      throw new functions.https.HttpsError("already-exists", "Already friends");
    }

    const inRef = requestInRef(toUid, fromUid);
    const outRef = requestOutRef(fromUid, toUid);
    const inSnap = await tx.get(inRef);
    const outSnap = await tx.get(outRef);
    if (inSnap.exists || outSnap.exists) {
      throw new functions.https.HttpsError("already-exists", "Request already pending");
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    tx.set(inRef, {
      fromUid,
      fromNickname: from.nickname,
      fromPhotoUrl: from.photoUrl ?? null,
      fromLevel: from.level ?? null,
      fromProfileIndex: from.profileIndex ?? null,
      createdAt: now,
    });

    tx.set(outRef, {
      toUid,
      toNickname: to.nickname,
      toPhotoUrl: to.photoUrl ?? null,
      createdAt: now,
    });
  });
}

export const ensurePublicProfile = functions
  .region(REGION)
  .https.onCall(async (_data, context) => {
    const uid = requireAuth(context);
    const db = admin.firestore();

    await db.runTransaction(async (tx) => {
      const userRef = db.collection("users").doc(uid);
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new functions.https.HttpsError("failed-precondition", "User profile missing");
      }

      const u = userSnap.data() || {};
      const nickname = String(u.nickname ?? "").trim();
      if (!nickname) {
        // Allow creating public_users without nickname.
        tx.set(
          db.collection("public_users").doc(uid),
          {
            uid,
            nickname: "",
            nicknameLower: "",
            photoUrl: u.photoUrl ?? null,
            level: typeof u.level === "number" ? u.level : null,
            profileIndex: typeof u.profileIndex === "number" ? u.profileIndex : null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        return;
      }

      const { lower } = normalizeNickname(nickname);
      tx.set(
        db.collection("public_users").doc(uid),
        {
          uid,
          nickname,
          nicknameLower: lower,
          photoUrl: u.photoUrl ?? null,
          level: typeof u.level === "number" ? u.level : null,
          profileIndex: typeof u.profileIndex === "number" ? u.profileIndex : null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(
        userRef,
        {
          nicknameLower: lower,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    return { ok: true };
  });

export const sendFriendRequestByUid = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const fromUid = requireAuth(context);
    const toUid = String(data?.toUid ?? "").trim();
    if (!toUid) throw new functions.https.HttpsError("invalid-argument", "toUid missing");
    if (toUid === fromUid) {
      throw new functions.https.HttpsError("invalid-argument", "Cannot add yourself");
    }

    await sendFriendRequestInternal(fromUid, toUid);

    return { ok: true };
  });

export const sendFriendRequestByNickname = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const fromUid = requireAuth(context);
    const rawNickname = String(data?.nickname ?? "");
    const { nickname, lower } = normalizeNickname(rawNickname);
    if (!nicknamePattern.test(nickname)) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid nickname");
    }

    const db = admin.firestore();
    const q = await db
      .collection("public_users")
      .where("nicknameLower", "==", lower)
      .limit(3)
      .get();
    if (q.empty) throw new functions.https.HttpsError("not-found", "User not found");
    if (q.docs.length > 1) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Multiple users match this nickname. Please select from search results."
      );
    }

    const doc = q.docs[0];
    const toUid = String(doc.data()?.uid ?? doc.id).trim();
    if (!toUid) throw new functions.https.HttpsError("not-found", "User not found");
    if (toUid === fromUid) {
      throw new functions.https.HttpsError("invalid-argument", "Cannot add yourself");
    }

    await sendFriendRequestInternal(fromUid, toUid);
    return { ok: true };
  });

export const sendFriendRequestByInviteCode = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const fromUid = requireAuth(context);
    const code = String(data?.code ?? "").trim().toUpperCase();
    if (!code) throw new functions.https.HttpsError("invalid-argument", "code missing");

    const db = admin.firestore();
    const q = await db.collection("users").where("friendInviteCode", "==", code).limit(1).get();
    if (q.empty) throw new functions.https.HttpsError("not-found", "User not found");
    const toUid = q.docs[0].id;
    if (toUid === fromUid) {
      throw new functions.https.HttpsError("invalid-argument", "Cannot add yourself");
    }
    await sendFriendRequestInternal(fromUid, toUid);
    return { ok: true };
  });

// ---------------------------------------------------------------------------
// Push notifications (FCM)
// - Android works immediately (FCM)
// - iOS requires APNs (.p8) configuration in Firebase Console
// ---------------------------------------------------------------------------

export const onUserCouponIssued = functions
  .region(REGION)
  .firestore.document("users/{uid}/coupons/{couponId}")
  .onCreate(async (snap, context) => {
    const uid = String(context.params.uid ?? "").trim();
    const couponId = String(context.params.couponId ?? "").trim();
    if (!uid || !couponId) return;

    const data = (snap.data() || {}) as Record<string, any>;

    // Only notify for active coupons.
    const status = String(data.status ?? "").toLowerCase();
    if (status && status !== "active") return;

    // Respect user preference if present (best-effort).
    try {
      const userSnap = await admin.firestore().collection("users").doc(uid).get();
      const prefs = (userSnap.data() as any)?.notificationPrefs;
      if (prefs && typeof prefs.coupon === "boolean" && prefs.coupon === false) {
        return;
      }
    } catch (_) {
      // Ignore preference read failures.
    }

    const title = "쿠폰이 발급됐어요";
    const couponTitle = String(data.title ?? "").trim();
    const placeName = String(data.placeName ?? "").trim();
    const body =
      couponTitle && placeName
        ? `${placeName} · ${couponTitle}`
        : couponTitle
        ? couponTitle
        : "쿠폰함에서 새 쿠폰을 확인해보세요.";

    // Collect stored tokens for this user.
    let tokens: string[] = [];
    try {
      const tokenSnap = await admin
        .firestore()
        .collection("users")
        .doc(uid)
        .collection("fcm_tokens")
        .limit(500)
        .get();
      tokens = tokenSnap.docs
        .map((d) => String((d.data() as any)?.token ?? d.id).trim())
        .filter((t) => t.length > 0);
    } catch (e) {
      console.error("Failed to read fcm_tokens", { uid, error: String((e as any)?.message ?? e) });
      return;
    }

    if (tokens.length === 0) return;

    // Send a multicast notification.
    try {
      const res = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: {
          type: "coupon_issued",
          couponId,
          placeId: String(data.placeId ?? ""),
        },
        android: {
          priority: "high",
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });

      // Clean up invalid tokens (best-effort).
      const invalid: string[] = [];
      res.responses.forEach((r, i) => {
        if (r.success) return;
        const code = (r.error as any)?.code as string | undefined;
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        ) {
          invalid.push(tokens[i]);
        }
      });
      if (invalid.length) {
        const batch = admin.firestore().batch();
        invalid.forEach((t) => {
          batch.delete(
            admin.firestore().collection("users").doc(uid).collection("fcm_tokens").doc(t)
          );
        });
        await batch.commit();
      }
    } catch (e) {
      console.error("Failed to send coupon push", {
        uid,
        couponId,
        error: String((e as any)?.message ?? e),
      });
    }
  });

export const applyReferralOnSignup = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const newUid = requireAuth(context);
    const code = String(data?.code ?? "").trim().toUpperCase();
    if (!code) throw new functions.https.HttpsError("invalid-argument", "code missing");
    if (code.length !== 6) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid code");
    }

    const db = admin.firestore();

    const q = await db.collection("users").where("friendInviteCode", "==", code).limit(1).get();
    if (q.empty) throw new functions.https.HttpsError("not-found", "User not found");
    const referrerUid = q.docs[0].id;

    if (referrerUid === newUid) {
      throw new functions.https.HttpsError("invalid-argument", "Cannot refer yourself");
    }

    await db.runTransaction(async (tx) => {
      const newUserRef = db.collection("users").doc(newUid);
      const referrerRef = db.collection("users").doc(referrerUid);

      const newUserSnap = await tx.get(newUserRef);
      const referrerSnap = await tx.get(referrerRef);
      if (!newUserSnap.exists) {
        throw new functions.https.HttpsError("failed-precondition", "User profile missing");
      }
      if (!referrerSnap.exists) {
        throw new functions.https.HttpsError("not-found", "User not found");
      }

      const newUserData = newUserSnap.data() || {};
      if (String(newUserData.referredByUid ?? "").trim()) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Referral already applied for this account"
        );
      }

      // If already friends, still mark referral but skip friend docs update (idempotent).
      const newAlreadyFriend = await tx.get(friendRef(newUid, referrerUid));
      const now = admin.firestore.Timestamp.now();

      // Grant the new user a 30-day free period (referral benefit).
      const newExistingUntil = newUserData.subscriptionFreeUntil as admin.firestore.Timestamp | undefined;
      const newExistingMs = newExistingUntil ? newExistingUntil.toMillis() : 0;
      const newBaseMs = Math.max(now.toMillis(), newExistingMs);
      const newExtendedUntil = admin.firestore.Timestamp.fromMillis(
        newBaseMs + 30 * 24 * 60 * 60 * 1000
      );
      tx.set(
        newUserRef,
        {
          subscriptionFreeUntil: newExtendedUntil,
          subscriptionFreeSource: "referral",
          subscriptionFreeUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(
        newUserRef,
        {
          referredByUid: referrerUid,
          referredByCode: code,
          referredAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // Write entitlements subcollection (new canonical location)
      const entitlementRef = newUserRef.collection("entitlements").doc("subscription");
      tx.set(entitlementRef, {
        status: "premium",
        source: "referral",
        productId: "premium_monthly",
        expiresAt: newExtendedUntil,
        freeUntil: newExtendedUntil,
        freeSource: "referral",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Record in payment_history
      const historyRef = newUserRef.collection("payment_history").doc();
      tx.set(historyRef, {
        eventType: "referral_grant",
        productId: "premium_monthly",
        amount: 0,
        currency: "KRW",
        status: "completed",
        source: "referral",
        expiresAt: newExtendedUntil,
        note: `Referral code: ${code}, referrer: ${referrerUid}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Ensure mutual friendship immediately (no accept step).
      if (!newAlreadyFriend.exists) {
        const referrerProfile = await readProfileForSnapshot(tx, referrerUid);
        const newProfile = await readProfileForSnapshot(tx, newUid);
        if (!referrerProfile || !newProfile) {
          throw new functions.https.HttpsError("failed-precondition", "User profile missing");
        }

        const createdAt = admin.firestore.FieldValue.serverTimestamp();
        tx.set(
          friendRef(newUid, referrerUid),
          {
            friendUid: referrerUid,
            friendNickname: referrerProfile.nickname,
            friendPhotoUrl: referrerProfile.photoUrl ?? null,
            friendLevel: referrerProfile.level ?? null,
            friendProfileIndex: referrerProfile.profileIndex ?? null,
            createdAt,
            snapshotAt: createdAt,
            source: "referral",
          },
          { merge: true }
        );
        tx.set(
          friendRef(referrerUid, newUid),
          {
            friendUid: newUid,
            friendNickname: newProfile.nickname,
            friendPhotoUrl: newProfile.photoUrl ?? null,
            friendLevel: newProfile.level ?? null,
            friendProfileIndex: newProfile.profileIndex ?? null,
            createdAt,
            snapshotAt: createdAt,
            source: "referral",
          },
          { merge: true }
        );

        // Clean up any pending requests between them to avoid UI confusion.
        tx.delete(requestInRef(newUid, referrerUid));
        tx.delete(requestOutRef(newUid, referrerUid));
        tx.delete(requestInRef(referrerUid, newUid));
        tx.delete(requestOutRef(referrerUid, newUid));
      }
    });

    return { ok: true, referrerUid };
  });

export const acceptFriendRequest = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const toUid = requireAuth(context); // receiver
    const fromUid = String(data?.fromUid ?? "").trim(); // sender
    if (!fromUid) throw new functions.https.HttpsError("invalid-argument", "fromUid missing");
    if (fromUid === toUid) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid fromUid");
    }

    const db = admin.firestore();
    await db.runTransaction(async (tx) => {
      const inRef = requestInRef(toUid, fromUid);
      const outRef = requestOutRef(fromUid, toUid);
      const inSnap = await tx.get(inRef);
      const outSnap = await tx.get(outRef);
      if (!inSnap.exists || !outSnap.exists) {
        throw new functions.https.HttpsError("failed-precondition", "Request not found");
      }

      const to = await readProfileForSnapshot(tx, toUid);
      const from = await readProfileForSnapshot(tx, fromUid);
      if (!to || !from) {
        throw new functions.https.HttpsError("failed-precondition", "User profile missing");
      }
      const now = admin.firestore.FieldValue.serverTimestamp();

      tx.set(
        friendRef(toUid, fromUid),
        {
          friendUid: fromUid,
          friendNickname: from.nickname,
          friendPhotoUrl: from.photoUrl ?? null,
          friendLevel: from.level ?? null,
          friendProfileIndex: from.profileIndex ?? null,
          createdAt: now,
          snapshotAt: now,
        },
        { merge: true }
      );

      tx.set(
        friendRef(fromUid, toUid),
        {
          friendUid: toUid,
          friendNickname: to.nickname,
          friendPhotoUrl: to.photoUrl ?? null,
          friendLevel: to.level ?? null,
          friendProfileIndex: to.profileIndex ?? null,
          createdAt: now,
          snapshotAt: now,
        },
        { merge: true }
      );

      tx.delete(inRef);
      tx.delete(outRef);
    });

    return { ok: true };
  });

export const declineFriendRequest = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const toUid = requireAuth(context); // receiver
    const fromUid = String(data?.fromUid ?? "").trim();
    if (!fromUid) throw new functions.https.HttpsError("invalid-argument", "fromUid missing");

    const db = admin.firestore();
    await db.runTransaction(async (tx) => {
      tx.delete(requestInRef(toUid, fromUid));
      tx.delete(requestOutRef(fromUid, toUid));
    });
    return { ok: true };
  });

export const cancelFriendRequest = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const fromUid = requireAuth(context); // sender
    const toUid = String(data?.toUid ?? "").trim();
    if (!toUid) throw new functions.https.HttpsError("invalid-argument", "toUid missing");

    const db = admin.firestore();
    await db.runTransaction(async (tx) => {
      tx.delete(requestOutRef(fromUid, toUid));
      tx.delete(requestInRef(toUid, fromUid));
    });
    return { ok: true };
  });

export const removeFriend = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const friendUid = String(data?.friendUid ?? "").trim();
    if (!friendUid) throw new functions.https.HttpsError("invalid-argument", "friendUid missing");
    if (friendUid === uid) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid friendUid");
    }

    const db = admin.firestore();
    await db.runTransaction(async (tx) => {
      tx.delete(friendRef(uid, friendUid));
      tx.delete(friendRef(friendUid, uid));
    });
    return { ok: true };
  });

// ---------------------------------------------------------------------------
// Subscription management
// ---------------------------------------------------------------------------

/**
 * Verify an iOS App Store receipt using Apple's verifyReceipt endpoint.
 * Tries production first, falls back to sandbox (status 21007).
 *
 * Requires: firebase functions:config:set appstore.shared_secret="YOUR_SECRET"
 * Get it from App Store Connect → App → App Information → App-Specific Shared Secret
 *
 * If shared_secret is not configured, trusts StoreKit on-device validation
 * with a 32-day fallback expiry (for initial review / development).
 */
async function verifyAppleReceipt(
  receiptData: string,
  productId: string
): Promise<{
  isValid: boolean;
  expiresDate: Date | null;
  originalTransactionId: string | null;
}> {
  const sharedSecret = functions.config().appstore?.shared_secret ?? "";

  if (!sharedSecret) {
    console.warn(
      "appstore.shared_secret not configured. " +
      "Run: firebase functions:config:set appstore.shared_secret=\"YOUR_SECRET\". " +
      "Trusting StoreKit on-device validation with fallback expiry."
    );
    return {
      isValid: true,
      expiresDate: new Date(Date.now() + 32 * 24 * 60 * 60 * 1000),
      originalTransactionId: null,
    };
  }

  const urls = [
    "https://buy.itunes.apple.com/verifyReceipt",
    "https://sandbox.itunes.apple.com/verifyReceipt",
  ];

  for (const url of urls) {
    try {
      const res = await axios.post(url, {
        "receipt-data": receiptData,
        "password": sharedSecret,
        "exclude-old-transactions": true,
      });

      const body = res.data;
      const status = body?.status;

      // 21007: sandbox receipt sent to production → retry with sandbox URL
      if (status === 21007) continue;

      if (status !== 0) {
        console.error("Apple verifyReceipt failed", { status, url });
        return { isValid: false, expiresDate: null, originalTransactionId: null };
      }

      // Find the latest subscription info for our product
      const receiptInfo: any[] = body?.latest_receipt_info ?? [];
      const subscriptionItems = receiptInfo
        .filter((item: any) => item.product_id === productId)
        .sort(
          (a: any, b: any) =>
            Number(b.expires_date_ms) - Number(a.expires_date_ms)
        );

      if (subscriptionItems.length === 0) {
        console.warn("No subscription items found in Apple receipt", { productId });
        return { isValid: false, expiresDate: null, originalTransactionId: null };
      }

      const latest = subscriptionItems[0];
      const expiresDate = new Date(Number(latest.expires_date_ms));

      return {
        isValid: true,
        expiresDate,
        originalTransactionId: latest.original_transaction_id ?? null,
      };
    } catch (e: any) {
      console.error("Apple verifyReceipt request error", {
        url,
        error: String(e?.message ?? e),
      });
    }
  }

  return { isValid: false, expiresDate: null, originalTransactionId: null };
}

/**
 * activateSubscription
 *
 * Called by the client after a successful in_app_purchase purchase.
 * Handles both Android (Google Play) and iOS (App Store) verification.
 *
 * Flow:
 * 1. Verify receipt/token with platform-specific API
 * 2. Extract actual expiry from the response
 * 3. Acknowledge purchase (Android only)
 * 4. Write subscription state to users/{uid} + entitlements subcollection
 * 5. Record event in payment_history subcollection
 *
 * Request:  { purchaseToken: string, productId: string, orderId: string, platform?: "ios"|"android" }
 * Response: { ok: true, expiresAt: ISO string }
 */
export const activateSubscription = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const purchaseToken = String(data?.purchaseToken ?? "").trim();
    const productId = String(data?.productId ?? "").trim();
    const orderId = String(data?.orderId ?? "").trim();
    const platform = String(data?.platform ?? "android").trim();

    if (!purchaseToken) {
      throw new functions.https.HttpsError("invalid-argument", "purchaseToken missing");
    }
    if (productId !== "premium_monthly") {
      throw new functions.https.HttpsError("invalid-argument", "Unknown productId");
    }

    let expiresAt: admin.firestore.Timestamp;
    let autoRenewing = true;
    let subscriptionState = "SUBSCRIPTION_STATE_ACTIVE";
    let source: string;

    if (platform === "ios") {
      // ---------------------------------------------------------------
      // iOS App Store verification
      // ---------------------------------------------------------------
      source = "app_store";
      const result = await verifyAppleReceipt(purchaseToken, productId);
      if (!result.isValid || !result.expiresDate) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Apple receipt verification failed"
        );
      }
      expiresAt = admin.firestore.Timestamp.fromDate(result.expiresDate);
      console.log("iOS subscription activated", {
        uid,
        productId,
        expiresAt: result.expiresDate.toISOString(),
        originalTransactionId: result.originalTransactionId,
      });
    } else {
      // ---------------------------------------------------------------
      // Android Google Play verification
      // ---------------------------------------------------------------
      source = "google_play";
      let subscription: any;
      try {
        const res = await androidPublisher.purchases.subscriptionsv2.get({
          packageName: PACKAGE_NAME,
          token: purchaseToken,
        });
        subscription = res.data;
      } catch (e: any) {
        console.error("Google Play verification failed", {
          uid,
          productId,
          error: String(e?.message ?? e),
          status: e?.response?.status,
        });
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Purchase verification failed"
        );
      }

      subscriptionState = String(subscription?.subscriptionState ?? "");
      if (
        subscriptionState !== "SUBSCRIPTION_STATE_ACTIVE" &&
        subscriptionState !== "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
      ) {
        console.warn("Subscription not active", { uid, subscriptionState });
        throw new functions.https.HttpsError(
          "failed-precondition",
          `Subscription not active (state: ${subscriptionState})`
        );
      }

      const lineItems = subscription?.lineItems ?? [];
      const lineItem = lineItems[0];
      const FALLBACK_DAYS = 32;
      expiresAt = lineItem?.expiryTime
        ? admin.firestore.Timestamp.fromDate(new Date(lineItem.expiryTime))
        : admin.firestore.Timestamp.fromMillis(
            Date.now() + FALLBACK_DAYS * 24 * 60 * 60 * 1000
          );
      autoRenewing = !!(lineItem?.autoRenewingPlan);

      // Acknowledge purchase (required by Google Play)
      try {
        await androidPublisher.purchases.subscriptions.acknowledge({
          packageName: PACKAGE_NAME,
          subscriptionId: productId,
          token: purchaseToken,
        });
      } catch (e: any) {
        console.warn("Acknowledge call failed (may be already done)", {
          uid,
          error: String(e?.message ?? e),
        });
      }
    }

    // Write to Firestore (shared for both platforms)
    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const entitlementRef = userRef.collection("entitlements").doc("subscription");
    const historyRef = userRef.collection("payment_history").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();

    await db.runTransaction(async (tx) => {
      // Legacy: write to users/{uid} for backward compatibility
      tx.set(
        userRef,
        {
          subscriptionStatus: "premium",
          subscriptionProductId: productId,
          subscriptionPurchaseToken: purchaseToken,
          subscriptionExpiresAt: expiresAt,
          subscriptionActivatedAt: now,
        },
        { merge: true }
      );

      // New canonical: entitlements subcollection
      tx.set(entitlementRef, {
        status: "premium",
        source,
        productId,
        purchaseToken,
        expiresAt,
        activatedAt: now,
        autoRenewing,
        subscriptionState,
        updatedAt: now,
      });

      // Payment history (immutable event log)
      tx.set(historyRef, {
        eventType: "subscription_new",
        orderId: orderId || null,
        purchaseToken,
        productId,
        amount: 990,
        currency: "KRW",
        status: "completed",
        source,
        platform,
        subscriptionState,
        expiresAt,
        autoRenewing,
        createdAt: now,
        processedAt: now,
      });
    });

    return { ok: true, expiresAt: expiresAt.toDate().toISOString() };
  });

// ---------------------------------------------------------------------------
// RTDN (Real-time Developer Notification) from Google Play
// Pub/Sub topic: play-billing-events
// Setup: Google Play Console → Monetization → Real-time developer notifications
// ---------------------------------------------------------------------------

/**
 * handlePlayBillingEvent
 *
 * Processes subscription lifecycle events from Google Play via Pub/Sub.
 * For each event:
 * 1. Look up user by purchaseToken
 * 2. Re-verify current subscription state with Google Play API
 * 3. Update entitlement + user doc (dual-write)
 * 4. Record event in payment_history
 */
export const handlePlayBillingEvent = functions
  .region(REGION)
  .pubsub.topic("play-billing-events")
  .onPublish(async (message) => {
    const data = message.json;

    const subNotification = data?.subscriptionNotification;
    if (!subNotification) {
      console.log("Non-subscription notification, ignoring", { data });
      return;
    }

    const { purchaseToken, subscriptionId, notificationType } = subNotification;
    if (!purchaseToken) {
      console.warn("RTDN missing purchaseToken", { subNotification });
      return;
    }

    // Look up user by purchaseToken
    const db = admin.firestore();
    const usersQuery = await db
      .collection("users")
      .where("subscriptionPurchaseToken", "==", purchaseToken)
      .limit(1)
      .get();

    if (usersQuery.empty) {
      console.warn("No user found for purchaseToken", {
        purchaseToken: purchaseToken.slice(0, 20) + "...",
        notificationType,
      });
      return;
    }

    const uid = usersQuery.docs[0].id;

    // Re-verify current state with Google Play API
    let subscription: any;
    try {
      const res = await androidPublisher.purchases.subscriptionsv2.get({
        packageName: PACKAGE_NAME,
        token: purchaseToken,
      });
      subscription = res.data;
    } catch (e: any) {
      console.error("RTDN: Google Play verification failed", {
        uid,
        notificationType,
        error: String(e?.message ?? e),
      });
      return;
    }

    const subscriptionState = String(subscription?.subscriptionState ?? "");
    const lineItem = subscription?.lineItems?.[0];
    const expiryTime = lineItem?.expiryTime
      ? admin.firestore.Timestamp.fromDate(new Date(lineItem.expiryTime))
      : null;
    const autoRenewing = !!(lineItem?.autoRenewingPlan);

    // Map Google Play notification type to our event type and new status
    // Ref: https://developer.android.com/google/play/billing/rtdn-reference
    let eventType: string;
    let newStatus: string;

    switch (notificationType) {
      case 1: // SUBSCRIPTION_RECOVERED
      case 7: // SUBSCRIPTION_RESTARTED
        eventType = "subscription_recovered";
        newStatus = "premium";
        break;
      case 2: // SUBSCRIPTION_RENEWED
        eventType = "subscription_renewed";
        newStatus = "premium";
        break;
      case 3: // SUBSCRIPTION_CANCELED (auto-renew off; still active until expiry)
        eventType = "subscription_canceled";
        newStatus = "premium";
        break;
      case 4: // SUBSCRIPTION_PURCHASED (handled by activateSubscription callable)
        eventType = "subscription_purchased";
        newStatus = "premium";
        break;
      case 5: // SUBSCRIPTION_ON_HOLD
        eventType = "subscription_on_hold";
        newStatus = "on_hold";
        break;
      case 6: // SUBSCRIPTION_IN_GRACE_PERIOD
        eventType = "subscription_grace_period";
        newStatus = "premium";
        break;
      case 12: // SUBSCRIPTION_REVOKED (refund)
        eventType = "subscription_revoked";
        newStatus = "free";
        break;
      case 13: // SUBSCRIPTION_EXPIRED
        eventType = "subscription_expired";
        newStatus = "free";
        break;
      default:
        eventType = `notification_type_${notificationType}`;
        newStatus =
          subscriptionState === "SUBSCRIPTION_STATE_ACTIVE" ? "premium" : "free";
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const userRef = db.collection("users").doc(uid);
    const entitlementRef = userRef.collection("entitlements").doc("subscription");
    const historyRef = userRef.collection("payment_history").doc();

    await db.runTransaction(async (tx) => {
      // Update legacy user doc
      tx.set(
        userRef,
        {
          subscriptionStatus: newStatus,
          subscriptionExpiresAt: expiryTime,
        },
        { merge: true }
      );

      // Update entitlements subcollection
      tx.set(
        entitlementRef,
        {
          status: newStatus,
          source: "google_play",
          expiresAt: expiryTime,
          autoRenewing,
          subscriptionState,
          lastNotificationType: notificationType,
          updatedAt: now,
        },
        { merge: true }
      );

      // Append to payment_history
      tx.set(historyRef, {
        eventType,
        purchaseToken,
        productId: subscriptionId || "premium_monthly",
        subscriptionState,
        notificationType,
        expiresAt: expiryTime,
        autoRenewing,
        amount: eventType === "subscription_renewed" ? 990 : 0,
        currency: "KRW",
        source: "rtdn",
        createdAt: now,
        processedAt: now,
      });
    });

    console.log("RTDN processed", {
      uid,
      eventType,
      newStatus,
      notificationType,
    });
  });

// ---------------------------------------------------------------------------
// Voided Purchases reconciliation (daily)
// ---------------------------------------------------------------------------

/**
 * reconcileVoidedPurchases
 *
 * Runs daily to catch refunds/chargebacks that RTDN might miss.
 * Calls Google Play Voided Purchases API and revokes premium for affected users.
 */
export const reconcileVoidedPurchases = functions
  .region(REGION)
  .pubsub.schedule("every 24 hours")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const db = admin.firestore();

    let voidedPurchases: any[];
    try {
      const res = await androidPublisher.purchases.voidedpurchases.list({
        packageName: PACKAGE_NAME,
        // Only check recent voids (last 3 days to account for processing delays)
        startTime: String(Date.now() - 3 * 24 * 60 * 60 * 1000),
      });
      voidedPurchases = res.data?.voidedPurchases ?? [];
    } catch (e: any) {
      console.error("Failed to fetch voided purchases", {
        error: String(e?.message ?? e),
      });
      return;
    }

    if (voidedPurchases.length === 0) {
      console.log("No voided purchases found");
      return;
    }

    console.log(`Found ${voidedPurchases.length} voided purchase(s)`);

    for (const vp of voidedPurchases) {
      const purchaseToken = vp.purchaseToken;
      if (!purchaseToken) continue;

      const usersQuery = await db
        .collection("users")
        .where("subscriptionPurchaseToken", "==", purchaseToken)
        .limit(1)
        .get();

      if (usersQuery.empty) continue;

      const uid = usersQuery.docs[0].id;
      const userData = usersQuery.docs[0].data();

      // Skip if already free
      if (userData.subscriptionStatus !== "premium") continue;

      const userRef = db.collection("users").doc(uid);
      const entitlementRef = userRef
        .collection("entitlements")
        .doc("subscription");
      const historyRef = userRef.collection("payment_history").doc();
      const now = admin.firestore.FieldValue.serverTimestamp();

      await db.runTransaction(async (tx) => {
        tx.set(
          userRef,
          { subscriptionStatus: "free", subscriptionExpiresAt: null },
          { merge: true }
        );

        tx.set(
          entitlementRef,
          {
            status: "free",
            source: "google_play",
            revokedReason: "voided_purchase",
            updatedAt: now,
          },
          { merge: true }
        );

        tx.set(historyRef, {
          eventType: "voided_purchase",
          purchaseToken,
          productId: vp.productId || "premium_monthly",
          orderId: vp.orderId || null,
          voidedSource: String(vp.voidedSource ?? ""),
          voidedReason: String(vp.voidedReason ?? ""),
          amount: 0,
          currency: "KRW",
          source: "reconciliation",
          createdAt: now,
          processedAt: now,
        });
      });

      console.log("Voided purchase reconciled", { uid, purchaseToken: purchaseToken.slice(0, 20) + "..." });
    }
  });

export const changeNickname = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const rawNickname = String(data?.nickname ?? "");
    const { nickname, lower } = normalizeNickname(rawNickname);
    if (!nicknamePattern.test(nickname)) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid nickname");
    }

    const db = admin.firestore();
    await db.runTransaction(async (tx) => {
      const userRef = db.collection("users").doc(uid);
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new functions.https.HttpsError("failed-precondition", "User profile missing");
      }

      const now = admin.firestore.FieldValue.serverTimestamp();

      tx.set(
        userRef,
        {
          nickname,
          nicknameLower: lower,
          updatedAt: now,
        },
        { merge: true }
      );

      tx.set(
        db.collection("public_users").doc(uid),
        {
          uid,
          nickname,
          nicknameLower: lower,
          updatedAt: now,
        },
        { merge: true }
      );
    });

    return { ok: true };
  });

// ---------------------------------------------------------------------------
// Client error log collection
// Stores auth/runtime errors from clients into Firestore for debugging.
// ---------------------------------------------------------------------------
export const logClientError = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid ?? "anonymous";
    const { action, errorType, errorMessage, stackTrace, platform, appVersion } =
      data ?? {};

    const entry: Record<string, unknown> = {
      uid,
      action: String(action ?? "unknown"),
      errorType: String(errorType ?? "unknown"),
      errorMessage: String(errorMessage ?? ""),
      stackTrace: String(stackTrace ?? "").slice(0, 4000),
      platform: String(platform ?? "unknown"),
      appVersion: String(appVersion ?? "unknown"),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await admin.firestore().collection("client_errors").add(entry);
    return { ok: true };
  });

// ---------------------------------------------------------------------------
// Admin-driven missions & coupons (PRD 02/07/08)
//
// 앱은 Admin이 운영하는 MissionInstance / CouponPolicy / StoreCouponOverride 를
// 직접 읽는 대신 아래 서버 엔드포인트를 통해 접근한다.
//   - getActiveMissionAndPolicy : 앱 UI가 오늘의 목표 걸음수/필요일수/회차기간을
//                                 Admin이 설정한 값 그대로 렌더링할 수 있게 해준다.
//   - claimCycleReward          : 클라이언트 주장("회차 N일 달성") 을 서버가 daily_steps
//                                 로 재검증한 뒤 쿠폰 1장을 발급하고 CouponUsage 로그를
//                                 기록한다. Firestore Rules 로 막혀 있는 쿠폰 write 를
//                                 여기에서만 Admin SDK 로 수행한다.
//   - redeemCoupon              : 상점 useCode 검증 후 쿠폰 상태를 used 로 바꾸고
//                                 CouponUsage 에 redeemed 로그를 남긴다.
// ---------------------------------------------------------------------------

/**
 * PRD 03: status 가 sanctioned / withdrawal_requested 인 사용자, 또는 riskFlag=true
 * 인 사용자는 쿠폰 발급/사용 권한을 박탈한다. 호출 측에서 이 가드를 통과해야
 * 미션 보상이나 쿠폰 사용 처리가 가능하다.
 */
async function assertUserActive(uid: string): Promise<void> {
  const snap = await admin.firestore().collection("users").doc(uid).get();
  if (!snap.exists) return; // 신규 계정 생성 직후 등 — 통과.
  const d = snap.data() as Record<string, unknown>;
  const status = String(d.status ?? "normal").toLowerCase();
  if (status === "sanctioned") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "제재 상태의 계정입니다. 운영자에게 문의해주세요."
    );
  }
  if (status === "withdrawal_requested") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "탈퇴 요청된 계정입니다."
    );
  }
  if (d.riskFlag === true) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "이상 활동이 감지되어 일시적으로 제한된 계정입니다."
    );
  }
}

type CouponPolicyDoc = {
  couponId: string;
  name?: string;
  type?: "common" | "store_specific";
  discountAmount?: number;
  minPurchase?: number;
  validityType?: "relative" | "absolute";
  validityDays?: number;
  validityEndDate?: admin.firestore.Timestamp;
  targetStoreScope?: "all" | "selected";
  targetStoreIds?: string[];
  duplicateUse?: boolean;
  status?: "scheduled" | "active" | "terminated" | "inactive";
  description?: string;
};

type MissionInstanceDoc = {
  instanceId: string;
  name?: string;
  description?: string;
  startAt?: string | admin.firestore.Timestamp;
  endAt?: string | admin.firestore.Timestamp;
  durationDays?: number;
  achievementType?: "n_days" | "cumulative_steps" | "consecutive" | "custom";
  targetSteps?: number;
  targetDays?: number;
  targetScope?: "all" | "group" | "individual";
  targetUserIds?: string[];
  rewardCouponId?: string | null;
  rewardCouponName?: string;
  status?: "scheduled" | "active" | "paused" | "terminated";
};

function toTimestamp(v: unknown): admin.firestore.Timestamp | null {
  if (!v) return null;
  if (v instanceof admin.firestore.Timestamp) return v;
  if (typeof v === "string") {
    const d = new Date(v);
    if (isNaN(d.getTime())) return null;
    return admin.firestore.Timestamp.fromDate(d);
  }
  if (v instanceof Date) return admin.firestore.Timestamp.fromDate(v);
  return null;
}

function yyyyMmDd(d: Date): string {
  const y = d.getUTCFullYear().toString().padStart(4, "0");
  const m = (d.getUTCMonth() + 1).toString().padStart(2, "0");
  const day = d.getUTCDate().toString().padStart(2, "0");
  return `${y}-${m}-${day}`;
}

/**
 * 현재 시각 기준 active 상태이고 사용자가 대상(all 또는 개별 지정)인 MissionInstance 를
 * 1건 반환한다. 여러 개면 startAt 이 늦은 쪽(최신 회차) 우선.
 */
async function findActiveMissionForUser(
  uid: string
): Promise<MissionInstanceDoc | null> {
  const db = admin.firestore();
  const snap = await db
    .collection("mission_instances")
    .where("status", "==", "active")
    .get();

  const now = Date.now();
  const candidates: MissionInstanceDoc[] = [];
  for (const doc of snap.docs) {
    const m = doc.data() as MissionInstanceDoc;
    const start = toTimestamp(m.startAt);
    const end = toTimestamp(m.endAt);
    if (!start || !end) continue;
    if (now < start.toMillis() || now > end.toMillis()) continue;

    const scope = m.targetScope ?? "all";
    if (scope === "individual") {
      const ids = Array.isArray(m.targetUserIds) ? m.targetUserIds : [];
      if (!ids.includes(uid)) continue;
    }
    // group scope: 상세 필터는 향후 확장 (PRD 07). 현재는 all 로 취급.
    candidates.push({ ...m, instanceId: doc.id });
  }

  if (candidates.length === 0) return null;
  candidates.sort((a, b) => {
    const aT = toTimestamp(a.startAt)?.toMillis() ?? 0;
    const bT = toTimestamp(b.startAt)?.toMillis() ?? 0;
    return bT - aT;
  });
  return candidates[0];
}

async function loadCouponPolicy(
  couponId: string | null | undefined
): Promise<CouponPolicyDoc | null> {
  if (!couponId) return null;
  const doc = await admin
    .firestore()
    .collection("coupon_policies")
    .doc(couponId)
    .get();
  if (!doc.exists) return null;
  return { ...(doc.data() as CouponPolicyDoc), couponId: doc.id };
}

/**
 * PRD 02: 상점별 Override 가 존재하면 해당 값을 공통 정책에 덮어쓴다.
 * 반환값은 앱 표출/발급에 사용할 최종 effective 정책.
 */
async function resolveEffectivePolicyForStore(
  policy: CouponPolicyDoc,
  storeId: string
): Promise<CouponPolicyDoc> {
  const now = admin.firestore.Timestamp.now();
  const overridesSnap = await admin
    .firestore()
    .collection("store_coupon_overrides")
    .where("couponId", "==", policy.couponId)
    .where("storeId", "==", storeId)
    .where("status", "==", "active")
    .get();

  for (const doc of overridesSnap.docs) {
    const o = doc.data() as Record<string, unknown>;
    const start = toTimestamp(o.startAt);
    const end = toTimestamp(o.endAt);
    if (!start || !end) continue;
    if (now.toMillis() < start.toMillis() || now.toMillis() > end.toMillis()) {
      continue;
    }
    return {
      ...policy,
      discountAmount:
        typeof o.discountAmount === "number"
          ? o.discountAmount
          : policy.discountAmount,
      minPurchase:
        typeof o.minPurchase === "number" ? o.minPurchase : policy.minPurchase,
      validityDays:
        typeof o.validityDays === "number" ? o.validityDays : policy.validityDays,
    };
  }
  return policy;
}

export const getActiveMissionAndPolicy = functions
  .region(REGION)
  .https.onCall(async (_data, context) => {
    const uid = requireAuth(context);

    const mission = await findActiveMissionForUser(uid);
    if (!mission) return { mission: null, policy: null };

    const policy = await loadCouponPolicy(mission.rewardCouponId ?? null);

    return {
      mission: {
        instanceId: mission.instanceId,
        name: mission.name ?? "",
        description: mission.description ?? "",
        startAt: toTimestamp(mission.startAt)?.toDate().toISOString() ?? null,
        endAt: toTimestamp(mission.endAt)?.toDate().toISOString() ?? null,
        durationDays: mission.durationDays ?? 10,
        achievementType: mission.achievementType ?? "n_days",
        targetSteps: mission.targetSteps ?? 5000,
        targetDays: mission.targetDays ?? 3,
        rewardCouponId: mission.rewardCouponId ?? null,
        rewardCouponName: mission.rewardCouponName ?? "",
      },
      policy: policy
        ? {
            couponId: policy.couponId,
            name: policy.name ?? "",
            description: policy.description ?? "",
            discountAmount: policy.discountAmount ?? 0,
            minPurchase: policy.minPurchase ?? 0,
            validityDays: policy.validityDays ?? 7,
            targetStoreScope: policy.targetStoreScope ?? "all",
            targetStoreIds: policy.targetStoreIds ?? [],
            duplicateUse: policy.duplicateUse === true,
            status: policy.status ?? "active",
          }
        : null,
    };
  });

/**
 * PRD 07: "회차 기간 내 targetDays 일 이상 목표 걸음수 달성" 을 서버가 직접
 * daily_steps 로 재검증한 뒤 쿠폰을 1장 발급한다. 발급은 회차(instanceId) 당 1장.
 */
export const claimCycleReward = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    await assertUserActive(uid);
    const db = admin.firestore();

    const requestedStoreId = String(data?.storeId ?? "").trim() || null;

    const mission = await findActiveMissionForUser(uid);
    if (!mission) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "활성화된 미션 회차가 없습니다."
      );
    }
    const policy = await loadCouponPolicy(mission.rewardCouponId);
    if (!policy || policy.status !== "active") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "이 미션에 연결된 활성 쿠폰 정책이 없습니다."
      );
    }

    const targetSteps = mission.targetSteps ?? 5000;
    const targetDays = mission.targetDays ?? 3;
    const start = toTimestamp(mission.startAt);
    const end = toTimestamp(mission.endAt);
    if (!start || !end) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "미션 기간이 올바르지 않습니다."
      );
    }

    // 회차 기간 내 daily_steps 를 서버가 직접 읽어 달성일수를 센다.
    const dailyRef = db
      .collection("users")
      .doc(uid)
      .collection("daily_steps");
    const startMs = start.toMillis();
    const endMs = Math.min(end.toMillis(), Date.now());

    let achieved = 0;
    const cursor = new Date(startMs);
    while (cursor.getTime() <= endMs) {
      const key = yyyyMmDd(cursor);
      const snap = await dailyRef.doc(key).get();
      const steps = Number((snap.data() as { steps?: unknown })?.steps ?? 0);
      if (steps >= targetSteps) achieved += 1;
      cursor.setUTCDate(cursor.getUTCDate() + 1);
    }

    if (achieved < targetDays) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `달성 일수가 부족합니다. (${achieved}/${targetDays})`
      );
    }

    // 대상 상점 선정: PRD 01 - status 가 active 인 상점만 쿠폰 사용 가능.
    // 레거시 문서는 status 필드 없이 isActive 만 갖는 경우도 있으므로 둘 다 본다.
    const storesSnap = await db.collection("places").get();
    const allowedIds =
      (policy.targetStoreScope ?? "all") === "selected"
        ? new Set(policy.targetStoreIds ?? [])
        : null;

    type StoreLite = {
      id: string;
      name: string;
      useCode: string;
      hasCoupons: boolean;
    };
    const stores: StoreLite[] = storesSnap.docs
      .map((d) => {
        const sd = d.data() as Record<string, unknown>;
        const statusRaw = String(sd.status ?? "").toLowerCase();
        const legacyActive = sd.isActive === true;
        const effectiveActive =
          statusRaw === "active" ||
          (statusRaw === "" && legacyActive);
        return {
          id: d.id,
          name: String(sd.name ?? ""),
          useCode: String(sd.useCode ?? ""),
          hasCoupons: sd.hasCoupons === true,
          active: effectiveActive,
        };
      })
      .filter(
        (s) =>
          s.active &&
          s.useCode.length > 0 &&
          (allowedIds == null || allowedIds.has(s.id))
      )
      .map(({ id, name, useCode, hasCoupons }) => ({
        id,
        name,
        useCode,
        hasCoupons,
      }));
    if (stores.length === 0) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "사용 가능한 상점이 없습니다."
      );
    }

    let store: StoreLite =
      (requestedStoreId && stores.find((s) => s.id === requestedStoreId)) ||
      stores.find((s) => s.hasCoupons) ||
      stores[0];

    const effectivePolicy = await resolveEffectivePolicyForStore(
      policy,
      store.id
    );

    const validityDays = effectivePolicy.validityDays ?? 7;
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + validityDays * 24 * 60 * 60 * 1000
    );

    const couponId = `mission_${mission.instanceId}`;
    const userCouponRef = db
      .collection("users")
      .doc(uid)
      .collection("coupons")
      .doc(couponId);
    const usageRef = db.collection("coupon_usage").doc();
    const missionRef = db.collection("mission_instances").doc(mission.instanceId);

    const result = await db.runTransaction(async (tx) => {
      const existing = await tx.get(userCouponRef);
      if (existing.exists) return { ok: false, reason: "already_issued" };

      const now = admin.firestore.FieldValue.serverTimestamp();
      tx.set(userCouponRef, {
        title: effectivePolicy.name || "미션 달성 쿠폰",
        description:
          effectivePolicy.description ||
          `${targetDays}일 이상 ${targetSteps}보 달성 쿠폰`,
        verificationCode: store.useCode,
        status: "active",
        expiresAt,
        placeId: store.id,
        placeName: store.name,
        issuedFor: couponId,
        missionInstanceId: mission.instanceId,
        couponPolicyId: policy.couponId,
        discountAmount: effectivePolicy.discountAmount ?? 0,
        minPurchase: effectivePolicy.minPurchase ?? 0,
        duplicateUse: effectivePolicy.duplicateUse === true,
        createdAt: now,
        updatedAt: now,
      });

      // PRD 08 사용내역 로그 - 발급 이벤트.
      tx.set(usageRef, {
        userId: uid,
        storeId: store.id,
        storeName: store.name,
        couponPolicyId: policy.couponId,
        missionInstanceId: mission.instanceId,
        userCouponId: couponId,
        discountAmount: effectivePolicy.discountAmount ?? 0,
        status: "issued",
        issuedAt: now,
        redeemedAt: null,
        expiresAt,
      });

      tx.set(
        missionRef,
        {
          couponsIssued: admin.firestore.FieldValue.increment(1),
          achieverCount: admin.firestore.FieldValue.increment(1),
          updatedAt: now,
        },
        { merge: true }
      );
      return { ok: true };
    });

    return {
      ok: result.ok === true,
      reason: result.ok ? null : result.reason,
      couponId,
      placeId: store.id,
      placeName: store.name,
    };
  });

/**
 * PRD 02/08: 쿠폰 사용 처리. 클라이언트가 입력한 코드가 상점 useCode 와 일치하면
 * 쿠폰 상태를 used 로 바꾸고 coupon_usage 에 redeemed 로그를 남긴다. 실패는
 * failed_code_attempts 에 이미 기록되므로 여기서는 성공 경로만 담당한다.
 */
export const redeemCoupon = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    await assertUserActive(uid);
    const couponId = String(data?.couponId ?? "").trim();
    const inputCode = String(data?.code ?? "").trim();
    if (!couponId || inputCode.length !== 6) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "couponId/code 가 올바르지 않습니다."
      );
    }

    const db = admin.firestore();
    const couponRef = db
      .collection("users")
      .doc(uid)
      .collection("coupons")
      .doc(couponId);

    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(couponRef);
      if (!snap.exists) return { ok: false, reason: "not_found" };
      const c = snap.data() as Record<string, unknown>;
      if (c.status === "used") return { ok: false, reason: "already_used" };
      if (c.status !== "active") return { ok: false, reason: "not_active" };

      const expiresAtRaw = c.expiresAt;
      const expiresAt =
        expiresAtRaw instanceof admin.firestore.Timestamp
          ? expiresAtRaw
          : null;
      if (expiresAt && Date.now() > expiresAt.toMillis()) {
        tx.update(couponRef, {
          status: "expired",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { ok: false, reason: "expired" };
      }

      if (String(c.verificationCode ?? "") !== inputCode) {
        return { ok: false, reason: "wrong_code" };
      }

      const now = admin.firestore.FieldValue.serverTimestamp();
      tx.update(couponRef, { status: "used", updatedAt: now });

      // CouponUsage: 기존 발급 로그를 갱신하기보다 redeemed 이벤트를 append.
      const usageRef = db.collection("coupon_usage").doc();
      tx.set(usageRef, {
        userId: uid,
        storeId: String(c.placeId ?? ""),
        storeName: String(c.placeName ?? ""),
        couponPolicyId: String(c.couponPolicyId ?? ""),
        missionInstanceId: String(c.missionInstanceId ?? ""),
        userCouponId: couponId,
        discountAmount: Number(c.discountAmount ?? 0),
        status: "redeemed",
        issuedAt: c.createdAt ?? null,
        redeemedAt: now,
        expiresAt: c.expiresAt ?? null,
      });
      return { ok: true };
    });

    if (!result.ok) {
      // 실패 원인도 이벤트 로그에 남겨 Admin 이상거래 화면에서 볼 수 있게.
      await db.collection("failed_code_attempts").add({
        userId: uid,
        couponId,
        attemptedCode: inputCode,
        reason: result.reason,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw new functions.https.HttpsError(
        "failed-precondition",
        `쿠폰 사용 실패: ${result.reason}`
      );
    }
    return { ok: true };
  });
