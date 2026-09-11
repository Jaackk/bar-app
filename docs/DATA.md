# BAR content and seed data

BAR ships with an offline demonstration dataset: 31 global classics, four sample venue cocktails, 17 sample wines, nine sample prep items and 27 sample stock items. The configured venue is **Rockwater Hove**, as requested. No current Rockwater menu, proprietary recipe, wine listing, par level or stock count has been verified.

**Sea Glass** takes its core amounts from the supplied visual mockup. Its ginger syrup and aquafaba foam are illustrative choices. **Peach & Bloom**, **Coral Tide** and **Garden Hour** are demonstration recipes; the first two names are inspired by the mockup. Every operational venue record has `isSample: true`; the UI can therefore label sample content without interpreting its name. Sample wines are generic style examples with the producer `Sample cellar selection`, not real bottle listings. The data must be approved and replaced before operational rollout.

## Files and first launch

The Swift package bundles these plain UTF-8 JSON arrays from `BARCore/Data/`:

| File | Records | Scope |
| --- | ---: | --- |
| `venues.json` | 1 | Venue identity and configurable branding |
| `classics.json` | 31 | Global reference recipes, with `venueID: null` |
| `cocktails.json` | 4 | Sample Rockwater venue recipes |
| `wines.json` | 17 | Sample venue wine styles and pairing metadata |
| `prep.json` | 9 | Sample tasks, recipes, yields and prep state |
| `stock.json` | 27 | Sample stock units, current counts and pars |

`SeedLoader` decodes these into an `AppSnapshot` on first launch. The local repository then stores user preferences and operational state in its own Application Support directory. Relaunching reads this persisted snapshot; it does not append duplicate seed records. Changing bundled JSON does **not** overwrite an existing installation's local snapshot. For a development preview of edited seed data, use the app's explicit local reset action or a fresh Simulator installation. Reset discards that installation's preferences, counts, prep state and progress; keep data you need before doing it.

The seed loader can skip an individually malformed record while preserving valid records. A malformed top-level JSON file or a failed snapshot validation is surfaced as an error. Treat a skipped record as a data defect: check the expected record totals and run the package tests after editing. Do not rely on forgiving parsing as an import validation strategy.

## Replace the samples with Rockwater's approved menu

1. Obtain the current approved cocktail specifications, ingredient brands, allergens, service methods and photography from the venue. Obtain the real wine list, supplier notes, pars and approved prep procedures separately.
2. Keep the venue ID `rockwater-hove` stable, or change it consistently across every venue-owned record and the active venue setting.
3. Replace the entries in `cocktails.json`, `wines.json`, `prep.json` and `stock.json`. Keep a stable unique ID for each logical record. Set `isSample` to `false` only once the record is reviewed and approved. A filename or drink name does not establish verification.
4. Assign exact recipe amounts and units. Specify real bottle sizes in millilitres. Review each ingredient's batch behaviour, linked prep component and any supplier-specific allergens.
5. Update `imageName` to match the bundled asset's exact name. Use the missing-image fallback until a licensed venue image is available.
6. Run `swift test` from the repository root and build/run the iOS scheme. Review the actual served spec, batch output and search results with a bartender.
7. Use a fresh install or reset for the initial bundle-based deployment. Ongoing shared menu updates require the future cloud/cache implementation described in [CLOUD.md](CLOUD.md); V1 does not pretend to sync data.

Keep `classics.json` as a global learning/reference library. Add venue versions to `cocktails.json` instead of changing the global standard just for one venue.

## JSON schema

All IDs are strings, intended to stay stable across edits. JSON uses camelCase. Date fields, when supplied, use ISO 8601 strings such as `2026-09-11T12:00:00Z`; omitted seed dates use the model's deterministic default. Required record identity is `id` and `name`. Most optional/default fields can be omitted, but fill operational fields deliberately. Unknown enum values make that record invalid.

The authoritative Codable definitions are in `BARCore/Models/`; the public API is described in [CONTRACT.md](../CONTRACT.md). The following is the editing guide.

### Venue

`id`, `name`, `location`, `venueCode`, `branding`, `createdAt`, `updatedAt`.

