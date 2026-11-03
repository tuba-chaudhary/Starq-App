# Services, Add-ons, and Pricing

## Catalogs
- `GET /services`: Returns DB-backed services and their associated `ServiceVariant` nodes.
- `GET /addons`: Returns DB-backed add-ons (e.g. Freshener, Tyre Shine).

## Authoritative Pricing
- **Pricing Strategy:** We do *not* trust the client to compute final prices.
- **Endpoint:** `POST /pricing/quote`
- **Request Body:**
  ```json
  {
    "vehicleId": "uuid",
    "serviceId": "uuid",
    "addonIds": ["uuid1", "uuid2"]
  }
  ```
- **Backend Flow:**
  1. Validates `vehicleId` belongs to the authenticated user.
  2. Fetches `Service` and finds the appropriate `ServiceVariant`.
  3. Sums prices for requested `addonIds`.
  4. Returns `subtotal`, `taxes`, and `total`.

## Flutter Integration
- Modeled strictly in `lib/features/models/`.
- Logic handled by `BookingProvider`.
- `ServiceSelectionScreen` actively loads DB nodes instead of using local arrays.
