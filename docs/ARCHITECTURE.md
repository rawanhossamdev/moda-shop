# Architecture

## Flutter

`lib/models` represents products, complete variants, cart lines, addresses and order snapshots. `lib/repositories` wraps API operations and supports injected test repositories. Controllers own authentication, wishlist and recent-search state; shared scopes connect commerce state to screens. Existing Material widgets and shared MODA styles provide responsive layout, error/loading states and accessibility labels.

Cart state is device-local and revalidated with the catalog when restored. Selected variant IDs distinguish colors/sizes. Checkout recovery is stored securely per authenticated account, keeping the same request ID across uncertain retries. Cart settlement markers prevent a recovered order consuming the same purchased quantities twice. Logout/session expiry clears protected navigation without deleting the user's cart.

Images are bundled assets. Current catalog photography has a 3:4 source ratio matched by filled card/gallery frames; fullscreen retains the complete image and zoom. Product-level wishlist behavior is intentionally independent from a particular variant.

## Node API and database

Express routes authenticate/authorize requests and delegate input validation and business rules to services. Repositories own Prisma/PostgreSQL access. The backend resolves product availability, allowed variants, integer-cent unit prices, shipping and final totals; client prices are not trusted.

Addresses and orders are bound to the authenticated user. COD order creation uses transactions, stable client request IDs and database-backed duplicate-request protection. Orders snapshot product names, variant/color/size labels, prices, image references and shipping details. Historical records remain meaningful when products or addresses change. Order state and payment state are separate.

Schema migrations preserve existing rows; known legacy demo records are projected into the richer color/variant model. ProductSize compatibility is retained. The catalog seed is transactional, create-only and repeatable, skipping non-demo owner collisions and preserving existing prices/availability.

## Boundaries

The server requires PostgreSQL for real catalog/commerce operations. Sessions and sensitive recovery information are kept out of source control. Tests inject synthetic repositories/providers and use local HTTP listeners. Optional SQL verification scripts roll synthetic writes back. Resend and disabled payment sandbox code are external boundaries, not required test dependencies.

COD checkout requires email verification. With mail disabled, new users can register/login/browse but cannot complete interactive verification; tests exercise that gate and verified-account checkout without sending mail. There is no public shared demo account, admin dashboard, live payment activation or production deployment in this source set.
