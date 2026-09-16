import Foundation

/// Keeps recipe language intact while making the operational catalogue describe
/// only things that can actually be bought, stored or counted.
public enum ProductCatalogueCorrections {
    /// IDs retired from the imported recipe-component catalogue and the real
    /// stock product that replaces each one.  A nil value means that the record
    /// was only recipe language/a generic concept and has no safe stock target.
    public static let replacements: [String: String?] = [
        "spec-lime": "menu-limes",
        "spec-orange-slice": "spec-orange",
        "spec-blend-passionfruit": "spec-passion-fruit-puree",
        "spec-blackberry": "service-blackberries",
        "spec-pineapple-foam-top": nil,
        "menu-oj": "menu-orange-juice",
        "spec-apple": "menu-apple-juice",
        "spec-pineapple": "menu-pineapple-juice",
        "spec-tomato": "menu-tomato-juice",
        "spec-orange-jucie": "menu-orange-juice",
        "spec-belnd-triple-sec": "spec-blend-triple-sec",
        "spec-hot-water": nil,
        "spec-peach-liq": "spec-teichene-peach",
        "spec-peroni": "menu-peroni-nastro-azzurro-5",
        "spec-blend-coffee": "spec-espresso",
        "spec-coffee-espresso-shots": "spec-espresso",
        "spec-soda": "spec-soda-top",
        "spec-angostura": "spec-angostura-bitters",
        "spec-disarrono": "menu-disaronno",
        "spec-orgeat-syrup": "menu-orgeat",
        "spec-gomme": "spec-gomme-syrup",
        "spec-rose-prosecco": "menu-prosecco-collezione-96-rose-masottina",
        "spec-veuve-cliquot-brut": "menu-veuve-clicquot-brut-yellow-label",
        "spec-old-forestor": "menu-old-forrester-bourbon",
        "spec-salcombe-rose": "menu-salcombe-rose-sainte-marie",
        "spec-chilli-infused-el-jimador-blanca": "menu-el-jimador-blanco",
        "spec-fruit": nil,
        "spec-desired-fruits": nil,
        "spec-desired-puree": nil,
        "spec-desired-syrup": nil,
        "spec-white-wine": nil,
        "spec-cremant": nil
    ]

    /// The source menu uses a handful of abbreviated labels.  They remain
    /// searchable aliases, while the visible catalogue uses a clear stock name.
    private static let edits: [String: (name: String?, category: String?, aliases: [String])] = [
        "menu-limes": (nil, nil, ["Lime", "Lime wedge", "Lime wedges", "Lime wheel", "Muddled lime", "Pressed lime", "Fresh squeeze lime wedge"]),
        "menu-lemons": (nil, nil, ["Lemon", "Lemon wedge", "Lemon wedges"]),
        "spec-cucumber-slices-muddled": ("Cucumber", "Fresh Fruit", ["Cucumber slices", "Muddled cucumber"]),
        "spec-dd-pink-grapefruit": ("Daily Dose Pink Grapefruit Juice", "Juices", ["DD Pink Grapefruit", "Daily Dose Pink Grapefruit"]),
        "spec-dd-lime-juice": ("Daily Dose Lime Juice", "Juices", ["DD Lime", "Daily Dose Lime", "Dd Lime Juice"]),
        "spec-dd-lemon-juice": ("Daily Dose Lemon Juice", "Juices", ["DD Lemon", "Daily Dose Lemon", "Dd Lemon Juice"]),
        "spec-watermelon-liq": ("Watermelon Liqueur", "Liqueurs / Aperitifs", ["Watermelon Liq"]),
        "spec-blend-triple-sec": ("Triple Sec", "Liqueurs / Aperitifs", ["Blend Triple Sec", "Belnd Triple Sec", "Dash of Triple Sec"]),
        "spec-apricot-liq": ("Apricot Liqueur", "Liqueurs / Aperitifs", ["Apricot Liq"]),
        "spec-teichene-peach": ("Teichenne Peach Liqueur", "Liqueurs / Aperitifs", ["Teichene Peach", "Peach Liqueur", "Peach Liq"]),
        "spec-martini-extra-dry": (nil, "Liqueurs / Aperitifs", []),
        "spec-worchester": ("Worcestershire Sauce", "Other", ["Worchester", "Worcestershire"]),
        "spec-soda-top": ("Soda Water", "Mixers", ["Soda", "Soda top"]),
        "spec-angostura-bitters": (nil, "Bitters", ["Angostura"]),
        "spec-coconut-milk": (nil, "Other", []),
        "spec-gomme-syrup": (nil, "Syrups / Cordials", ["Gomme"]),
        "spec-agave": ("Agave Syrup", "Syrups / Cordials", ["Agave"]),
        "spec-vanilla": ("Vanilla Syrup", "Syrups / Cordials", ["Vanilla"]),
        "spec-pimms": ("Pimm's", "Liqueurs / Aperitifs", ["Pimms"]),
        "spec-cachaca": ("Cachaça", "Other", ["Cachaca"]),
        "spec-creme-de-mure": ("Crème de Mûre", "Liqueurs / Aperitifs", []),
        "spec-creme-de-cassis": ("Crème de Cassis", "Liqueurs / Aperitifs", []),
        "spec-pisco": (nil, "Brandy / Cognac", []),
        "spec-olive-brine-if-dirty": ("Olive Brine", "Garnishes", ["Olive brine (if dirty)"])
    ]

