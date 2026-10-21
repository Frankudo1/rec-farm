# REC Livestock & Agro Farms Enterprises

**Growing Excellence, Feeding the Future.**

Production website for REC Livestock & Agro Farms Enterprises — a Nigerian livestock
and agro marketplace in lagos State. Fresh farm produce, livestock, eggs, fish,
supplies — all sourced with integrity and delivered cold & fresh.

- Live config-driven storefront (vanilla HTML/CSS/JS + Supabase)
- Full admin panel for products, orders, inventory, reviews, blog and more
- Ready for Vercel deployment with zero build step

---

## Features

- **Storefront** — homepage, shop with filters & search, product details, cart, checkout, order tracking
- **Policy support** — certain items (e.g. broiler meat, pigs) are marked *“Visit Farm to Purchase”* and cannot be ordered online
- **Supabase data layer** — all catalogue, settings, blog and review content is read live from Supabase (Row-Level Security enforced)
- **Graceful demo fallback** — before Supabase keys are added, the site runs on sample demo data so you can still explore the UI
- **Auth** — customer sign up/sign in via Supabase Auth; a `profiles.role` in the staff set unlocks the admin panel
- **Role-based access** — `owner`, `administrator`, `manager`, `seller` plus the legacy `admin` value; the DB (`is_admin`, `is_owner`, `is_staff`, `has_permission`) is the authority
- **Staff management** — owner/admin creates admin, manager or seller logins from `/rule/staff` through a secure serverless function (`api/admin-create-staff.js`) that uses the service-role key server-side
- **Admin panel** — `/rule` with dashboard KPIs, order status workflow, product CRUD + image upload, inventory, product batches, stock movements, categories, delivery zones, pickup stations, testimonials, product review moderation, blog, contact inbox, customers, site settings
- **Bulk / B2B & farm visits** — storefront request forms feed the **Bulk Requests** and **Farm Visits** admin pages
- **Quotations** — build and track per-customer quotes with line items, then print or export
- **Notifications inbox** — the admin topbar bell reads the `notifications` table (populated by DB triggers) and shows an unread badge
- **Product reviews** — signed-in customers rate and comment on each item; reviews go live only after an admin approves them (approve / hide / feature / delete)
- **Delivery zones** — fee + minimum order per zone drives a structured checkout tax
- **WhatsApp-first support** — one-click WhatsApp chat replaces a JS map, meeting the “no JS map library” requirement
- **SEO / polish** — semantic markup, OG tags, robots.txt, sitemap.xml, custom 404, SVG favicon & logo

---

## Tech Stack

| Layer     | Choice                                                        |
|-----------|---------------------------------------------------------------|
| Frontend  | Vanilla HTML5, CSS3, Vanilla JavaScript (no frameworks)       |
| Backend   | Supabase (PostgreSQL, Auth, Storage, Row-Level Security)      |
| Hosting   | Vercel (static, zero config)                                  |
| Fonts     | Fraunces (display) + Manrope (UI), via Google Fonts           |

---

## Project Structure

```
rec-livestock/                # <- repo root, deploy this directory as-is
├── index.html                 # Homepage (site entry point, stays at root)
├── pages/                     # All other storefront pages
│   ├── shop.html              # Shop / marketplace listing
│   ├── product.html           # Product detail
│   ├── cart.html / checkout.html
│   ├── order-success.html     # Order confirmation + tracking
│   ├── account.html           # Auth + order history
│   ├── about.html / contact.html
│   ├── blog.html / blog-post.html
│   └── privacy.html / terms.html / 404.html
├── rule/                      # Restricted area (requires a staff role)
│   ├── login.html / index.html
│   ├── products.html / orders.html / inventory.html
│   ├── categories.html / delivery.html / pickups.html
│   ├── testimonials.html / reviews.html / customers.html
│   ├── blog.html / messages.html / settings.html
│   ├── staff.html / assignments.html / sales.html
│   ├── stock_requests.html / activity.html / profile.html
│   └── (bulk request / farm visit / quotation pages served from here)
├── api/                       # Vercel serverless functions
│   ├── sitemap.js             # Dynamic sitemap from Supabase
│   ├── verify-payment.js      # Paystack payment verification
│   └── admin-create-staff.js  # Owner/admin: create staff logins (service-role)
├── css/
│   └── style.css              # Single stylesheet: tokens, layout,
│                              # components, storefront + admin
├── js/
│   └── app.js                 # Single bundle: config, UI helpers, auth,
│                              # data layer, storefront + admin controllers
├── assets/
│   ├── logo/                  # rec-logo.jpg (main logo / favicon)
│   ├── icons/                 # svg sprite (sprite.svg)
│   └── images/                # hero, categories, product photos
├── docs/
│   └── design-reference.png   # Reference mockups (not deployed content)
├── supabase/
│   ├── schema.sql             # Full schema + RLS + triggers + storage
│   ├── seed.sql               # Sample categories, products, settings, zones…
│   └── update-*.sql           # Incremental migrations (run in order)
└── vercel.json / robots.txt / .env.example / .gitignore
```

