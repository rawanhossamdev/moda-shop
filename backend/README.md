# MODA Shop API

Express/PostgreSQL/Prisma backend for the Flutter portfolio demo. The root [README](../README.md) is the current installation and safety guide.

## Start locally

1. Install a supported Node version (`^22.12.0 || >=24.0.0`) and PostgreSQL.
2. Copy `.env.example` to private `.env` only if one does not exist, and set your own database URL. Do not overwrite existing credentials.
3. Keep email delivery and Paymob disabled for safe local work.
4. Run the following in this directory:

```text
npm ci
npm run auth:secret
npm run prisma:generate
npm run db:migrate
npm run db:seed
npm start
```

The API defaults to `http://127.0.0.1:3000/api`. The Android Emulator uses `http://10.0.2.2:3000/api` to reach the host. No absolute SDK paths or private account credentials are required in source control.

## Data and behavior

The seed adds 24 demo products across five categories with stable color/size variant IDs and media. Existing owner data, prices and availability are preserved. Migrations are additive/targeted transformations of known demo records; historical order snapshots remain. Review migrations and back up existing databases. Never reset, truncate or drop data to install this project.

Routes cover health/catalog, authentication/profile/verification/recovery, user-owned addresses, checkout quotes and idempotent COD orders/history. User ownership and variant/quantity/availability checks run server-side. Prices and totals are resolved in the backend. Transactions protect order creation; order status and payment status remain distinct.

Unverified accounts cannot place orders. Registration/login remain available with mail disabled, but sending verification/recovery codes requires authorized Resend configuration. No users, real customer data or shared passwords are seeded. COD is the documented active payment path; disabled sandbox payment code is not a production payment feature.

## Verification

```text
npm test
npm run check
npm run prisma:validate
```

Regular tests use synthetic repositories and local HTTP listeners, without PostgreSQL or provider credentials. Read-only `npm run api:verify` and rollback-only `npm run catalog:verify` / `npm run commerce:verify` require a migrated/seeded local development database. Neither sends emails nor charges money. Optional provider/email scripts must not be run as part of publication preparation.

See [architecture](../docs/ARCHITECTURE.md), [image provenance](../docs/IMAGE_PROVENANCE.md) and the [release checklist](../docs/RELEASE_CHECKLIST.md). Private `.env`, logs, database exports, dependencies and keys are excluded from Git; `.env.example`, lockfiles, source and migrations belong in the public source set.
