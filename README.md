# DARI Restaurant | مطعم داري

Arabic-first restaurant ordering and cashier app built with Flutter. The menu seed follows the two supplied DARI menu references; product images are intentionally left empty because those files are full-page menus, not individual food photos.

## Development

```sh
flutter pub get
flutter run -d chrome
flutter test
flutter analyze
```

The app opens at the cashier PIN screen. Development cashier/admin PIN is `1234`; connection settings use `2002`. These values live in `DevelopmentAuthRepository` and are not production authentication.

Open `/menu` for the public menu or `/menu?table=5` for a table session. QR links use the current web origin when available. Set `DARI_PUBLIC_BASE_URL` at build time to generate links for a deployed domain:

```sh
flutter build web --dart-define=DARI_PUBLIC_BASE_URL=https://restaurant.example
```

## Implemented

- Arabic RTL customer menu with category filtering, search, product variants, cart quantities, takeaway/delivery details, and table-aware orders.
- Cashier PIN, incoming/confirmed/all order filters, status changes, and dine-in/takeaway/delivery manual orders.
- Admin PIN, local product/category management, actual QR generation, copy/share, QR previews, and API/bridge configuration forms.
- Repository interfaces with a SharedPreferences development implementation for catalog, orders, and connection settings.
- Order, product, category, variant, and connection data models kept outside widgets.

## Development limits

The local repository only stores data on the current device. A customer's phone cannot deliver orders to a cashier device without a server. Connection testing therefore remains disconnected; no API, bridge, WebSocket, authentication provider, remote database, or push notification service is configured. QR links and print layouts can be generated and previewed, but physical printing and mobile app deep-link registration still require platform/service setup. SharedPreferences is development persistence, not secure storage for production credentials.

For production, provide authenticated endpoints such as `GET /categories`, `GET /products`, `POST /orders`, `GET /orders`, `PATCH /orders/{id}`, `GET /settings`, `POST /settings`, and `POST /connection/test`. The server must persist orders and publish order/status events over WebSocket or an equivalent real-time channel. Also configure a public HTTPS domain, proper staff authentication and roles, secret storage, printer/bridge adapters, and app deep links.

The appetizer labels `نقانق` and `جاجيك` have been checked against the supplied menu references.

## Supabase backend (orders, cashier sync, menu)

Without Supabase settings the app keeps using the local development repository.
With them, customer orders go to Supabase and the cashier reads them from there.

1. In the Supabase SQL Editor run `supabase/migrations/001_dari_schema.sql`,
   `supabase/migrations/002_fix_order_realtime_and_permissions.sql`,
   `supabase/migrations/003_product_image_storage.sql`, and
   `supabase/migrations/004_daily_order_numbers_and_processed_order_deletion.sql`,
   then `supabase/seed.sql` (menu data generated from `lib/data/menu_seed.dart` only).
2. Dashboard -> Authentication -> Users: create a staff user (email + password).
3. Authorize that user (replace the UUID with the user's id):

   ```sql
   insert into public.staff_profiles (user_id, role) values ('<auth-user-uuid>', 'admin');
   ```

4. Dashboard -> Database -> Replication: confirm `orders` is in the `supabase_realtime` publication
   (the migration adds it).

Build and run (the anon key is public by design; never use `service_role` in Flutter):

```sh
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
flutter build web --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" --dart-define=DARI_PUBLIC_BASE_URL=https://your-domain
```

Do not commit credentials. `.env` files are git-ignored; `.env.example` holds empty placeholders.

Security model: customers never write to `orders` directly; they call the `create_order` RPC, which
validates the source/type/customer fields and takes prices from `products`. Staff (Supabase Auth users
listed in `staff_profiles`) can read orders and change their status; processed-order deletion is
available only through staff-checked RPCs. The cashier PIN screen stays as a local gate and is followed
by a staff sign-in. Order numbers are assigned transactionally in PostgreSQL per Asia/Baghdad calendar
date and remain consumed after orders are deleted. The Admin -> Connection Settings screen is unchanged;
its connection test now reports Supabase reachability when configured.
