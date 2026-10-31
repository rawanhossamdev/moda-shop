# MODA Shop — Flutter developer portfolio

## What this demonstrates

MODA is a fashion-commerce portfolio MVP with a Flutter client, an Express API and PostgreSQL persistence. It demonstrates product modeling, responsive Flutter UI, asynchronous state/error handling and backend validation across a complete sample shopping flow. It is not a live retail business or production-readiness claim.

## Engineering decisions

| Problem | Implementation |
|---|---|
| Clothing sizes leaking into bags | Product-specific variants, One Size and footwear labels from API data |
| Color/size mismatches | Stable complete-variant IDs, disabled invalid combinations, server revalidation |
| Cart loss or outdated prices | Secure local persistence, restore/revalidate and clear availability notices |
| Uncertain checkout / repeated taps | Account-scoped pending request IDs, server idempotency, transactions and one-time settlement markers |
| Historical orders changing with catalog edits | Product/price/variant/address/image snapshots |
| Authentication and ownership | Secure token storage, JWT/bcrypt and server checks for addresses/orders |
| Photography with letterboxing | Local 3:4 assets, filled rounded cards, shared gallery framing and fullscreen zoom |
| Accessible category discovery | Swipeable chips plus labeled scroll controls, preserving the outline icon system |
| Honest demonstration pricing | Clean card prices with a visible catalog-level demo disclosure and detailed sample information |

## Scope

Catalog/search/filtering/sorting, wishlist, persistent cart, account flows, addresses, verified-account COD checkout/recovery and order history are implemented. The project also includes labeled Help content, recent search, branded startup and adaptive Android icons.

Resend delivery requires authorized external configuration. The documented defaults send no real mail. COD starts Pending / Unpaid; live online payments, real inventory, fulfillment, production hosting and an admin dashboard are outside this portfolio scope.

## Evidence

- [Screenshots](README.md#screenshots): emulator captures of demonstration products, with no customer information.
- [Architecture](docs/ARCHITECTURE.md): separation of client state/repositories, routes/services and persistence.
- [Preparation report](docs/PUBLICATION_REPORT.md): reproducible checks and current test results.
- [Release checklist](docs/RELEASE_CHECKLIST.md): explicit owner decisions before publication.

No metrics, business outcomes, real customers, production traffic or payment processing are claimed. Test data and catalog merchandise are synthetic. This case study describes implemented behavior and validation rather than claiming business outcomes or production traffic.

## Suggested GitHub metadata

- Repository: `moda-shop`
- Description: `Flutter fashion-commerce portfolio with an Express/PostgreSQL API, product variants, persistent cart and idempotent COD checkout.`
- Topics: `flutter`, `dart`, `nodejs`, `express`, `postgresql`, `prisma`, `ecommerce`, `portfolio`, `cash-on-delivery`, `rest-api`.

## Copyright and review-only source

Copyright © 2026 MODA Shop project owner, for owner-authored material. All rights reserved. Source is publicly visible for portfolio review, with no project-granted permission to copy, redistribute, modify, or commercially reuse it. No software reuse license or root LICENSE is provided. Applicable-law rights and GitHub's terms, including viewing and platform forking, remain unaffected; see [GitHub's licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).

Third-party dependencies, images, icons and files with pre-existing separate notices retain their own terms; no ownership of third-party assets is claimed. Existing geometric-art/drawing-source CC0 permissions are not revoked. The unresolved asset provenance gaps still block publication; see [image provenance](docs/IMAGE_PROVENANCE.md).