`branding` contains `displayName` and `subtitle`. Business logic uses the venue ID, never a hard-coded Rockwater name. The initial display is `ROCKWATER` with subtitle `Bar`.

### Cocktail

`id`, `name`, `venueID`, `subtitle`, `description`, `venueSpecific`, `category`, `baseSpirit`, `flavourTags`, `ingredients`, `method`, `glass`, `ice`, `garnish`, `prepInstructions`, `serviceNotes`, `allergens`, `imageName`, `isPopular`, `isActive`, `isSample`, `variations`, `overridesCocktailID`, `createdAt`, `updatedAt`.

`flavourTags`, `prepInstructions`, `allergens` and `variations` are arrays of strings. `ingredients` is an ordered array of Ingredient records. Measurement order is the service spec order. `baseSpirit` and `category` are human-readable strings; use consistent values for filters, such as `Gin`, `Rum`, `Vodka`, `Tequila`, `Whisky`, `Brandy`, `Sours`, `Highballs`, `Tiki`, `Martinis`, `Spritzes`, `Spirit Forward` and `After Dinner`.

`venueID: null` denotes a global classic. A venue record uses its venue's ID and `venueSpecific: true`. An explicit `overridesCocktailID` pointing to a global ID is the clearest way to replace that classic for one venue. The resolver also matches case-insensitive names as a convenience. Prefer explicit IDs for renamed house versions. An inactive venue record does not act as a hidden tombstone for the global classic; publish an active replacement to override it.

Minimal illustrative override (intentionally marked sample):

```json
{
  "id": "sample-house-negroni",
  "name": "Negroni",
  "venueID": "rockwater-hove",
  "venueSpecific": true,
  "overridesCocktailID": "classic-negroni",
  "category": "Spirit Forward",
  "baseSpirit": "Gin",
  "isSample": true,
  "ingredients": [
    { "id": "house-negroni-gin", "name": "Gin", "amount": 30, "unit": "ml", "bottleSize": 700 },
    { "id": "house-negroni-bitter", "name": "Campari", "amount": 30, "unit": "ml", "bottleSize": 700 },
    { "id": "house-negroni-vermouth", "name": "Sweet red vermouth", "amount": 30, "unit": "ml", "bottleSize": 750 }
  ]
}
```

This abbreviated example demonstrates the mapping; a service-ready record also needs method, ice, glass, garnish, allergen review and notes.

### Ingredient and batch rules

`id`, `name`, `amount`, `unit`, `batchable`, `batchBehaviour`, `bottleSize`, `notes`, `prepComponent`.

| Field | Convention |
| --- | --- |
| `amount` | Non-negative quantity of the named unit |
| `unit` | `ml`, `cl`, `litre`, `dash`, `barspoon`, `top`, `piece`, `sprig`, `gram` |
| `bottleSize` | Positive bottle capacity **in ml**, regardless of ingredient unit; omit if unknown |
| `prepComponent` | Optional stable prep item ID, e.g. `prep-pineapple-foam` |
| `batchable` | `false` excludes the ingredient from a batch calculation |
| `batchBehaviour` | One of the five values below |

| Behaviour | Use | Calculation |
| --- | --- | --- |
| `normal` | Spirits, liqueurs, measured non-carbonated liquids | Serves × amount × wastage factor |
| `serviceOnly` | Soda, sparkling wine, fresh espresso, delicate mint | Serves × amount; no wastage; separate service label |
| `prepareSeparately` | Foam base, dairy/coconut components or a separately handled ingredient | Serves × amount × wastage factor; kept out of the combined liquid total |
| `garnishCount` | Fruit pieces, sprigs, coffee beans | Whole count rounded up; no liquid conversion or wastage |
| `nonBatchable` | Ice or an ingredient which must not be scaled | Excluded from batch output |

Fresh citrus is a measured liquid in many classic records and carries handling notes. For an approved house recipe that holds citrus separately, use `prepareSeparately`. The sample Sea Glass notes explicitly instruct staff to keep citrus chilled and separate even when its quantity is calculated.