    private static let individualImageNames: [String: String] = [
        "menu-limes": "lime-photo",
        "menu-lemons": "lemon-photo",
        "spec-orange": "orange-photo",
        "service-strawberries": "strawberry-photo",
        "menu-trip-lemon-basil": "trip-lemon-basil",
        "menu-still-water-75cl": "still-water-75cl",
        "menu-drip-still-water-500ml": "drip-still-water-500ml",
        "menu-apple-juice": "apple-juice",
        "menu-orange-juice": "orange-juice",
        "menu-pineapple-juice": "pineapple-juice",
        "menu-cranberry-juice": "cranberry-juice",
        "menu-tomato-juice": "tomato-juice",
        "menu-ginger-x-hot-shot": "ginger-x-hot-shot",
        "menu-grey-goose-essences": "grey-goose-essences",
        "menu-limoncello": "limoncello",
        "menu-sambuca": "sambuca",
        "menu-sugar-syrup": "sugar-syrup",
        "menu-orgeat": "orgeat",
        "spec-apricot-liq": "apricot-liq",
        "spec-blue-curacao": "blue-curacao",
        "spec-ginger-syrup": "ginger-syrup",
        "spec-cachaca": "cachaca",
        "spec-guava-puree": "guava-puree",
        "spec-teichene-peach": "teichene-peach",
        "spec-lime-juice": "lime-juice",
        "spec-jasmine-syrup": "jasmine-syrup",
        "spec-lemon-juice": "lemon-juice",
        "spec-passion-fruit-puree": "passion-fruit-puree",
        "spec-blood-orange-syrup": "blood-orange-syrup",
        "spec-orange-bitters": "orange-bitters",
        "spec-watermelon-syrup": "watermelon-syrup",
        "spec-grapefruit-soda": "grapefruit-soda",
        "spec-pisco": "pisco",
        "spec-elderflower-cordial": "elderflower-cordial",
        "spec-strawberry-syrup": "strawberry-syrup",
        "spec-cherry-syrup": "cherry-syrup",
        "spec-simple-syrup": "simple-syrup",
        "spec-blend-triple-sec": "blend-triple-sec",
        "spec-ginger-beer": "ginger-beer",
        "spec-peach-liqueur": "peach-liqueur",
        "spec-creme-de-mure": "creme-de-mure",
        "spec-maraschino": "maraschino",
        "spec-grenadine": "grenadine",
        "spec-agave": "agave",
        "spec-gomme-syrup": "gomme-syrup",
        "spec-angostura-bitters": "angostura-bitters",
        "spec-peach-puree": "peach-puree",
        "spec-creme-de-cassis": "creme-de-cassis",
        "spec-lemonade": "lemonade",
        "menu-sparkling-water-75cl": "sparkling-water-75cl",
        "menu-drip-sparkling-water-500ml": "drip-sparkling-water-500ml",
        "menu-glorious-greens": "glorious-greens",
        "menu-ginger-zinger": "ginger-zinger",
        "spec-sweet-vermouth": "sweet-vermouth",
        "spec-coconut-water": "coconut-water",
        "spec-nll-fl": "nll-fl",
        "spec-nll-ms": "nll-ms",
        "menu-cinsault-rose-leeuwenkuil-family-vineyards": "leeuwenkuil-cinsault-rose",
        "menu-apres-provence-chateau-des-bertrands": "apres-provence",
        "menu-rioja-alavesa-las-parcelas-bideona": "bideona-las-parcelas",
        "menu-real-blush-sparkling": "real-dry-sparkling",
        "menu-picpoul-de-pinet-tournee-du-sud": "lafage-les-sardines-chardonnay",
        "menu-grenache-chardonnay-cote-est-domaine-lafage": "lafage-les-sardines-chardonnay",
        "menu-cotes-de-provence-maia": "minuty-prestige",
        "menu-cotes-de-provence-maia-magnum": "minuty-prestige",
        "menu-touriga-nacional-santo-isidro-de-pegoes": "santo-isidro-pegoes-touriga",
        "menu-syrah-tumbleweed-big-sky-bruce-jack-wines": "bruce-jack-tumbleweed-syrah",
        "menu-raboso-il-casone": "san-marzano-talo",
        "menu-montepulciano-blend-anima-osca-tenimenti-grieco": "anima-osca-rosso",
        "menu-agiorgitiko-mavroudi-voltes-monemvasia-winery": "monemvasia-voltes-red",
        "menu-saumur-champigny-vieilles-vignes-domaine-lavigne": "bruce-jack-tumbleweed-syrah",
        "menu-cotes-du-rhone-villages-plan-de-dieu-saint-damien": "bruce-jack-tumbleweed-syrah",
        "menu-cabernet-sauvignon-paso-doro": "bruce-jack-tumbleweed-syrah",
        "menu-rivesaltes-tuile-dom-brial": "dom-brial-rivesaltes-tuile",
        "menu-lbv-quinta-do-vallado": "castelnau-de-suduiraut",
        "menu-tawny-20yr-quinta-do-vallado": "castelnau-de-suduiraut",
        "menu-rockwater-lager-3-4": "bar-staples",
        "menu-rockwater-ipa-4-7": "bar-staples",
        "menu-cornish-orchards-fruit-cider-4": "cornish-orchards-raspberry-elderflower",
        "menu-antica-rosso": "martini-rosso",
        "spec-spicy-tincture": "bar-staples",
        "spec-soda-top": "bar-staples",
        "spec-coconut-milk": "bar-staples",
        "spec-oggs": "oggs-aquafaba",
        "spec-lychee-juice": "bar-staples",
        "spec-espresso": "bar-staples",
        "spec-vanilla": "bar-staples",
        "spec-dd-lime-juice": "bar-staples",
        "spec-dd-lemon-juice": "bar-staples",
        "spec-worchester": "bar-staples",
        "spec-tabasco-3-standard": "bar-staples",
        "spec-salt": "bar-staples",
        "spec-pepper": "bar-staples",
        "spec-whole-milk": "bar-staples",
        "spec-double-cream": "bar-staples",
        "spec-ms-betters-bitters": "bar-staples",
        "spec-tabasco": "bar-staples",
        "spec-saline": "bar-staples",
        "spec-coconut-cream": "bar-staples",
        "spec-brown-sugar": "bar-staples",
        "service-ice-cubes": "bar-staples",
        "service-crushed-ice": "bar-staples"
    ]