> `js/app.js` and `css/style.css` are intentionally single, dependency-free
> files — the site has no build step, so everything ships as-authored.

### Supabase migrations (run in this order)

| # | File | Adds |
|---|------|------|
| 1 | `schema.sql` | Tables, indexes, RLS, triggers, `rec-media` bucket |
| 2 | `seed.sql` *(optional)* | Sample content — delete before launch |
| 3 | `update-admin-console.sql` | Roles, notifications, farm visits, quotations |
| 4 | `update-role-manager-seller.sql` | Manager/seller roles + permissions |
| 5 | `update-role-based-access.sql` | `has_permission`, assignments, stock requests |
| 6 | `update-egg-sizes.sql` | Egg-size catalogue values |
| 7 | `update-reviews-editing.sql` | Customer review editing |
| 8 | `update-remove-sample-testimonials.sql` | Drops seeded testimonials |
| 9 | `update-ops-access.sql` | RLS for the bulk/farm-visit/quotation/ops pages |
| 10 | `update-security-hardening.sql` | Pins `search_path`, closes internal RPCs, trims storage listing |

### Path convention

Pages live at different depths (`/`, `/pages`, `/rule`), so never hand-write
relative paths in JavaScript. `js/app.js` resolves the site root once from its
own script URL and exposes `REC.page`, `REC.admin`, `REC.asset` and `REC.sprite`:

```js
REC.page("shop")            // -> <root>/pages/shop.html
REC.page("cart") + "?id=4"
REC.asset("images/hero.png") // -> <root>/assets/images/hero.png
REC.sprite("i-cart")         // -> <root>/assets/icons/sprite.svg#i-cart
```

Both absolute URLs and `data:` / `blob:` / already-public values pass through
`REC.asset` untouched, so values straight from the database can be piped
through it safely.

Public URLs are kept stable by the `rewrites` in `vercel.json` — `/shop.html`,
`/shop` and `/pages/shop.html` all serve the same page, so the canonical tags
and `sitemap.xml` entries stay valid.

---

## Quick Start

```bash
# from the repo root:
# serve statically (any static server is fine):
python -m http.server 8080
# or
npx serve .
```

Open http://localhost:8080 — the site runs immediately using demo data.

---

## Connect Supabase

> The frontend uses only the **anon key** with Row-Level Security protecting every
> table. Never put your service-role key in browser code.

1. Create a project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** and run the migrations from `supabase/` **in the order
   listed above** — starting with `schema.sql` (tables, indexes, RLS, triggers,
   storage bucket `rec-media`) and finishing with
   `update-security-hardening.sql`.
3. Optional: run `supabase/seed.sql` to load sample products, categories, zones,
   a site-settings row and sample blog posts. Delete sample rows before going live.
4. The site reads its keys directly from `js/app.js` — the Supabase URL and
   **anon** key are committed there on purpose. The anon key is public by design
   and safe to ship to the browser; RLS protects every table.

```js
// js/app.js  (~line 23)
supabaseUrl: "https://<project>.supabase.co",
supabaseAnonKey: "your-anon-key",
```

> These client values are **not** read from Vercel environment variables — the
> site is fully static with no build step, so anything the browser needs must be
> in `app.js`. Env vars are only used by the serverless functions in `api/`
> (Paystack verification and staff creation), which run on the server.

### Create your first owner / admin user

Roles you can assign: `owner`, `administrator`, `manager`, `seller` (plus the
legacy `admin`, treated as full admin). Only **owner** is special — it can never
be granted from the browser, only from SQL.

1. In Supabase **Authentication → Users**, add the email you will use.
2. In **SQL Editor**, run (promote to **owner** for the first account; use
   `'administrator'` or `'manager'`/`'seller'` for other staff):

```sql
update public.profiles
set role = 'owner', full_name = 'Farm Owner'
where id = (select id from auth.users where email = 'you@example.com');
```

> `public.profiles` has **no `email` column** — join through `auth.users`, as above.
> `handle_new_user()` auto-creates the profile row (as `role = 'customer'`) the moment
> the auth user is created, so the row already exists before you promote it.
>
> Run this in the Supabase **SQL Editor**. `protect_profile_role` normally blocks role
> changes for non-admins, but it permits this one because the editor connects as
> `postgres`. A regular authenticated browser session is still refused, which is what
> stops a customer from promoting themselves.
>
> **If you see `P0001: Only the current owner can grant the owner role`**, disable the
> guard for the one statement and re-enable it immediately:
>
> ```sql
> alter table public.profiles disable trigger protect_profile_role;
> update public.profiles set role = 'owner', full_name = 'Farm Owner'
>   where id = (select id from auth.users where email = 'you@example.com');
> alter table public.profiles enable trigger protect_profile_role;
> ```

Verify it landed:

```sql
select p.role, u.email from public.profiles p
join auth.users u on u.id = p.id
where u.email = 'you@example.com';
```

