import XCTest
@testable import BARCore

final class ProductImageResolverTests: XCTestCase {
    func testOfficialReplacementAssetsReplaceLegacyGroupImagesWithoutEditingProduct() {
        let replacements = [
            "menu-patron-silver": "bar-patron-silver",
            "menu-patron-reposado": "bar-patron-reposado",
            "menu-cotes-du-rhone-villages-plan-de-dieu-saint-damien": "bar-saint-damien",
            "menu-cabernet-sauvignon-paso-doro": "bar-paso-doro"
        ]
        for (id, image) in replacements {
            var product = Product(id: id, venueID: "rockwater-hove", name: id, imageName: "legacy-group")
            XCTAssertEqual(ProductImageResolver.source(for: product), .bundled(image))
            XCTAssertEqual(product.imageName, "legacy-group")
            product.imageData = Data([4, 5, 6])
            XCTAssertEqual(ProductImageResolver.source(for: product), .custom)
            XCTAssertEqual(product.imageData, Data([4, 5, 6]))
        }
    }

    func testLogosAmbiguousExpressionsAndWrongMagnumPacksUseFallback() {
        for id in ["menu-asahi-0-0", "menu-orange-juice", "menu-kraken", "spec-sweet-vermouth",
                   "menu-grey-goose-essences", "menu-veuve-clicquot-brut-yellow-label-magnum",
                   "menu-minuty-prestige-chateau-minuty-magnum"] {
            var product = Product(id: id, venueID: "rockwater-hove", name: id, imageName: "legacy-photo")
            XCTAssertNil(ProductImageResolver.bundledImageName(for: product), id)
            XCTAssertFalse(ProductImageResolver.hasRelevantImage(for: product,
                canRenderBundledImage: { _ in true }, canRenderCustomImage: { _ in true }), id)
            product.imageData = Data([7])
            XCTAssertEqual(ProductImageResolver.source(for: product), .custom, id)
        }
    }

    func testNoillyPratSpellingPreservesIdentityAndLegacySearchAlias() throws {
        let old = Product(id: "menu-noilly-pratt", venueID: "rockwater-hove", name: "Noilly Pratt")
        let corrected = try XCTUnwrap(ProductCatalogueCorrections.corrected([old]).first { $0.id == old.id })
        XCTAssertEqual(corrected.name, "Noilly Prat")
        XCTAssertTrue(corrected.aliases.contains("Noilly Pratt"))
        XCTAssertEqual(corrected.venueID, old.venueID)
        XCTAssertEqual(old.name, "Noilly Pratt")
    }

    func testUnavailableNamedAssetIsMissingEvenWhenCorrectionProvidesItsName() {
        let product = Product(id: "menu-trip-lemon-basil", venueID: "rockwater-hove", name: "TRIP Lemon & Basil")
        var checkedName: String?
        XCTAssertFalse(ProductImageResolver.hasRelevantImage(
            for: product,
            canRenderBundledImage: { checkedName = $0; return false },
            canRenderCustomImage: { _ in XCTFail("No custom photo should be decoded"); return true }
        ))
        XCTAssertEqual(checkedName, "trip-lemon-basil")
    }

    func testRenderableNamedAssetIsComplete() {
        let product = Product(venueID: "venue", name: "Bottle", imageName: "existing-bottle")
        XCTAssertTrue(ProductImageResolver.hasRelevantImage(
            for: product, canRenderBundledImage: { $0 == "existing-bottle" }, canRenderCustomImage: { _ in false }
        ))
    }

    func testCustomPhotoMustDecodeAndTakesPriorityOverBundledDefault() {
        var product = Product(venueID: "venue", name: "Bottle", imageName: "existing-bottle")
        let localPhoto = Data([1, 2, 3])
        product.imageData = localPhoto
        XCTAssertTrue(ProductImageResolver.hasRelevantImage(
            for: product,
            canRenderBundledImage: { _ in XCTFail("A custom photo takes priority"); return false },
            canRenderCustomImage: { $0 == localPhoto }
        ))
        // The thumbnail shows fallback for corrupt custom bytes, not the bundled
        // default; completeness must describe the same visible result.
        XCTAssertFalse(ProductImageResolver.hasRelevantImage(
            for: product, canRenderBundledImage: { _ in true }, canRenderCustomImage: { _ in false }
        ))
    }

    func testGenericArtworkIsMissingEvenWhenItCanRender() {
        let product = Product(venueID: "venue", name: "Mint", category: "Fresh Herbs", imageName: "fresh-herbs")
        XCTAssertFalse(ProductImageResolver.hasRelevantImage(
            for: product, canRenderBundledImage: { _ in true }, canRenderCustomImage: { _ in true }
        ))
    }

    func testConfirmedWrongDefaultsAreRejectedWithoutChangingLocalPhotos() {
        let defaults = [
            "menu-glorious-greens": "glorious-greens",
            "menu-ginger-zinger": "ginger-zinger",
            "menu-drip-sparkling-water-500ml": "drip-sparkling-water-500ml",
            "menu-sparkling-water-75cl": "sparkling-water-75cl",
            "spec-nll-fl": "nll-fl",
            "spec-nll-ms": "nll-ms"
        ]
        for (id, oldImage) in defaults {
            var product = Product(id: id, venueID: "rockwater-hove", name: id, imageName: oldImage)
            XCTAssertNil(ProductImageResolver.bundledImageName(for: product), id)
            XCTAssertFalse(ProductImageResolver.hasRelevantImage(
                for: product, canRenderBundledImage: { _ in true }, canRenderCustomImage: { _ in true }
            ), id)
            let localPhoto = Data([9, 8, 7])
            product.imageData = localPhoto
            XCTAssertEqual(ProductImageResolver.source(for: product), .custom, id)
            XCTAssertTrue(ProductImageResolver.hasRelevantImage(
                for: product, canRenderBundledImage: { _ in false }, canRenderCustomImage: { $0 == localPhoto }
            ), id)
            XCTAssertEqual(product.imageData, localPhoto, id)
        }
    }

    func testRejectedWineDefaultCannotReappearThroughLegacyWineImageName() {
        var product = Product(id: "menu-picpoul-de-pinet-tournee-du-sud", venueID: "rockwater-hove", name: "Picpoul", category: "Wine", imageName: "lafage-les-sardines-chardonnay")
        let wine = Wine(id: "old-wine", productID: product.id, name: "Picpoul", imageName: "lafage-les-sardines-chardonnay")
        XCTAssertEqual(WineProductResolver.imageSource(for: wine, products: [product]), .fallback)
        product.imageData = Data([1, 2, 3])
        XCTAssertEqual(WineProductResolver.imageSource(for: wine, products: [product]), .customProductImage(product))
    }
}
