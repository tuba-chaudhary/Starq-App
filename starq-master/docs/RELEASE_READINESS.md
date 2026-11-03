# STARQ Release Configuration Checklist

## Current Status Overview

- **BACKEND DEPLOYMENT**: **MANUAL** (Requires provisioning cloud compute & running `npm run start:prod`)
- **DATABASE**: **MANUAL** (Requires executing `prisma migrate deploy` on production URL)
- **RAZORPAY**: **MANUAL** (Requires toggling to Live Mode and inserting real keys into `.env`)
- **FIREBASE**: **MANUAL** (Requires placing `google-services.json` and `.plist` into the Flutter repo locally)
- **GOOGLE MAPS**: **MANUAL** (Requires restricting actual production Maps API keys in Google Cloud)
- **ANDROID SIGNING**: **MANUAL** (Requires generating a JKS Keystore for Google Play)
- **AAB**: **BLOCKED** locally by sandbox (Requires you to run `flutter build appbundle --release` manually)
- **HTTPS**: **MANUAL** (Requires SSL configuration on your VPS/Server)
- **CORS**: **READY** (Configured via `CORS_ORIGIN` env variable cleanly)
- **PLAY STORE**: **MANUAL** (Requires publishing the AAB to the internal track)

*Everything architectural inside the source code is **READY**; the final remaining tasks are operational cloud setups.*