    public static func corrected(_ imported: [Product]) -> [Product] {
        var products = imported.filter { replacements[$0.id] == nil && !replacements.keys.contains($0.id) }
        // Preserve the legacy IDs as aliases on the target product so a saved
        // recipe phrase can always be found without creating a second stock SKU.
        for (oldID, targetID) in replacements {
            guard let targetID, let old = imported.first(where: { $0.id == oldID }), let target = products.firstIndex(where: { $0.id == targetID }) else { continue }
            products[target].aliases = Array(Set(products[target].aliases + [old.name] + old.aliases)).sorted()
        }
        for index in products.indices {
            guard let edit = edits[products[index].id] else { continue }
            if let name = edit.name { products[index].name = name }
            if let category = edit.category { products[index].category = category }
            products[index].aliases = Array(Set(products[index].aliases + edit.aliases)).sorted()
        }
        for index in products.indices where individualImageNames[products[index].id] != nil {
            products[index].imageName = individualImageNames[products[index].id]!
        }
        // Regularly ordered milk variants are genuine operational items even
        // where the menu import did not carry a brand.  They intentionally use
        // generic names rather than inventing a supplier or a brand.
        let venueID = imported.first?.venueID ?? "rockwater-hove"
        let milk: [Product] = [
            Product(id: "service-skimmed-milk", venueID: venueID, name: "Skimmed Milk", category: "Other", unit: "carton", defaultOrderUnit: "carton", aliases: ["Skinny Milk", "Skimmed milk"]),
            Product(id: "service-oat-milk", venueID: venueID, name: "Oat Milk", category: "Other", unit: "carton", defaultOrderUnit: "carton"),
            Product(id: "service-almond-milk", venueID: venueID, name: "Almond Milk", category: "Other", unit: "carton", defaultOrderUnit: "carton"),
            Product(id: "service-soy-milk", venueID: venueID, name: "Soy Milk", category: "Other", unit: "carton", defaultOrderUnit: "carton")
        ]
        return products + milk
    }

    public static func canonicalID(for oldID: String) -> String? {
        replacements[oldID] ?? oldID
    }

    public static func canonicalID(forIngredientName name: String, products: [Product]) -> String? {
        let key = SearchNormalizer.normalize(name)
        return products.first { product in
            SearchNormalizer.normalize(product.name) == key || product.aliases.contains { SearchNormalizer.normalize($0) == key }
        }?.id
    }
}
