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

function asNumber(v, fieldName) {
  if (v === undefined || v === null || v === '') return null;
  const n = Number(String(v).trim());
  if (!Number.isFinite(n)) {
    die(`Invalid number for ${fieldName}: ${v}`);
  }
  return n;
}

function readCsv(csvPath) {
  const text = fs.readFileSync(csvPath, 'utf8');
  return parse(text, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
  });
}

function makeNaverSearchUrl({ name, address }) {
  const q = [name, address].filter(Boolean).join(' ').trim();
  if (!q) return '';
  return `https://m.search.naver.com/search.naver?query=${encodeURIComponent(q)}`;
}

async function main() {
  const argv = minimist(process.argv.slice(2));

  const serviceAccountPath = argv.serviceAccount || argv.service_account;
  const csvPath = argv.csv;
  const projectId = argv.projectId || argv.project_id;
  const dryRun = asBool(argv.dryRun ?? argv.dry_run, false);

  if (!serviceAccountPath) {
    die('Missing --serviceAccount path to Firebase service account JSON');
  }
  if (!csvPath) {
    die('Missing --csv path to places CSV (e.g. ../../documents/planning/places_template.csv)');
  }

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

  if (!rows.length) {
    die('CSV has no rows.');
  }

  console.log(`Loaded ${rows.length} rows from ${resolvedCsv}`);

  // Use up to 500 writes per batch.
  const BATCH_LIMIT = 450;
  let batch = db.batch();
  let inBatch = 0;
  let totalWrites = 0;

  for (const r of rows) {
    const id = (r.id || '').trim();
    const name = (r.name || '').trim();

    const lat = asNumber(r.lat, 'lat');
    const lng = asNumber(r.lng, 'lng');

    if (!name) {
      die(`Missing name for row id=${id || '(empty)'}`);
    }
    if (lat === null || lng === null) {
      die(`Missing lat/lng for row name=${name}`);
    }

    const docId = id || db.collection('places').doc().id;
    const ref = db.collection('places').doc(docId);

    const openingHours = (r.openingHours || '').trim() || '매일 10:00-22:00';
    const naverPlaceUrl =
      (r.naverPlaceUrl || '').trim() ||
      makeNaverSearchUrl({ name, address: (r.address || '').trim() });

    const data = {
      name,
      lat,
      lng,
      address: (r.address || '').trim(),
      category: (r.category || '').trim(),
      openingHours,
      naverPlaceUrl,
      hasCoupons: asBool(r.hasCoupons, false),
      isActive: asBool(r.isActive, true),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Only set createdAt on first creation.
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

  console.log(dryRun ? `Dry run OK (${totalWrites} writes skipped).` : `Done. Upserted ${totalWrites} places.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
