# Bundled concept assets

Three photographs were generated using the built-in imagegen tool for this implementation. These are illustrations of sample drinks, not documentary Rockwater photography. Final assets are committed inside `BAR/Assets.xcassets/` and work completely offline.

| Asset set | Subject prompt |
| --- | --- |
| `sea-glass.imageset` | One turquoise blue cocktail in a tall clear highball glass, a little golden amber at bottom, large ice cubes, thick creamy white pineapple foam top and one dried pineapple wedge garnish. |
| `peach-bloom.imageset` | One dusty pink peach cocktail in an elegant stemmed coupe glass, delicate pale foam and small edible pink flower garnish. |
| `coral-tide.imageset` | One refreshing coral pink cocktail in a tall clear highball glass with ice cubes and a thin blood orange wheel garnish. |

Each subject used this shared prompt:

> Use case: photorealistic-natural. Asset type: bundled sample cocktail photograph for a premium coastal bar iPhone app. Single glass centered and fully visible from garnish to base, with room around it for portrait and square crops. Warm pale stone tabletop, softly blurred seaside terrace, muted teal sea and beige bokeh. Natural late afternoon side light. Editorial hospitality photography, realistic condensation, refined understated styling, shallow depth of field. Portrait composition. No people, no text, no logos, no watermark. This is concept photography, not a verified restaurant product.

`AppIcon.appiconset` was drawn using native vector paths and rendered to a 1024px PNG: opaque cream background, olive martini outline, a wave and coral garnish. The wine bottle and missing-photo artwork are native SwiftUI drawing components, with no download requirement.

Replace these assets with licensed, venue-approved imagery before operational release if accurate presentation photography is required. Preserve asset-set names or update the matching JSON `imageName` fields.
