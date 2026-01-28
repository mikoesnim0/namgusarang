#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const admin = require('firebase-admin');
const { parse } = require('csv-parse/sync');
const minimist = require('minimist');

function die(msg) {
  console.error(msg);
  process.exit(1);
}

function asBool(v, defaultValue = false) {
  if (v === undefined || v === null || v === '') return defaultValue;
  if (typeof v === 'boolean') return v;
  const s = String(v).trim().toLowerCase();
  if (['true', '1', 'yes', 'y'].includes(s)) return true;
  if (['false', '0', 'no', 'n'].includes(s)) return false;
  return defaultValue;
}

function readCsv(csvPath) {
  const text = fs.readFileSync(csvPath, 'utf8');
  return parse(text, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
  });
}

function parseDateYYYYMMDD(s, fieldName) {
  const v = (s || '').trim();
  if (!v) return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(v);
  if (!m) die(`Invalid date for ${fieldName}: ${s} (expected YYYY-MM-DD)`);
  const dt = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 0, 0, 0);
  if (Number.isNaN(dt.getTime())) die(`Invalid date for ${fieldName}: ${s}`);
  return dt;
}

function gen6() {
  const n = Math.floor(Math.random() * 900000) + 100000;
  return String(n);
}

async function main() {
  const argv = minimist(process.argv.slice(2));

  const serviceAccountPath = argv.serviceAccount || argv.service_account;
  const csvPath = argv.csv;
  const projectId = argv.projectId || argv.project_id;
  const uid = (argv.uid || '').trim();
  const dryRun = asBool(argv.dryRun ?? argv.dry_run, false);

  if (!serviceAccountPath) die('Missing --serviceAccount path to Firebase service account JSON');
  if (!csvPath) die('Missing --csv path to coupons CSV (e.g. ../../documents/planning/coupons_template.csv)');
  if (!uid) die('Missing --uid (Firebase Auth uid to seed coupons into /users/{uid}/coupons)');

  const resolvedServiceAccount = path.resolve(process.cwd(), serviceAccountPath);
  const resolvedCsv = path.resolve(process.cwd(), csvPath);

  if (!fs.existsSync(resolvedServiceAccount)) {
    die(`Service account file not found: ${resolvedServiceAccount}`);
  }
  if (!fs.existsSync(resolvedCsv)) {
    die(`CSV file not found: ${resolvedCsv}`);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(resolvedServiceAccount, 'utf8'));

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: projectId || serviceAccount.project_id,
  });

  const db = admin.firestore();
  const rows = readCsv(resolvedCsv);
  if (!rows.length) die('CSV has no rows.');

  console.log(`Loaded ${rows.length} rows from ${resolvedCsv}`);
  console.log(`Target user: ${uid}`);

  const BATCH_LIMIT = 450;
  let batch = db.batch();
  let inBatch = 0;
  let totalWrites = 0;

  for (const r of rows) {
    const couponId = (r.couponId || '').trim() || db.collection('x').doc().id;
    const title = (r.title || '').trim();
    const description = (r.description || '').trim();
    const verificationCode = (r.verificationCode || '').trim() || gen6();
    const status = (r.status || 'active').trim().toLowerCase();
    const expiresAt = parseDateYYYYMMDD(r.expiresAt, 'expiresAt') || new Date(Date.now() + 7 * 86400 * 1000);
    const placeId = (r.placeId || '').trim();
    const placeName = (r.placeName || '').trim();

    if (!title) die(`Missing title for couponId=${couponId}`);
    if (!placeId) die(`Missing placeId for couponId=${couponId}`);

    const ref = db.collection('users').doc(uid).collection('coupons').doc(couponId);
    const data = {
      title,
      description,
      verificationCode,
      status,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      placeId,
      placeName,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (!dryRun) {
      batch.set(ref, { ...data, createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    }

    inBatch += 1;
    totalWrites += 1;
    if (inBatch >= BATCH_LIMIT) {
      if (!dryRun) await batch.commit();
      console.log(`Committed ${inBatch} writes...`);
      batch = db.batch();
      inBatch = 0;
    }
  }

  if (inBatch > 0) {
    if (!dryRun) await batch.commit();
    console.log(`Committed ${inBatch} writes...`);
  }

  console.log(dryRun ? `Dry run OK (${totalWrites} writes skipped).` : `Done. Upserted ${totalWrites} coupons.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

