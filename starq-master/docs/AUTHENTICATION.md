# STARQ Authentication Architecture

## Overview
STARQ uses a stateless JWT-based authentication system built with NestJS on the backend and secure Provider-based state management on the Flutter frontend. 

## Backend Setup
- **Framework & Libraries:** NestJS, `@nestjs/jwt`, `@nestjs/passport`, `bcryptjs`.
- **Strategy:** `JwtStrategy` validates Bearer tokens.
- **Passwords:** Hashed with `bcryptjs` (salt rounds: 10). NEVER stored in plaintext.
- **Entities:** `User` has been extended with a `Role` enum (CUSTOMER, ADMIN, PARTNER) and `password` string.
- **Environment:** `JWT_SECRET` loaded dynamically via `@nestjs/config`.

## Endpoints
- `POST /auth/register`: Validates DTO, hashes password, prevents duplicate email/phone, returns JWT.
- `POST /auth/login`: Verifies bcrypt hash, issues JWT.
- `GET /auth/me`: Protected by `JwtAuthGuard`, returns current user profile (omitting password hash).

## Frontend Setup
- **State Management:** `AuthProvider` extends `ChangeNotifier`.
- **Storage:** `SecureStorageService` securely persists access tokens via EncryptedSharedPreferences/Keychain.
- **Routing:** `GoRouter` uses `refreshListenable: authProvider` to actively guard routes. Unauthenticated users are safely redirected to `/sign-in`. Authenticated users are directed to `/home`.

## Security Implementations
- Passwords are fully hashed in Postgres.
- `JwtAuthGuard` secures protected endpoints.
- Flutter NEVER logs or exposes the raw JWT secret.
- Stack traces and Prisma errors are sanitized and mapped to correct HTTP exceptions (e.g., `ConflictException`).