Use `top` with `amount: 0` for a genuinely unmeasured top or seasoning; its text is retained, and **no liquid volume or bottle requirement is invented**. To obtain a reliable purchase estimate, measure the venue's per-serve amount and use `ml` with appropriate behaviour. A `barspoon` or `dash` has no automatic litre conversion because bar tools and contents vary. Dry sugar measured by spoon is never silently treated as a liquid. Bottle requirements use ceiling of measured volume divided by bottle capacity and are estimates before checking opened inventory.

### Wine

`id`, `name`, `venueID`, `producer`, `region`, `country`, `grape`, `colour`, `style`, `body`, `sweetness`, `acidity`, `tannin`, `flavourNotes`, `description`, `foodPairings`, `similarTo`, `servingNotes`, `guestDescription`, `imageName`, `venueSpecific`, `isActive`, `isSample`.

`colour` is `red`, `white`, `rose`, `sparkling` or `dessert`. `body`, `sweetness`, `acidity` and `tannin` are ordinal integers from 1 to 5. For body, 1 is light and 5 full. For sweetness, 1 is dry and 5 sweet. These are search/recommendation attributes, not laboratory analysis or an assertion of a formal WSET score. `flavourNotes`, `foodPairings` and `similarTo` are string arrays. Include concrete pairings and familiar comparison grapes so a query such as `sea bass`, `steak` or `similar to Malbec` has meaningful data to rank.

Taste, pairing and guest descriptions must be reviewed for the **actual wine and vintage**, including the dish's sauce, seasoning and guest preference. The generic sample profiles are illustrative. A sample producer is never an assertion that Rockwater stocks that wine. Wine allergens and dietary suitability must come from the actual supplier information; the absence of a model field does not mean allergen-free.

### Prep

`id`, `name`, `venueID`, `category`, `currentAmount`, `targetAmount`, `recipeYieldAmount`, `unit`, `recipe`, `method`, `storageInstructions`, `shelfLife`, `lastPreparedDate`, `completed`, `notes`, `isSample`.

`recipe` is an Ingredient array; `method` is an ordered array of strings. `recipeYieldAmount` is the nominal finished yield of the displayed recipe in the **same unit as the prep item**. The scaler uses `desired yield / recipeYieldAmount`, so 2.2 L required from a nominal 1 L recipe scales ingredient quantities by 2.2. Mixing sugar into water does not simply add liquid volumes; sample syrups instruct staff to measure actual finished yield. Set an approved measured yield before relying on the scale.

`requiredAmount = max(targetAmount - currentAmount, 0)` is computed, not stored. Completing a task raises current amount to at least target and records a preparation date. Sample shelf-life entries are planning examples, **not validated food-safety limits**; the venue must approve recipes, refrigeration, date labelling, allergens and holding periods. The dehydrated-fruit example intentionally claims no fixed shelf life.

### Stock

`id`, `name`, `venueID`, `category`, `bottleSize`, `currentStock`, `parLevel`, `unit`, `notes`, `isSample`.

`bottleSize` is ml; `currentStock` and `parLevel` use the declared stock unit, usually bottles. Thus a 1 L syrup bottle at `0.8` means 800 ml, while a 70 cl spirit bottle at `0.5` means 350 ml. `requiredStock = max(parLevel - currentStock, 0)` is computed. Suggested bottle orders round positive shortfalls up to whole units. Supplier case packs, minimum orders and EPOS reconciliation are future concerns; V1 does not invent those integrations. Prep and stock are separate workflows; reconcile their overlapping sample syrup counts before operating a live ordering process.

## Image conventions

`imageName` refers to a local asset name without a filename extension. Use short lowercase kebab-case names. Sample hero names are `sea-glass`, `peach-bloom`, `coral-tide` and `garden-hour`; classic records can share category artwork such as `classic-sours`, `classic-martinis` and `classic-highballs`. Wine names are `wine-white`, `wine-red`, `wine-rose`, `wine-sparkling` and `wine-dessert`.

Add a licensed photograph as an image set in the iOS app's asset catalogue and set the exact same name in JSON. Include the image in the app target. Portrait drink photographs around 1200–1600 pixels on their long edge provide useful detail without shipping full camera originals. Keep the main glass near the centre so the UI's aspect-fill crop remains useful. Avoid text baked into photographs. Missing assets are rendered with the app's local fallback artwork; the app must not need a remote URL to show a drink.

