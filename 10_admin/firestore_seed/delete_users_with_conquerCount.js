/* eslint-disable no-console */
/**
 * Deletes Firestore user documents that contain legacy field `conquerCount`.
 *
 * Safety:
 * - Defaults to dry-run.
 * - Use --commit true to actually delete.
 *
 * Notes:
 * - This only targets Firestore documents in `users/{uid}`.
 * - If supported by the current firebase-admin version, it will use
 *   `firestore.recursiveDelete(docRef)` to delete subcollections too.
 *
 * Usage:
 *   node delete_users_with_conquerCount.js --serviceAccount serviceAccountKey.json --dryRun true
 *   node delete_users_with_conquerCount.js --serviceAccount serviceAccountKey.json --commit true
 *   node delete_users_with_conquerCount.js --serviceAccount serviceAccountKey.json --commit true --limit 50
 */

const fs = require("fs");
const path = require("path");
const minimist = require("minimist");
const admin = require("firebase-admin");

function toBool(v, fallback) {
  if (v === undefined || v === null) return fallback;
  if (typeof v === "boolean") return v;
  const s = String(v).trim().toLowerCase();
  if (["1", "true", "t", "yes", "y"].includes(s)) return true;
  if (["0", "false", "f", "no", "n"].includes(s)) return false;
  return fallback;
}

function usageAndExit(msg) {
  if (msg) console.error(`\n[error] ${msg}\n`);
  console.log(
    [
      "Delete legacy users that have `conquerCount` field.\n",
      "Required:",
      "  --serviceAccount <path>   Firebase Admin SDK service account json\n",
      "Optional:",
      "  --dryRun true|false       Default: true",
      "  --commit true|false       If true, actually deletes (overrides dryRun)",
      "  --limit <n>               Stop after deleting n docs (default: no limit)",
      "  --batchSize <n>           Pagination size (default: 300)\n",
      "Examples:",
      "  node delete_users_with_conquerCount.js --serviceAccount serviceAccountKey.json",
      "  node delete_users_with_conquerCount.js --serviceAccount serviceAccountKey.json --commit true",
    ].join("\n"),
  );
  process.exit(msg ? 1 : 0);
}

async function main() {
  const args = minimist(process.argv.slice(2));
  const serviceAccountPath = args.serviceAccount;
  if (!serviceAccountPath) usageAndExit("--serviceAccount is required");

  const dryRunArg = toBool(args.dryRun, true);
  const commit = toBool(args.commit, false);
  const dryRun = commit ? false : dryRunArg;

  const limitRaw = args.limit;
  const limit =
    limitRaw === undefined || limitRaw === null || limitRaw === ""
      ? null
      : Number(limitRaw);
  if (limit !== null && (!Number.isFinite(limit) || limit <= 0)) {
    usageAndExit("--limit must be a positive number");
  }

  const batchSize = Number(args.batchSize ?? 300);
  if (!Number.isFinite(batchSize) || batchSize < 50 || batchSize > 1000) {
    usageAndExit("--batchSize must be between 50 and 1000");
  }

  const resolvedServiceAccountPath = path.resolve(process.cwd(), serviceAccountPath);
  if (!fs.existsSync(resolvedServiceAccountPath)) {
    usageAndExit(`service account file not found: ${resolvedServiceAccountPath}`);
  }

  const serviceAccount = require(resolvedServiceAccountPath);
  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }

  const db = admin.firestore();
  const canRecursiveDelete = typeof db.recursiveDelete === "function";

  console.log(
    JSON.stringify(
      {
        mode: dryRun ? "dryRun" : "commit",
        limit,
        batchSize,
        recursiveDelete: canRecursiveDelete,
      },
      null,
      2,
    ),
  );

  let scanned = 0;
  let matched = 0;
  let deleted = 0;
  let lastDoc = null;

  while (true) {
    let q = db.collection("users").orderBy(admin.firestore.FieldPath.documentId()).limit(batchSize);
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    scanned += snap.size;
    lastDoc = snap.docs[snap.docs.length - 1];

    for (const doc of snap.docs) {
      const data = doc.data() || {};
      if (!Object.prototype.hasOwnProperty.call(data, "conquerCount")) continue;

      matched += 1;
      const uid = doc.id;
      const conquerCount = data.conquerCount;
      console.log(
        `[match] uid=${uid} conquerCount=${typeof conquerCount === "object" ? JSON.stringify(conquerCount) : String(conquerCount)}`,
      );

      if (!dryRun) {
        try {
          if (canRecursiveDelete) {
            await db.recursiveDelete(doc.ref);
          } else {
            await doc.ref.delete();
          }
          deleted += 1;
        } catch (e) {
          console.error(`[delete-failed] uid=${uid} error=${e?.message ?? String(e)}`);
        }
      }

      if (limit !== null && (dryRun ? matched : deleted) >= limit) {
        console.log("[done] limit reached");
        console.log(JSON.stringify({ scanned, matched, deleted }, null, 2));
        return;
      }
    }
  }

  console.log("[done] scan complete");
  console.log(JSON.stringify({ scanned, matched, deleted }, null, 2));

  if (!dryRun && !canRecursiveDelete && deleted > 0) {
    console.log(
      "\n[warn] recursiveDelete() not available in this firebase-admin version; subcollections under deleted user docs may still exist.\n",
    );
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

