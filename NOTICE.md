# Notice

This repo includes code and sample data from the Pronto sample app:

- Source: https://github.com/trailheadapps/pronto, commit `5d2659f` (Oct 4, 2026)
- License: Apache License 2.0 (see `LICENSE.md`)
- Included in: `pronto/`, `data/`, `apex-scripts/`, `.forceignore`

Changes from the original: the customer-service channel (Experience Cloud site, messaging, queues, service agents, and their flows) was removed; `GetStorefrontFromNameAction`, its test, and the `Employee_Assistant` agent were replaced by the HXL versions in `hxl/`; and the `Merchant_Management_App` permission set was moved from `src-headless` into `pronto/`. See "What's different from Pronto" in `README.md`.