The bundled demonstration visuals are not verified photographs of Rockwater drinks. Replace them with approved venue photography before public release. Maintain provenance/licence information for supplied images outside secret-bearing configuration.

## Recipe provenance and chosen conventions

The classics are useful reference specs, not claims of one universally definitive recipe. Ingredient amounts were checked against primary references on **11 September 2026**. Methods, service guidance and descriptions are written for this app. No source photographs or long prose were copied. A venue's approved specification takes precedence in service.

The IBA's [official cocktail library](https://iba-world.com/cocktails/) is the primary reference for these records:

| Classic | Source | Seed convention or variation |
| --- | --- | --- |
| Old Fashioned | [IBA](https://iba-world.com/iba-cocktail/old-fashioned/) | The source's “few dashes” is fixed at three bitters/water dashes for a scannable reference. |
| Negroni | [IBA](https://iba-world.com/iba-cocktail/negroni/) | Equal 30 ml measures. |
| Margarita | [IBA](https://iba-world.com/iba-cocktail/margarita/) | 50/20/15 ml, optional half salt rim. |
| Tommy's Margarita | [IBA](https://iba-world.com/iba-cocktail/tommys-margarita/) | 60/30/30 ml; agave product concentration must be reviewed. |
| Daiquiri | [IBA](https://iba-world.com/iba-cocktail/daiquiri/) | 60 ml rum, 20 ml lime, two barspoons dry superfine sugar. |
| Mojito | [IBA](https://iba-world.com/iba-cocktail/mojito/) | Mint adapted to six tender leaves plus garnish; dry sugar recorded in level barspoons. |
| Cosmopolitan | [IBA](https://iba-world.com/iba-cocktail/cosmopolitan/) | Citron vodka and lemon twist reference. |
| Espresso Martini | [IBA](https://iba-world.com/iba-cocktail/espresso-martini/) | One espresso represented as 30 ml; actual coffee recipe must be calibrated. |
| Pornstar Martini | [IBA](https://iba-world.com/iba-cocktail/porn-star-martini/) | Purée, vanilla sugar and Champagne alongside; naming follows the requested library. |
| Whiskey Sour | [IBA](https://iba-world.com/iba-cocktail/whiskey-sour/) | Optional egg white represented as 15 ml; this is more than the source's few drops. |
| Mai Tai | [IBA](https://iba-world.com/iba-cocktail/mai-tai/) | Two-rum reference; Martinique molasses rum is distinct from agricole. |
| Dry Martini | [IBA](https://iba-world.com/iba-cocktail/dry-martini/) | 60 ml gin and 10 ml dry vermouth. |
| French Martini | [IBA](https://iba-world.com/iba-cocktail/french-martini/) | Source's 15 ml pineapple retained; higher-juice versions vary. |
| Manhattan | [IBA](https://iba-world.com/iba-cocktail/manhattan/) | Rye reference. |
| Boulevardier | [IBA](https://iba-world.com/iba-cocktail/boulevardier/) | 45/30/30 ml, served up; rocks is a common variation. |
| Paloma | [IBA](https://iba-world.com/iba-cocktail/paloma/) | Grapefruit soda version, with unmeasured pinch of salt. |
| Sidecar | [IBA](https://iba-world.com/iba-cocktail/sidecar/) | 50/20/20 ml; optional sugar rim is identified as a variation. |
| Aviation | [IBA](https://iba-world.com/iba-cocktail/aviation/) | Violette included as one barspoon. |
| Bramble | [IBA](https://iba-world.com/iba-cocktail/bramble/) | Blackberry liqueur is a service drizzle. |
| Tom Collins | [IBA John Collins](https://iba-world.com/iba-cocktail/john-collins/) | Source explicitly names Old Tom gin for Tom Collins. |
| French 75 | [IBA](https://iba-world.com/iba-cocktail/french-75/) | Champagne held for service. |
| Caipirinha | [IBA](https://iba-world.com/iba-cocktail/caipirinha/) | Dry sugar teaspoons represented as calibrated level barspoons. |
| Piña Colada | [IBA](https://iba-world.com/iba-cocktail/pina-colada/) | Liquid ratio retained; illustrative ice weight is excluded from batches. |
| Dark 'n' Stormy | [IBA](https://iba-world.com/iba-cocktail/dark-n-stormy/) | Goslings rum reference. |
| Moscow Mule | [IBA](https://iba-world.com/iba-cocktail/moscow-mule/) | Generic vodka at the source's 45 ml amount. |
| Bloody Mary | [IBA](https://iba-world.com/iba-cocktail/bloody-mary/) | Hot sauce starts at two dashes; seasoning remains to taste. |
| Long Island Iced Tea | [IBA](https://iba-world.com/iba-cocktail/long-island-iced-tea/) | Cola remains an unmeasured service top. |
| Aperol Spritz | [IBA Spritz](https://iba-world.com/iba-cocktail/spritz/) | Soda splash made explicit as 30 ml for the common 3:2:1 formulation. |

Three further primary references explain the chosen modern variants:

- **Amaretto Sour** follows [Jeffrey Morgenthaler's published recipe](https://jeffreymorgenthaler.com/i-make-the-best-amaretto-sour-in-the-world/?print=true), with bourbon and rich syrup. It is identified as that modern variation rather than presented as the sole standard.
- **Martini** uses the 2:1 ratio of [Plymouth's Douglas Martini](https://www.plymouthgin.com/en/cocktail/douglas-martini/), offering a distinct, wetter comparison to Dry Martini.
- **Dirty Martini** scales [Grey Goose's UK 75/15/15 ml reference](https://www.greygoose.com/en-gb/cocktails/grey-goose-vodka/dirty-martini-cocktail.html) to 60/12/12 ml. The seed uses strained brine without the source's muddled-olive step.

Allergen arrays are prompts for supplier review, not a comprehensive allergen register. Formulations differ by brand, including vermouth sulphites, nut-derived liqueurs, bitters and Worcestershire sauce. Optional egg is explicitly present in the Whiskey Sour record, so an allergy search does not silently treat it as egg-free. Cross-contact procedures remain a venue responsibility.

Sample wine pairings use general principles described by [WSET on salt, acidity, fat and preference](https://www.wsetglobal.com/knowledge-centre/blog/2023/july/13/four-rules-to-masterful-food-and-wine-pairing/), [WSET on tomato-based dishes](https://www.wsetglobal.com/knowledge-centre/blog/2020/june/02/how-to-pair-wine-with-your-favourite-takeaway-meals), and [WSET on sweet dishes](https://www.wsetglobal.com/knowledge-centre/blog/2020/december/21/winter-wine-and-food-matching/). The Sauvignon Blanc example is informed by [New Zealand Wine's style and pairing guide](https://www.nzwine.com/en/winestyles/sauvignonblanc/). Numerical scores and individual sample descriptions are illustrative app data, not source tasting notes or claims about specific bottles.

## Local manager import

Debug builds expose a clearly labelled development role preview. Select Manager in Profile, then use **Import venue JSON**. Release builds do not expose the role switch or grant manager access from a saved debug preference.

The file is one content object, not one of the individual array files:

```json
{
  "schemaVersion": 1,
  "venues": [{"id": "rockwater-hove", "name": "Rockwater Hove"}],
  "cocktails": [],
  "wines": [],
  "prep": [],
  "stock": []
}
```

Empty arrays intentionally replace those collections with no records. Include all wanted records, including global classics in `cocktails`. The active venue must remain present. A convenient packager combines the six seed files:

```sh
python3 scripts/make-content-import.py build/venue-content.json
```

Transfer the file to Files on the iPhone or Simulator and choose it in the importer. `ContentImportService` preserves employee identity, role, preferences, favourites, recents, training and saved batches from the current device; any such fields in the input cannot replace personal state. Every content record must pass strict snapshot validation. Nothing is saved if validation fails. Import replaces operational prep/stock state too, so use an intentional complete dataset. This is a local development tool, not server publishing.
