# Shared venue data and future Supabase integration

BAR V1 is an offline native application. It has **no backend connection, no production authentication, no network sync and no pretend cloud service**. Local repositories, Codable models and venue/role boundaries provide the insertion points for a real service later. Bundled JSON is the starting dataset; a saved local snapshot is the current source of data on a device.

## Existing boundaries

The shared `BARCore` package keeps the models and services independent of SwiftUI:

- `AppRepository` owns snapshot loading, validated saving and explicit reset. `LocalAppRepository` implements it with atomic JSON storage under Application Support/BAR.
- `CocktailRepository`, `WineRepository`, `PrepRepository`, `StockRepository`, `VenueRepository` and `UserRepository` define content access. `LocalContentRepository` implements those interfaces over an injected `AppRepository`.
- `VenueResolver` combines active global classics with active content for the selected venue and applies venue overrides.
- Batch, search, wine recommendations, stock calculations and quizzes work on value models. They do not need network access.
- `UserRole` defines `bartender`, `manager` and `admin`. Local role checks support a development prototype; they are **not authentication or a security boundary**.

The SwiftUI application depends on the repository through its observable application/view-model layer. Views have no SwiftData or database queries. The domain repository protocols are available for smaller feature-specific view models as the application grows; the current app can continue to use the aggregate snapshot boundary.

## How a cloud adapter fits

A future cache-backed `SupabaseAppRepository` can implement the same `AppRepository` methods. Those synchronous methods should read and write the local cache promptly. A separate actor, for example `VenueSyncCoordinator`, should use `async/await` for authentication, fetches, uploads and subscriptions. Do not place synchronous network requests inside `load()` or block the main thread waiting for a connection.

Recommended flow:

```text
Manager publishes an approved venue revision
                    ↓
Supabase validates the session and database permissions
                    ↓
Cocktail + ingredient changes commit together
                    ↓
Staff sync coordinator fetches the new revision
                    ↓
Decode, validate and atomically merge into the local cache
                    ↓
Observable application state refreshes from the repository
```

Cocktail/menu/wine/prep content then changes without an App Store release. App releases remain necessary for new app functionality, incompatible schemas and bundled fallback updates. Images downloaded by the future adapter should be cached before advertising them as available; the existing local art remains the fallback.

An alternative is `SupabaseCocktailRepository` and companion implementations of the narrow domain protocols. Each should still serve a local cache. The native models do not need to mirror every PostgreSQL join: remote DTOs map database records and ordered ingredients into the current Codable types.

**This is a design proposal, not implemented sync behaviour.** The remaining work includes the Supabase project, authentication, migrations, RLS tests, remote DTO mapping, local outbox, revision handling, subscriptions, conflict UI and account/venue lifecycle.

## Proposed database concepts

Use stable identifiers, server timestamps, foreign keys, validation constraints and indexes. V1 IDs are readable strings. A future database can retain text IDs during import, or issue UUIDs with an explicit migration map; never silently generate new IDs for every sync, because favourites, overrides and prep references rely on stability.

