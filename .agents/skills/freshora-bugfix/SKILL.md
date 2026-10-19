---
name: freshora-bugfix
description: Diagnose and fix FRESHORA Flutter customer bugs, including login, account crashes, address validation, cart totals, checkout and order status. Use for tester feedback and regression repairs in freshora-customer-app.
---
# Fix customer bugs
1. Read AGENTS.md and current mobile/ implementation; verify the backend API contract before changing request or response fields.
2. Reproduce the reported scenario or document the exact static evidence and reproduction gap. Prioritize crashes, login, address saving, incorrect totals and failed orders.
3. Use an isolated branch and claim file ownership before editing. Keep UI and backend workstreams informed of contract changes.
4. Add a focused regression for the failure. Preserve saved credentials during temporary network/server failures; clear invalid credentials only when invalidity is established.
5. From mobile/, run flutter pub get, flutter analyze and the relevant flutter test target, followed by the full suite before review. Record unavailable tools as unverified; never claim success from source inspection.
6. Review the diff and submit one coherent PR. Check CI for its latest commit; diagnose the first failure and batch related corrections. Do not rerun an unchanged failure.
7. Retest the affected customer flow on an emulator/device before marking it launch ready.
