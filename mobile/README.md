# Talegaon Fresh Flutter Customer App

## Architecture

Flutter Customer App
  -> Home / Products / Product Details
  -> Cart / Checkout
  -> UPI / COD
  -> Order Confirmation / Tracking
  -> My Orders / Profile
  -> FastAPI Backend
  -> PostgreSQL
  -> Razorpay

WhatsApp remains an optional channel and is not required for the mobile app.

## Planned API integration

- Product catalog -> GET /products
- Customer identity
- Cart and order creation
- Address APIs
- Razorpay payment flow via authenticated customer payment-link API
- Order tracking/status
- Loading/error/empty states

No secrets are stored in the mobile application.

## Product API configuration

The app reads the customer catalogue from `GET /products`.

By default it uses the deployed Talegaon Fresh backend:
`https://talegaon-fresh-ai-backend.onrender.com`

For another environment, pass the API base URL without a trailing slash:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.example.com
```

No API secrets are stored in the mobile application. When a customer session has a token, the mobile product API sends it as a Bearer token in the Authorization header. A `401 Unauthorized` response is treated as an expired session and signs the customer out.

## Local development

cd mobile
flutter pub get
flutter run

flutter test

## Customer authentication

The customer app uses an injectable authentication repository for mobile-number + 6-digit PIN authentication.

- Demo mode is used by local/widget tests and accepts PIN `123456`.
- Remote mode uses `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, and `POST /auth/logout-session`.
- Remote authentication expects `access_token`, `refresh_token`, and an optional `customer` object containing `phone` and `name`.
- Configure the backend base URL with `AUTH_BASE_URL`.
- Enable remote authentication with `AUTH_MODE=remote`.

Example:

```bash
flutter run \
  --dart-define=AUTH_MODE=remote \
  --dart-define=AUTH_BASE_URL=https://your-api.example.com
```

For a production build, do not ship demo authentication. The release build must use `AUTH_MODE=remote` and the production backend URL. Never put backend secrets, admin tokens, or signing credentials in `--dart-define` values.

No OTPs, API keys, or JWT secrets are stored in the mobile application. The authenticated customer token is persisted locally for session restoration and removed on sign out. The deployed backend must implement the documented authentication endpoints before remote mode is enabled for production.

## Customer address management

The authenticated customer can open **My Addresses** from Profile to add, edit, and delete saved delivery addresses. When a JWT session is active, the UI uses `GET/POST /customers/me/addresses` and `PUT/DELETE /customers/me/addresses/{id}` with the customer Bearer token. Address edits preserve the server-side address ID and default-address flag. Demo/local sessions continue to use local storage.

## Customer order API

Authenticated sessions use the server-side customer order APIs for checkout and order history: `POST /customers/me/orders`, `GET /customers/me/orders`, and `GET /customers/me/orders/{id}`. The server-side order ID is retained for payment and tracking. UPI checkout calls `POST /customers/me/orders/{id}/payment-link` and opens the returned Razorpay payment link. Order tracking and order history can refresh status from the backend.

Checkout totals are calculated from catalog prices by the backend. Delivery is ₹20 for product subtotals below ₹199 and free at or above ₹199. The customer app validates `FRESH10` (10% off, up to ₹50), `WELCOME50` (₹50 off the first order with a product subtotal of ₹499 or more; eligibility is verified by the backend), and `FRESHORA20` (20% off, up to ₹100, orders of ₹499 or more) through `POST /customers/me/promos/validate`. Each account receives a server-generated referral code from `GET /customers/me/referral-code`; it gives a new customer 20% off up to ₹100 on their first order of ₹499 or more. The order API validates the code again and stores the resulting discount and delivery fee on the order.

## Customer cart API

Authenticated sessions use the server-side cart through `GET /customers/me/cart`, `PUT /customers/me/cart`, and `DELETE /customers/me/cart`. Cart synchronization failures are surfaced in the cart UI with a retry action rather than silently replacing the server cart with stale local data. A `401 Unauthorized` response ends the customer session.

## Production customer flow

1. Sign in with remote OTP authentication.
2. Load products and the authenticated customer cart.
3. Add or update a saved delivery address.
4. Create an order through the customer API.
5. For UPI, create a Razorpay payment link and complete payment on the hosted page.
6. Refresh order status from the backend after payment/webhook processing.
7. View the server-side order history and tracking status.

The deployed backend must have its authentication, database, and Razorpay webhook configuration completed before enabling customer traffic.

## Product details

Customers can tap any product card to open a product details screen, review the unit price, choose a quantity, and add the selected quantity to the cart in one action.

## Order details

Completed mobile orders retain an item snapshot locally. Customers can open an order from **My Orders** to review each item, quantity, unit price, order total, payment method, delivery address, and the existing tracking view.

## Favorites

Customers can save products to **My Favorites** from the product cards. Favorites are stored locally per customer mobile number, survive app restarts, and are cleared when that customer signs out.
