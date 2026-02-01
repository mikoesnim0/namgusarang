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
