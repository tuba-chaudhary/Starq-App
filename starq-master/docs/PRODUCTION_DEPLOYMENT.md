# STARQ - Render Deployment Guide

This guide provides exact, beginner-friendly instructions to deploy your NestJS backend on **Render.com**. 
Your Neon PostgreSQL database is already verified and ready.

## Step 1: Create a Web Service on Render
1. Log into your [Render Dashboard](https://dashboard.render.com).
2. Click **New +** and select **Web Service**.
3. Select **Build and deploy from a Git repository**.
4. Connect your GitHub/GitLab account and select the STARQ repository.

## Step 2: Configure the Render Web Service
Fill out the service details exactly as follows:
- **Name:** `starq-api` (or your preferred name)
- **Region:** Choose the region closest to your primary customers (e.g., Singapore for India).
- **Branch:** `main` (or whichever branch holds your production code)
- **Root Directory:** `backend` *(Crucial: This tells Render to look inside the backend folder!)*
- **Runtime:** `Node`
- **Build Command:** `npm install && npx prisma generate && npm run build`
- **Start Command:** `npm run start:prod`

## Step 3: Add Environment Variables
Scroll down to the **Environment Variables** section. Add the following keys (fill in your real secrets, but NEVER commit them):

| Key | Value | Description |
|---|---|---|
| `NODE_ENV` | `production` | Tells NestJS to run in prod mode. |
| `DATABASE_URL` | `postgresql://...` | Your exact Neon database connection string. |
| `PORT` | `10000` | Render dynamically assigns ports, but setting a default is safe. |
| `CORS_ORIGIN` | `https://your-admin-panel.com` | Only if you have a web portal. For the Flutter app, you can leave this blank or restrict it securely. |
| `JWT_SECRET` | *(Your secure random string)* | Used for signing auth tokens. |
| `RAZORPAY_KEY_ID` | `rzp_live_...` | From Razorpay Dashboard -> API Keys. |
| `RAZORPAY_KEY_SECRET` | *(Your Live Secret)* | From Razorpay Dashboard. |
| `RAZORPAY_WEBHOOK_SECRET` | *(Your Webhook Secret)* | Ensure this exactly matches what you put in Razorpay. |
| `FIREBASE_PROJECT_ID` | *(Your Firebase ID)* | Required for push notifications. |
| `FIREBASE_CLIENT_EMAIL` | *(Your Firebase Email)* | From Service Account JSON. |
| `FIREBASE_PRIVATE_KEY` | *(Your Firebase Private Key)* | Ensure line breaks (`\n`) are preserved properly in Render! |

## Step 4: Deploy and Verify
1. Click **Create Web Service**.
2. Render will automatically pull the code, install dependencies, run Prisma generation, build the NestJS app, and start it.
3. Wait for the logs to say `STARQ API running on port...` and `Build successful`.
4. **Verification:** Click the URL provided by Render at the top left (e.g., `https://starq-api.onrender.com`). Add `/api/v1/health` to the end of the URL.
   *Example:* `https://starq-api.onrender.com/api/v1/health`
   *Expected Output:* `{"ok":true,"timestamp":"..."}`

## Step 5: Applying Database Migrations
Since your Neon database already reports `Database schema is up to date`, you do **not** need to run migrations right now.
However, for future updates, you can apply migrations safely on Render by either:
1. Using Render's "Shell" tab to run: `npx prisma migrate deploy`
2. Or changing your Build Command to: `npm install && npx prisma generate && npx prisma migrate deploy && npm run build`

## Step 6: Link to Flutter App
Once your Render deployment is verified via the `/health` endpoint:
1. Open `lib/core/config/env_config.dart` in your Flutter project.
2. Update the `kReleaseMode` fallback URL to match your Render URL:
   `return 'https://starq-api.onrender.com/api/v1';`
3. Also update your local `.env` if you want to test against production (not recommended for daily dev).
