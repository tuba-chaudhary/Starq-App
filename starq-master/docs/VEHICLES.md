# Vehicle Management

## Database
- Added `category String?` to the `Vehicle` model in `schema.prisma`.
- Seeded `VehicleType` (CAR and BIKE).

## Endpoints
- `GET /vehicles`: Retrieve all vehicles owned by the authenticated customer.
- `GET /vehicles/:id`: Retrieve a specific vehicle.
- `POST /vehicles`: Add a new vehicle.
- `PATCH /vehicles/:id`: Edit a vehicle.
- `DELETE /vehicles/:id`: Delete a vehicle.

## Security
- Validated via `JwtAuthGuard`.
- All CRUD actions strictly ensure the `userId` in the JWT matches the `userId` of the vehicle to prevent data leaks or unauthorized modifications.

## Flutter Integration
- Modeled strictly in `lib/features/models/vehicle_model.dart`.
- Handled efficiently by `VehicleProvider`.
- Integrated directly into `MyGarageScreen` to strip out prototype/hardcoded placeholders.