| Table | Main fields and relationships | Native mapping |
| --- | --- | --- |
| `venues` | `id`, `name`, `location`, `venue_code`, branding fields, timestamps | `Venue`, `VenueBranding` |
| `profiles` | Auth user ID, display name, timestamps; no client-writable privilege field | `User` identity/display fields |
| `venue_memberships` | `venue_id`, `user_id`, role, status, joined/revoked timestamps; unique user/venue pair | Active `User.venueID` and permitted role |
| `cocktails` | `id`, nullable `venue_id` for global classics, spec metadata, active/sample flags, override ID, revision, timestamps | `Cocktail` excluding its joined ingredients |
| `cocktail_ingredients` | `id`, `cocktail_id`, position, amount, unit, behaviour, bottle size, notes, prep reference | Ordered `[Ingredient]` |
| `wines` | `id`, `venue_id`, producer/style/structure fields, tags, pairings, active/sample flags, revision | `Wine` |
| `prep_items` | Venue recipe definitions, nominal yield/unit, storage, shelf life, approved methods | Recipe portion of `PrepItem` |
| `prep_status` | Prep item, service date/shift, current amount, target, completed state, preparer, timestamp | Operational portion of `PrepItem` |
| `stock_items` | Venue product catalog, category, capacity, unit, par, supplier/pack metadata later | Static portion of `StockItem` |
| `stock_counts` | Product, venue, stocktake/shift, count, counter, timestamp, idempotency key | Current `StockItem.currentStock` plus audit history |
| `training_progress` | User/venue, per-cocktail progress or answer events, version | `TrainingProgress` |
| `user_preferences` | User, selected venue, wastage, units; favourite references may be separate tables | `UserPreferences` |
| `menu_revisions` | Venue, published revision number, author, publish time, change summary | Sync cursor and publication metadata |
| `content_audit_log` | Actor, venue, entity, operation, old/new revision, timestamp | Manager history; no UI model required in V1 |

Arrays such as tags and food pairings can initially use PostgreSQL arrays or JSONB. Normalize only where referential integrity or reporting justifies it. Keep ingredient order explicit. Keep the global classic catalog distinct from venue recipes: only authorized platform administrators should edit globals, and a venue manager should publish an override instead.

Cocktails, ingredients, linked prep and menu visibility need a transaction or server-side publication operation. Publishing a half-written cocktail would expose an incomplete service spec. A revision should contain only reviewed, valid content, including allergen and sample-status review. Store old revisions or audit entries for recovery.

## Offline reads and changes

