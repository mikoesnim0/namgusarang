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
 * activateSubscription
 *
 * Called by the client after a successful in_app_purchase purchase.
 * Server-side receipt verification via Google Play Developer API.
 *
 * Flow:
 * 1. Verify purchaseToken with purchases.subscriptionsv2.get
 * 2. Check subscription is ACTIVE or IN_GRACE_PERIOD
 * 3. Extract actual expiry from Google's response
 * 4. Acknowledge purchase
 * 5. Write subscription state to users/{uid} + entitlements subcollection
 * 6. Record event in payment_history subcollection
 *
 * Request:  { purchaseToken: string, productId: string, orderId: string }
 * Response: { ok: true, expiresAt: ISO string }
 */
export const activateSubscription = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const purchaseToken = String(data?.purchaseToken ?? "").trim();
    const productId = String(data?.productId ?? "").trim();
    const orderId = String(data?.orderId ?? "").trim();

    if (!purchaseToken) {
      throw new functions.https.HttpsError("invalid-argument", "purchaseToken missing");
    }
    if (productId !== "premium_monthly") {
      throw new functions.https.HttpsError("invalid-argument", "Unknown productId");
    }

    // 1. Verify with Google Play Developer API
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

    // 2. Validate subscription state
    const subscriptionState = String(subscription?.subscriptionState ?? "");
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

    // 3. Extract actual expiry from Google's response
    const lineItems = subscription?.lineItems ?? [];
    const lineItem = lineItems[0];
    const FALLBACK_DAYS = 32;
    const expiresAt = lineItem?.expiryTime
      ? admin.firestore.Timestamp.fromDate(new Date(lineItem.expiryTime))
      : admin.firestore.Timestamp.fromMillis(
          Date.now() + FALLBACK_DAYS * 24 * 60 * 60 * 1000
        );
    const autoRenewing = !!(lineItem?.autoRenewingPlan);

    // 4. Acknowledge purchase (required by Google Play)
    try {
      await androidPublisher.purchases.subscriptions.acknowledge({
        packageName: PACKAGE_NAME,
        subscriptionId: productId,
        token: purchaseToken,
      });
    } catch (e: any) {
      // Log but don't fail -- may already be acknowledged
      console.warn("Acknowledge call failed (may be already done)", {
        uid,
        error: String(e?.message ?? e),
      });
    }

    // 5 & 6. Write to Firestore in a transaction
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
        source: "google_play",
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
        source: "google_play",
        platform: "android",
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