3. Sign in at `https://<your-site>/rule/login.html` — done. After this, staff
   accounts can be created from **Owner panel → Staff → Add Staff** (which uses
   `api/admin-create-staff.js`, so it needs the service-role env var — see below).

### Storage (product/blog images)

`rec-media` is created by `schema.sql` as a **public bucket** (objects served via
`/storage/v1/object/public/...` with no policy needed). Writes are restricted to
admins, and `update-security-hardening.sql` replaces the broad public listing
policy with an admin-gated read policy — so clients can fetch images by URL but
cannot enumerate the whole bucket.

---

## Orders & Checkout

- Orders go into `public.orders`; the database trigger `assign_order_number` assigns
  references like `REC-2026-000001`.
- Items are stored as JSON (`items`), and a second trigger `sync_order_items`
  normalizes them into `order_items`.
- Fulfilment statuses: `pending → confirmed → processing → ready →
  out for delivery → completed` (or `cancelled`). Guests track orders on
  `order-success.html` via the `track_order(p_reference)` RPC — no sensitive data exposed.

---

## Deployment (Vercel)

The project is fully static — no build step.

1. Push to GitHub, then **Import Project → Vercel** and choose the repo.
2. Framework preset: **Other**. Output directory: leave as project root.
3. The storefront needs no env vars — the Supabase URL + anon key are inlined in
   `js/app.js`. The serverless routes need secrets (Vercel → Settings → Environment
   Variables):
   - `SUPABASE_URL` — required by `verify-payment.js` and `admin-create-staff.js`
   - `SUPABASE_SERVICE_ROLE_KEY` — required by both (never expose to the browser)
   - `PAYSTACK_SECRET_KEY` — only if you enable Paystack checkout
4. Attach your custom domain, confirm `robots.txt` / `sitemap.xml` resolve, and
   you're live.

`vercel.json` maps every public URL onto the file that serves it and sets
long-lived cache headers for `/assets`, no-cache for `/css` and `/js`.

---

## Launch Config Checklist

Work through this before announcing the site. Items marked **required** will break
a feature if skipped.

**Supabase — database**
- [ ] Run all migrations in order (`schema.sql` → `update-security-hardening.sql`)
- [ ] **required** Promote the first account to `owner` (see *Create your first owner*)
- [ ] **required** Re-run **Advisors → Security**; confirm the hardening advisories are cleared
- [ ] Delete any `seed.sql` sample products, categories, blog posts and testimonials
- [ ] Confirm RLS is enabled on every table (Table Editor → RLS badge)

**Supabase — auth & storage**
- [ ] Add your production domain under **Authentication → URL Configuration** (Site URL + redirects)
- [ ] Enable **leaked password protection** (Authentication → Policies)
- [ ] Confirm the `rec-media` bucket exists and is public

**Supabase — keys (copy into `js/app.js`)**
- [ ] `supabaseUrl` and `supabaseAnonKey` point at the production project
- [ ] The **anon** key is used (never the service-role key)

**Vercel**
- [ ] Set `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (and `PAYSTACK_SECRET_KEY` if used)
- [ ] Confirm `verify-payment.js` and `admin-create-staff.js` deploy without error
- [ ] Custom domain attached and HTTPS active

**Content & contact**
- [ ] Fill in site settings (name, phone, WhatsApp number, address, socials)
- [ ] Replace logo/hero imagery; upload real product photos
- [ ] Test a real order end-to-end and guest order tracking
- [ ] Test the bulk-request and farm-visit forms, then confirm they appear in the admin pages
- [ ] Send a test contact message and follow up from the admin inbox

---

## Security Notes

- RLS is enabled on every table; stores and the admin panel read under the anon
  key with policies doing the real gating.
- **Public form tables** (`bulk_quote_requests`, `contact_messages`, `customers`,
  `farm_visit_bookings`) intentionally allow anonymous `INSERT` — that is how the
  storefront submits forms. The Supabase linter flags these as `rls_policy_always_true`;
  that is expected.
- Staff access is enforced in the database, not the UI: `is_admin`, `is_owner`,
  `is_staff` and `has_permission` guard every privileged table.
- `track_order` is the only RPC the browser calls, and it returns only order
  status/eta fields to guests.
- `update-security-hardening.sql` pins `search_path` on every function and revokes
  `EXECUTE` on internal/trigger-only functions, closing their `/rest/v1/rpc/...`
  entry points.
- The `rec-media` bucket serves objects by URL but is not publicly listable.
- Staff accounts are created inside your own Supabase via the service-role
  function — no shared credentials.

---

## Roadmap

- Store pickup scheduling & branch pickup alerts
- Weather-based delivery advisories
- AI cohort recommendations (safe, privacy-preserving)
- Optional: ad skip / premium content upgrades
- Sales/referral reporting exports (CSV/PDF)

---

## License

Proprietary — all rights reserved. Content, design and assets belong to
REC Livestock & Agro Farms Enterprises unless otherwise noted.# rec-farm
