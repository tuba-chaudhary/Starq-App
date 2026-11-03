# STARQ Backend

PostgreSQL API for the STARQ customer app. Pricing, payments, partner assignment, and booking state live here. The Flutter client never calculates payable amounts.

## Required credentials

Copy `backend/.env.example` to `backend/.env`.

| Variable | Required | Purpose |
|---|---|---|
| `DATABASE_URL` | Yes | PostgreSQL connection |
| `JWT_ACCESS_SECRET` | Yes | Access token signing |
| `JWT_REFRESH_SECRET` | Yes | Refresh token signing |
| `RAZORPAY_KEY_ID` | For payments | Public Razorpay key (also sent to Flutter) |
| `RAZORPAY_KEY_SECRET` | For payments | **Server only.** Never put this in Flutter. |
| `RAZORPAY_WEBHOOK_SECRET` | For webhooks | Dashboard webhook signing secret |
| `SMS_PROVIDER_API_KEY` | For OTP | OTP endpoints return HTTP 503 until this is set |
| `APP_BASE_URL` | Recommended | Hosted checkout links |

Razorpay test keys: https://dashboard.razorpay.com/app/keys

Webhook URL: `POST {APP_BASE_URL}/api/v1/payments/webhook`

If Razorpay keys are missing, `POST /api/v1/payments/create-order` returns **503**. It does **not** mark bookings paid.

## Run locally

```bash
docker compose up -d postgres
cd backend
cp .env.example .env
npm install
npm start
```

API: `http://localhost:3000/api/v1`  
Health: `http://localhost:3000/health`  
Admin desk: `http://localhost:3000/admin`  
Partner GPS/jobs: `http://localhost:3000/partner`

Seeded accounts:

- Admin: `admin@starq.in` / `Admin@12345`
- Partner: `partner1@starq.in`, `partner2@starq.in`, `partner3@starq.in` / `Partner@123`

## Android emulator

Use `API_BASE_URL=http://10.0.2.2:3000/api/v1` in the Flutter `.env`.