1. Launch from the most recent validated local cache immediately, including all active essential venue recipes and wines.
2. After a valid sign-in and venue selection, fetch a complete authorized snapshot for the initial sync. Save the server cursor only after the cache transaction commits.
3. For later updates, fetch revisions changed after that cursor. Use a monotonic revision or a robust cursor, not device clocks alone. Apply deletions as tombstones, with a bounded retention strategy, so an offline device can catch up safely.
4. Treat Realtime as an invalidation signal to fetch authoritative data. Reconnect, foreground and periodic catch-up fetches must repair missed events. Supabase documents both [Postgres Changes](https://supabase.com/docs/guides/realtime/postgres-changes) and [database Broadcast subscriptions](https://supabase.com/docs/guides/realtime/subscribing-to-database-changes); choose and test the mechanism for the actual workload.
5. Persist permitted offline stock counts and prep completion events in an outbox with unique operation IDs before reporting them saved. Retry with bounded backoff, distinguish authentication failures from connectivity failures, and make retries idempotent.
6. Merge remote content without erasing unrelated favourites, training progress, current counts or unsent changes. Whole-snapshot last-writer-wins would lose data. Introduce a repository actor or transactional store before concurrent sync writes are added.
7. Show meaningful freshness, pending-change and conflict state. Do not display “synced” unless the server acknowledged the operation. Preserve useful cached content while offline.

## Conflict rules to define before rollout

- **Published menu content:** server-approved revision is authoritative. A manager edits a draft based on a known revision. If it changed meanwhile, reject or request an explicit merge; never silently overwrite a newer allergen/spec change.
- **Stock counts:** counts are observations at a time and place, not increments that can safely be added. Store events per stocktake; reconcile two observations in the same session and retain who counted them.
- **Prep completion:** keep shift/service date, operator and quantity. A new day's task must not inherit yesterday's completion simply because the recipe ID is unchanged.
- **Favourites/preferences:** merge per user; favourite add/remove events or timestamps prevent stale devices from resurrecting removed favourites.
- **Training:** deduplicate answer events or synchronize per-question progress, rather than adding arbitrary aggregate totals from two devices.
- **Venue overrides:** preserve the explicit global reference ID, choose the active local version for that venue and do not leak another venue's private recipe.

V1 stores current operational state locally and does not attempt these multi-device conflict behaviours.

## Authentication and permissions

Use Supabase Auth for the user session and a database-managed membership relationship for venue access. Store refresh/session material in the iOS Keychain using an appropriate accessibility level. Do not use the editable employee display name, a local role field, a UI toggle or a hard-coded password as proof of identity or privilege.

The proposed authorization matrix is:

| Actor | Operational content | Counts/prep actions | Menu and par editing | Venue administration |
| --- | --- | --- | --- | --- |
| Bartender | Read published content for active memberships | Create permitted events for their venue | No | No |
| Manager | Same venue reads | Same venue events and review | Own venue drafts/publications and pars | Only explicit delegated membership permissions |
| Admin | Only venues within granted administrative scope | Explicit scope | Explicit scope, including global catalog if granted | Explicitly granted administration |

Enforce permissions in PostgreSQL with Row Level Security and appropriate table grants. Test read, insert, update and delete separately, including changed `venue_id` values and unauthenticated users. A membership role should be set through trusted administration, never writable by its subject. Supabase's [RLS guide](https://supabase.com/docs/guides/database/postgres/row-level-security) explains database policy enforcement and identity helpers; UI visibility is only a usability feature.

Children inherit authorization through their parent: ingredient access must verify the parent cocktail's venue and publication status. Apply the same tenant boundary to views, RPCs, Realtime messages and object storage. Do not expose draft recipes or cross-venue data through an unprotected join or bucket. Use server-verified membership for both the old row (`USING`) and proposed new row (`WITH CHECK`) when designing write policies.

A production backend test suite should prove at least:

- anonymous callers cannot read private venue content;
- a bartender in venue A cannot read, change or subscribe to private data in venue B;
- a bartender cannot change pars, publish recipes, self-promote or edit membership;
- a manager can edit only authorized venue content, not the global catalog;
- ingredient and image policies have the same scope as their parent recipe;
- revoked memberships and expired sessions cannot upload queued writes;
- two-device retries cannot double-count a completed operation.

These are required future security behaviours, not claims of tests performed against a nonexistent backend.

## Photos and storage

Store originals in a controlled upload area and publish optimized derivatives with content metadata, rights information and revision/hash. A proposed path is `venue-id/cocktail-id/revision/hero.jpg`. A path name is not an authorization rule: verify membership and allowed operation in storage policies. Supabase Storage supports policy-controlled access, and privileged service credentials can bypass those controls. See [Storage access control](https://supabase.com/docs/guides/storage/security/access-control).

Choose private buckets plus authorized requests/signed URLs for employee-only photography. Once downloaded, map remote asset metadata to a local cached filename; retain the bundled fallback when offline or after a failed download. Clean up superseded cached images with a size budget while keeping the active menu available. Session expiry must not crash image presentation.

## Secrets and configuration

The future iOS build may contain the project URL and the **publishable** client key appropriate to the deployed Supabase configuration. Treat those as identifiers protected by server policies, not as privileged secrets. Never place service-role/secret database keys, database passwords, Apple signing material or private server credentials in the iOS bundle, JSON seeds or Git repository. Privileged credentials belong only in trusted server/deployment secret storage.

Use an ignored local configuration file and a committed example containing names and empty values when integration is implemented. Authentication tokens belong in Keychain, not `UserDefaults`, screenshots, logs or the snapshot JSON. Redact logs before sharing. Remove or compile out development role controls in production builds when real authentication is connected.

## A practical implementation order

1. Create the Supabase project, migrations, database constraints and representative venue data in a non-production environment.
2. Implement authentication, controlled membership administration and RLS tests before connecting employee data.
3. Build a read-only remote-to-local mapper and cache coordinator; prove offline launch and recovery after missed updates.
4. Add transactional manager drafts/publishing and versioned image updates.
5. Add the idempotent outbox for stock/prep with conflict and permission-revocation handling.
6. Migrate local user state deliberately, validate device data and test two devices across connectivity changes.
7. Deploy with observability, backup/recovery procedures and a controlled employee rollout.

No PowerEPOS API, supplier order submission or authentication shortcut is assumed by this design.
