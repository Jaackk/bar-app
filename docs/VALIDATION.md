# Validation record

Recorded on **11 September 2026**, using **Xcode 26.2 (17C48)** on macOS 15.7.2, Intel. The project targets iOS 17+. Tests used the installed iOS 26.2 Simulator runtime.

## Verified builds and tests

| Check | Result |
| --- | --- |
| BARCore XCTest suite (`swift test`) | 47 passed, 0 failed |
| Debug iPhone Simulator build | Passed, including a fresh DerivedData build |
| Release generic iPhone / arm64 build, signing disabled | Passed after the final stock editor change |
| iPhone 15 Pro — five UI flows | 5 passed, 0 failed |
| iPhone 15 Pro — additional stock editor regression run | 1 passed, 0 failed |
| iPhone 15 Pro — settled Learn screenshot / interaction recheck | 1 passed, 0 failed |
| iPhone SE (3rd generation) — initial five-flow suite | 4 passed, 1 failed (search result tapped behind keyboard) |
| iPhone SE (3rd generation) — search / wine / classics recheck | 1 passed, 0 failed after explicit search submission |

**Final coverage:** all 47 core tests and all five UI flows have passed. Each UI flow was verified on both iPhone 15 Pro (393×852 points) and iPhone SE (3rd generation, 375×667 points), using the targeted rechecks above where necessary. There are no outstanding failures in those app flows. Earlier failures and the invalid mini simulator run are recorded below.

The unsigned Release build verifies compilation and linking for physical iPhone architecture. It is not a signed archive, an installation on a physical device, or App Store validation.

## What the UI tests exercise

1. Home → venue cocktail library → Sea Glass → favourite → batch. Verify 25 serves with 3% wastage gives 1,030ml rum, switch to 50 serves, save the batch, create prep, and confirm the favourite survives termination/relaunch.
2. Universal search for Negroni, classics navigation, Wine Finder taste selection, seafood pairing search, grape/region search, wine detail and wine favourite.
3. Prep list and recipe, completion feedback, stock navigation, suggested order generation/copy and Profile.
4. Learn, flashcard reveal and self-assessment, recipe quiz answer, next question visible from the top.
5. Fractional stock counting, search keyboard dismissal, employee name editing and persistence after relaunch. The extended regression saves 1000.5, reopens the numeric editor and saves without changing the amount.

Tests reset a dedicated temporary **BAR-UITests** repository only in Debug builds. The relaunch tests preserve that test state explicitly. Normal app storage is separate.

Core tests independently cover custom/zero batch sizes, different wastage rates, ml/litre conversion, whole-bottle ceilings, service additions, non-batchable ingredients, separate preparations, garnish rounding, stock shortfalls, search ranking, wine recommendations, venue overrides, quiz generation, seed parsing, corrupted data preservation, atomic repository persistence and validated imports that preserve personal state.

## Fixes found during validation

- Rebuilt the Xcode project after a newly added Profile source file was initially absent from the target; subsequent builds pass.
- Reduced Home spacing, adjusted the drink hero and simplified the initial Wine Finder taste area after screenshot review.
- Reset flashcard/quiz scroll position when moving to the next item.
- Added explicit search submission/keyboard dismissal and a keyboard Done control. An earlier stock-to-profile UI test failed with the search keyboard open. A fresh build and simulator app installation verified the updated code; the complete iPhone 15 Pro run and extended persistence regression now pass.
- Removed display thousands separators from the numeric editor's initial text. Previously, reopening a count such as 1,000.5 could be parsed as a different decimal value. The regression verifies round-trip editing at 1000.5.
- On the SE, the search test initially tried to activate a result while the keyboard obscured part of its card. The test now submits the query using the existing Search action before selecting a result. The complete search/classics/wine flow then passed.
- Allowed native navigation transitions to settle before screenshots and selected the containing navigation button when a card label is used by a UI test.
- The iPhone 13 mini attempt returned 3 passed and 2 failed UI tests (Learn hittability and Wine Finder field lookup). Screenshot and accessibility inspection showed a red `rdar:45025538` banner and an incorrect 320×568 app window. This matches the Simulator issue discussed on [Apple’s developer forum](https://developer.apple.com/forums/thread/807280). These results are not treated as valid iPhone 13 mini coverage; a different small-screen device was selected.
- A combined two-device test attempt was interrupted after stalling. Device suites were subsequently run separately; the interrupted attempt is not counted as a pass.

## Visual evidence and limits

Actual Simulator screenshots are in [screenshots](screenshots/README.md). Home, Search, cocktail library/detail, batch calculator, Wine Finder, Prep, Stock, Learn and Profile were visually reviewed on both valid device sizes. Smaller screens require more vertical scrolling; controls remain reachable. The interface uses native iOS navigation and tab controls, which differ visually between OS versions; the cream/olive cards, typography and bundled concept photography follow the supplied mockup. The app deliberately uses a light appearance.

No crashes were observed in the passing flows. This validation does not establish live-service usability in three seconds, exhaustive VoiceOver or Dynamic Type coverage, physical-device performance, or compatibility with every iOS 17–26 release. Only the installed iOS 26.2 runtime was available for interaction testing. Those remain release review items.

Menu specifications, wine inventory, prep storage guidance, stock pars and imagery remain illustrative and require venue approval. No Supabase credentials, real authentication, network sync, supplier sending or TestFlight publishing were configured or simulated.
