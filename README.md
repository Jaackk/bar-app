# BAR

A native, offline iPhone companion for bartenders, initially configured for **Rockwater Hove**. Built with Swift, SwiftUI and Apple frameworks for **iOS 17 or later**. Open **`BAR.xcodeproj`**, select scheme **BAR**, and run on an iPhone Simulator.

The cream, stone, olive, sage and coral design follows the supplied Rockwater mockup. It includes locally bundled concept cocktail photography, serif drink titles, readable measurements and five tabs: Home, Search, Prep, Stock and Profile.

## Screenshots

Actual iPhone Simulator captures are included in [docs/screenshots](docs/screenshots). See [Home](docs/screenshots/iphone-15-pro/home.png), [cocktail detail](docs/screenshots/iphone-15-pro/cocktail-detail.png), [batch calculator](docs/screenshots/iphone-15-pro/batch.png) and [Wine Finder](docs/screenshots/iphone-15-pro/wine-finder.png).

## What works

- Venue cocktail browsing and a 31-drink classics library, with spirit/style filters and venue overrides.
- Ranked universal search across names, ingredients, flavours, methods, glassware, wines and prep; exclusions such as `no egg`.
- Cocktail specifications, allergens, service instructions, favourites and bounded recent history.
- Batch calculations with custom serves, quick quantities, adjustable wastage, litres and whole-bottle requirements. Service additions, separate preparations, garnish counts and non-batchable items retain their meaning.
- Saved batches and creation of preparation tasks from calculations.
- Wine Finder with taste/colour controls, grape/style matching, ranked food pairings, guest descriptions and wine favourites.
- Prep recipes with yield-aware scaling, current/target amounts, progress, completion and storage notes.
- Separate persistent Restock and Stock Order lists, compact rows, swipe removal, a searchable product picker, native copy/share and editable product photos. The shared catalogue feeds universal Search and manager Stocktake.
- Flashcards, recipe and ingredient quizzes generated from the actual database, with persistent local progress.
- Employee name, ml/cl recipe preference, default wastage, local reset and development-only role preview.
- Validated local content import in development manager mode; manager par editing through the repository-backed app model.

There is no production account system, cloud sync, EPOS integration or published App Store build. The content editing foundation is a validated JSON importer; a full form-based manager recipe editor is a future feature.

## Run in Xcode

1. Open `BAR.xcodeproj` (the project already exists; no project generator is needed).
2. Select the **BAR** scheme in the toolbar.
3. Select an available iPhone Simulator. Xcode Settings → Components lets you install an iOS Simulator runtime if needed.
4. Choose Product → Run, or press **⌘R**.
5. The first launch loads the bundled JSON. Subsequent launches restore the saved device state.

The repository contains a local Swift package, **BARCore**, referenced by the Xcode project. It has no third-party dependencies and does not need network access to resolve external packages.

To run on a physical iPhone, connect and trust the iPhone, enable Developer Mode when requested, add your Apple account in Xcode Settings → Apple Accounts, and select your own team under the BAR target’s Signing & Capabilities. Choose the iPhone and press ⌘R. Change `com.barapp.mobile` to a bundle identifier available to your team. Personal-team development can be used for local device testing subject to Apple’s provisioning limits; TestFlight/App Store distribution requires Apple Developer Program membership. No personal team or signing material is included here. See [Apple’s device instructions](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices).

## Build and test

From the repository root:

```sh
swift test
xcodebuild -project BAR.xcodeproj -scheme BAR \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project BAR.xcodeproj -scheme BAR \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
```

Use an installed simulator name shown by `xcrun simctl list devices available`. `swift test` executes the domain/repository tests on macOS. Product → Test (**⌘U**) on scheme BAR executes the iPhone UI tests. UI tests use a separate temporary repository and do not reset normal app data. Their `--uitesting` launch argument is recognised only in Debug builds.

The domain suite verifies batch amounts/wastage/bottles and ingredient behaviours, stock ordering, ranked search, wine recommendations, venue overrides, quiz generation, JSON parsing, first-launch seeding, durable state, role behaviour and preservation of corrupted data. See [VALIDATION.md](docs/VALIDATION.md) for the actual recorded results and device coverage.

## Architecture

```text
SwiftUI views
    ↓
AppStore (@Observable, @MainActor)
    ↓
AppRepository / domain repository protocols
    ↓
LocalAppRepository → validated atomic Codable JSON snapshot
    ↑
Bundled seed JSON on first launch
```

Views do not query SwiftData or know disk paths. The local adapter uses Apple Foundation JSON encoding and atomic file replacement instead of SwiftData because the small offline catalog is naturally represented as portable Codable records. This also makes content imports and repository tests straightforward.

`AppStore` is the injected application view model and navigation/session coordinator. Pure services accept value models and can be reused in future feature view models. Domain protocols (`CocktailRepository`, `WineRepository`, `PrepRepository`, `StockRepository`, `VenueRepository`, `UserRepository`) and `LocalContentRepository` provide narrower access boundaries as the platform grows. A cache-backed cloud `AppRepository` can be injected without changing screens; network sync should run asynchronously outside its synchronous cache methods.

```text
BAR/
  App/                  SwiftUI lifecycle, AppStore and dependency composition
  Components/           Shared colours, typography, cards, buttons and artwork
  Views/                Home, search, cocktail, batch and wine flows
    Operations/         Prep, stock, Learn and Profile
  Assets.xcassets/      Bundled cocktail images and 1024px concept app icon
  PrivacyInfo.xcprivacy Privacy manifest
BARCore/
  Models/               Codable venue, user, drinks, prep, stock and local state
  Services/             Batch, search, wine ranking, ordering, quiz and overrides
  Repositories/         Domain interfaces and local content implementation
  Persistence/          Seed decoding, validation and atomic snapshot repository
  Data/                 Editable JSON arrays
Tests/BARCoreTests/     Domain and persistence XCTest suite
BARUITests/            Native interaction and screenshot tests
BAR.xcodeproj/         Shared BAR scheme and local package reference
Package.swift          BARCore library and macOS-testable test target
```

