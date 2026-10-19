---
name: freshora-ui-review
description: Improve FRESHORA Flutter usability and accessibility, including visible filters, small-screen layouts, address forms, keyboard behavior, loading, empty and failure states. Use for customer UI feedback and pre-release UX review.
---
# Review customer UI
1. Read AGENTS.md, existing mobile/ themes and widgets. Keep existing branding and business behavior.
2. Inspect login, catalog/filter selection and deselection, cart, address add/edit, account and order tracking. Test narrow layouts and large text with the keyboard open.
3. Claim owned files and isolate changes from authentication and checkout logic.
4. Make controls readable, tappable and visibly selected. Keep field labels/errors clear, allow scrolling and provide retry or empty states.
5. Add widget regressions for the actual layout or interaction problem. Run formatting checks, flutter analyze and focused tests before the full suite.
6. Compare emulator/device screenshots before and after. If no runtime is available, explicitly report visual verification as pending.
7. Open a scoped PR with the affected flow, evidence and checks; use latest-commit CI and resolve real failures before merge.
