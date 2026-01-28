#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const admin = require('firebase-admin');
const minimist = require('minimist');

function die(msg) {
  console.error(msg);
  process.exit(1);
}

function csvEscape(v) {
  const s = String(v ?? '');
  if (s.includes('"') || s.includes(',') || s.includes('\n') || s.includes('\r')) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function toBool(v, fallback = false) {
  if (typeof v === 'boolean') return v;
  if (v == null) return fallback;
  const s = String(v).trim().toLowerCase();
  if (['true', '1', 'yes', 'y'].includes(s)) return true;
  if (['false', '0', 'no', 'n'].includes(s)) return false;
  return fallback;
}

async function main() {
  const argv = minimist(process.argv.slice(2));

  const serviceAccountPath = argv.serviceAccount || argv.service_account;
  const projectId = argv.projectId || argv.project_id;
  const outPath = argv.out || argv.output || '../../documents/planning/places_export.csv';

  if (!serviceAccountPath) {
    die('Missing --serviceAccount path to Firebase service account JSON');
  }

  const resolvedServiceAccount = path.resolve(process.cwd(), serviceAccountPath);
  if (!fs.existsSync(resolvedServiceAccount)) {
    die(`Service account file not found: ${resolvedServiceAccount}`);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(resolvedServiceAccount, 'utf8'));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: projectId || serviceAccount.project_id,
  });

  const db = admin.firestore();
  const snap = await db.collection('places').get();
  const docs = snap.docs.slice().sort((a, b) => a.id.localeCompare(b.id));

  const headers = [
    'id',
    'name',
    'address',
    'category',
    'lat',
    'lng',
    'hasCoupons',
    'isActive',
    'openingHours',
    'naverPlaceUrl',
  ];

  const lines = [];
  lines.push(headers.join(','));

  for (const d of docs) {
    const data = d.data() || {};
    const row = {
      id: d.id,
      name: (data.name || '').toString(),
      address: (data.address || '').toString(),
      category: (data.category || '').toString(),
      lat: data.lat ?? '',
      lng: data.lng ?? '',
      hasCoupons: toBool(data.hasCoupons, false),
      isActive: toBool(data.isActive, true),
      openingHours: (data.openingHours || '').toString(),
      naverPlaceUrl: (data.naverPlaceUrl || '').toString(),
    };

    lines.push(headers.map((h) => csvEscape(row[h])).join(','));
  }

  const resolvedOut = path.resolve(process.cwd(), outPath);
  fs.writeFileSync(resolvedOut, lines.join('\n') + '\n', 'utf8');
  console.log(`Exported ${docs.length} places to ${resolvedOut}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

