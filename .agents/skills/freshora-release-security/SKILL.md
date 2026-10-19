---
name: freshora-release-security
description: Audit FRESHORA customer/backend security and gather Play Store release evidence. Use for vulnerabilities, auth and session hardening, authorization, sensitive data, and release readiness.
---
# Verify security and release
1. Read AGENTS.md and current mobile/ code plus the actual backend repository. Audit source and isolated test environments; do not attack production.
2. Trace access and refresh token expiry, rotation and logout; verify server-side ownership on customer addresses/orders and privileged operations. Check validation, secret handling, transport and log redaction.
3. Demonstrate each finding using a focused regression. Distinguish confirmed vulnerabilities from untested concerns. Keep credentials and customer data out of output.
4. Fix in an isolated branch, preserve API contracts, and run the backend's declared checks plus app regressions when contracts change.
5. Before release, verify latest merged commit CI, real login/address/cart/order/logout flows, versionName/versionCode against the existing Play release, production endpoint, signed AAB and correct package ID. Never assume main's version is higher.
6. Inspect current privacy/data safety/account deletion and permissions requirements against the app's behavior. Check current official Play documentation when policy decisions are needed.
7. Report outstanding failures, missing device tests and signing evidence as launch blockers. Build success alone is not end-to-end or security approval.
