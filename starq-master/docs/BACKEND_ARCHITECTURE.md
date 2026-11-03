# STARQ Backend Architecture

## Framework
- **Framework:** NestJS (TypeScript)
- **Database ORM:** Prisma
- **Database:** PostgreSQL

## Modular Structure
The backend is structured into domain-specific modules:
- **AuthModule:** Authentication, JWT handling.
- **UsersModule:** User profiles and management.
- **VehiclesModule:** Customer vehicles and garage management.
- **ServicesModule:** Core car/bike washing service catalog.
- **AddonsModule:** Extra services (Freshener, Tyre Shine, etc.).
- **AddressesModule:** Customer saved addresses.
- **BookingsModule:** Core booking logic, scheduling, and state machine.
- **PartnersModule:** Partner dispatch, availability, and tracking.
- **PaymentsModule:** Payment gateway integration (e.g., Razorpay) and checkout validation.
- **ReviewsModule:** Post-service customer feedback.
- **RewardsModule:** Points ledger and loyalty program.

## API & Documentation
- RESTful API endpoints exposed via NestJS Controllers.
- **Swagger UI** available at `/api/docs` (when running locally).
- DTOs validated using `class-validator`.

## Environment
- Secrets and DB connections managed securely via `.env`.
- Hardcoded secrets strictly forbidden.
