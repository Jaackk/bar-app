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
        "service-strawberries": "strawberry-photo"
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
