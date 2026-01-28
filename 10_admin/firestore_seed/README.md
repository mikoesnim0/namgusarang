# Firestore Seed (places)

This folder contains scripts to seed Firestore collections for development.

## What you need
- Firebase service account key JSON file.
  - Download from Firebase Console: Project settings -> Service accounts -> Generate new private key.
- Put the JSON file here as `serviceAccountKey.json` (it is gitignored).

## Scripts
- `seed_places.js`: seeds `/places`
- `seed_user_coupons.js`: seeds `/users/{uid}/coupons`

## Input CSV
Default CSV path (relative to this folder):
- `../../documents/planning/places_template.csv`

CSV headers:
- `id` (optional): document id. If empty, an auto id is generated.
- `name` (required)
- `address` (optional)
- `category` (optional)
- `lat` (required, number)
- `lng` (required, number)
- `hasCoupons` (optional, true/false)
- `isActive` (optional, true/false)

## Run
Dry run (validate CSV, no writes):

```bash
npm run seed_places_dry
```

Seed (upsert into `places`):

```bash
npm run seed_places
```

Custom paths:

```bash
node seed_places.js --serviceAccount /path/to/key.json --csv /path/to/places.csv
```

## User coupons seed

Seeds coupons into the signed-in user's scope:

`/users/{uid}/coupons/{couponId}`

Template CSV path:
- `../../documents/planning/coupons_template.csv`

Run:

```bash
node seed_user_coupons.js --serviceAccount serviceAccountKey.json --csv ../../documents/planning/coupons_template.csv --uid YOUR_UID
```

Dry run:

```bash
node seed_user_coupons.js --serviceAccount serviceAccountKey.json --csv ../../documents/planning/coupons_template.csv --uid YOUR_UID --dryRun true
```