## Data and branding

The venue catalogue comes from [Rockwater Hove’s official drinks menu](https://www.rockwater.uk/wp-content/uploads/2026/05/Drinks-menu-May-1.pdf). The 16 Coastal recipes now use the supplied **cocktail_specs (2).pdf**, and 44 house classic recipes use the [supplied spreadsheet](https://docs.google.com/spreadsheets/d/12saJcah98vFdTI2IE4YzacAs2XMpdOUadzdmtMPOvfQ/edit), imported 15 September 2026. Two additional wet Martini variants make batch quantities explicit. House specifications override matching generic classics. Unspecified garnish/ice/fruit choices remain unspecified; optional additions are not silently added to a batch.

- `BARCore/Data/hove-cocktails.json`: the 16 PDF specifications, retaining menu names and recording PDF aliases.
- `BARCore/Data/house-classics.json`: all spreadsheet recipes with source sheet/cell references and original quantity notes.
- `BARCore/Data/hove-wines.json`: all 59 menu wines. Numerical taste profiles and food pairings are editorial style guidance, not published venue tasting scores.
- `BARCore/Data/hove-products.json`: the menu catalogue and recipe ingredients; edit preferred units through Products & photos.
- `BARCore/Data/prep.json` and `stock.json`: original sample prep, counts and pars retained for continuity; these are not verified operational stock.

`MenuMigration` revision 2 updates supplied recipes on existing installs without resetting lists, photos, custom products, counts or personal settings. Deleted menu products stay deleted. Imported house overrides preserve saved favourite and batch references. Product photos are resized to at most 800 pixels and stored locally in the product record. No photo upload or search API is used.

Stock → Products & photos is available to staff for catalogue maintenance. A new product appears in both list pickers, universal Search and Stocktake; editing updates linked list labels. Deleting a product preserves existing list entries. Custom list items remain temporary list-only entries. Counts and pars remain under Profile → Manager tools → Stocktake (development role preview).

See [HOUSE-UPDATE.md](docs/HOUSE-UPDATE.md) for source exceptions and validation. Source exceptions are displayed in the affected recipe, not silently corrected.

## Images and icon

The three named sample photographs are **AI-generated concept images**, bundled locally under `BAR/Assets.xcassets/sea-glass.imageset`, `peach-bloom.imageset` and `coral-tide.imageset`. They do not verify how any venue actually serves a drink. Other drinks use a restrained native artwork fallback; wine bottles use native symbolic artwork.

To replace an image, add an Image Set in the asset catalog, place the licensed photo inside, and set the recipe’s `imageName` to that set’s exact name. Existing names can be retained when replacing files. The app always provides fallback artwork if an asset is missing. Portrait images around 1024×1536 are sufficient for the hero and card layouts. No remote image URL is required.

`AppIcon.appiconset` contains a 1024px opaque cream-and-olive martini concept icon. Review final branding and artwork before distribution. [ASSETS.md](docs/ASSETS.md) records the generated asset prompts and provenance.

## Cloud, roles and manager editing

Read [CLOUD.md](docs/CLOUD.md) for the proposed Supabase adapter, cache/sync flow, tables, schema mapping, role enforcement, conflict handling and rollout steps. Proposed tables include venues, profiles, venue_memberships, cocktails, cocktail_ingredients, wines, prep_items, stock_items/counts and training_progress.

The Debug role preview exists only under `#if DEBUG`. Release builds use the bartender role until real authentication is added. A stored Debug role cannot enable manager UI in Release. There is no production password. Future Supabase permissions must be enforced using authenticated venue membership and database row-level security; hidden UI controls alone are never permission enforcement.

A future manager editor should validate a complete draft `Cocktail`, then call the repository save API. Publishing should be a server transaction that increments the content revision, followed by staff cache updates. Do not write directly into SwiftUI view state or require an app release for a menu update.

## Release and TestFlight

1. Review verified menu/allergen data, real photography, branding, accessibility and device behaviour.
2. Choose your bundle identifier, Apple signing team, version and build number in the BAR target. Configure an App Store Connect app for that identifier.
3. Choose an iPhone device/archive destination, then Product → Archive using Release.
4. In Organizer, validate the archive and Distribute App → App Store Connect. Upload using your own account.
5. Wait for processing, provide the required compliance/release information, then configure TestFlight groups and invite employees. External testing may require beta review.
6. For a public release, add App Store metadata/screenshots, privacy information, support/privacy URLs and submit for App Review.

The project includes no personal signing credentials and no archived distribution build. Physical device performance, signing, provisioning, TestFlight processing and App Store review must be verified with your own account. [Apple’s distribution documentation](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases) describes the current workflow.

## Security and repository hygiene

Local preferences and operational data remain on the device; the app does not send analytics or data to a server. The saved snapshot uses iOS file protection until first unlock. Corrupt saved data is preserved and reported, rather than silently reseeded or overwritten. An explicit reset is available for recovery.

Future user access tokens belong in Keychain. Keep configuration examples free of real credentials. Never include privileged Supabase service-role keys in an iOS app. Do not commit signing certificates, provisioning profiles, personal team IDs, tokens, secrets, DerivedData, build products or user-specific Xcode state. The `.gitignore` covers these development artifacts.

The remote repository was reported as public during setup, despite the brief describing it as private. This implementation is committed locally only; repository visibility is unchanged.
