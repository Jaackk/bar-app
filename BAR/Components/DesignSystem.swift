import SwiftUI
import UIKit
import BARCore

enum BarTheme {
    static let cream = Color(red: 0.956, green: 0.940, blue: 0.904)
    static let stone = Color(red: 0.886, green: 0.868, blue: 0.824)
    static let ink = Color(red: 0.13, green: 0.15, blue: 0.12)
    static let olive = Color(red: 0.24, green: 0.29, blue: 0.17)
    static let sage = Color(red: 0.76, green: 0.81, blue: 0.68)
    static let coral = Color(red: 0.91, green: 0.69, blue: 0.64)
    static let muted = Color(red: 0.38, green: 0.39, blue: 0.35)
    static let card = Color(red: 0.988, green: 0.980, blue: 0.960)
    static let spacing: CGFloat = 16
    static let radius: CGFloat = 18
    static func title(_ size: CGFloat = 28) -> Font { .custom("Georgia", size: size, relativeTo: .title2) }
}
struct BarCardModifier: ViewModifier {
    func body(content: Content) -> some View { content.padding(16).background(BarTheme.card, in: RoundedRectangle(cornerRadius: BarTheme.radius)).overlay(RoundedRectangle(cornerRadius: BarTheme.radius).stroke(BarTheme.stone.opacity(0.6), lineWidth: 0.6)) }
}
extension View {
    func barCard() -> some View { modifier(BarCardModifier()) }
    func barScreen() -> some View { background(BarTheme.cream.ignoresSafeArea()).foregroundStyle(BarTheme.ink) }
}
struct PrimaryButton: View {
    var title: String
    var systemImage: String = "arrow.right"
    var action: () -> Void
    var body: some View { Button(action: action) { Label(title, systemImage: systemImage).font(.headline).frame(maxWidth: .infinity).frame(minHeight: 52).background(BarTheme.olive, in: RoundedRectangle(cornerRadius: 13)).foregroundStyle(.white) }.buttonStyle(.plain) }
}
struct SectionHeader: View {
    var title: String
    var subtitle: String? = nil
    var body: some View { VStack(alignment: .leading, spacing: 5) { Text(title).font(BarTheme.title(22)); if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(BarTheme.muted) } }.frame(maxWidth: .infinity, alignment: .leading) }
}
struct TagChip: View {
    var title: String
    var selected = false
    var body: some View { Text(title).font(.system(.caption, design: .rounded).weight(.medium)).padding(.horizontal, 13).padding(.vertical, 9).frame(minHeight: 44).foregroundStyle(selected ? .white : BarTheme.ink).background(selected ? BarTheme.olive : BarTheme.stone.opacity(0.6), in: Capsule()).accessibilityAddTraits(selected ? .isSelected : []) }
}
struct EmptyStateView: View {
    var title: String
    var message: String
    var systemImage: String
    var body: some View { VStack(spacing: 12) { Image(systemName: systemImage).font(.system(size: 32, weight: .light)).foregroundStyle(BarTheme.olive); Text(title).font(BarTheme.title(23)); Text(message).font(.subheadline).foregroundStyle(BarTheme.muted).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, 30).padding(.horizontal, 18) }
}
struct SampleLabel: View {
    var body: some View { Label("SAMPLE SPECIFICATION", systemImage: "info.circle").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(BarTheme.muted).accessibilityLabel("Sample specification. Not a verified venue recipe.") }
}
struct SearchBar: View {
    @Binding var text: String
    @FocusState private var editing: Bool
    var focus: FocusState<Bool>.Binding? = nil
    var placeholder = "Cocktails, wine, ingredients…"
    var accessibilityIdentifier = "universal-search"
    var body: some View { HStack(spacing: 10) { Image(systemName: "magnifyingglass").font(.title3); TextField(placeholder, text: $text).font(.subheadline).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search).focused(focus ?? $editing).onSubmit { if let focus { focus.wrappedValue = false } else { editing = false } }.accessibilityIdentifier(accessibilityIdentifier); if !text.isEmpty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(BarTheme.muted).frame(width: 44, height: 44) }.accessibilityLabel("Clear search") } }.padding(.leading, 16).padding(.trailing, 8).frame(minHeight: 54).background(BarTheme.card, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(BarTheme.stone, lineWidth: 0.6)).toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { if let focus { focus.wrappedValue = false } else { editing = false } } } } }
}
struct DrinkArtwork: View {
    let name: String
    var spirit = ""
    var height: CGFloat = 190
    var body: some View {
        Group {
            if !name.isEmpty, !Self.unsuitableReferences.contains(name), UIImage(named: name) != nil {
                if spirit == "Wine" { Image(name).resizable().scaledToFit().frame(maxWidth: .infinity).background(BarTheme.card) }
                else { Image(name).resizable().scaledToFill() }
            }
            else {
                BarCategoryArtwork(category: spirit == "Wine" ? "Wine" : "Cocktail")
            }
        }.frame(height: height).clipped().accessibilityHidden(true)
    }
    // Strawberry Daiquiri, fruit-juice Mai Tai and identical rum promotions do
    // not identify these recipes. Preserve files as evidence, not service art.
    private static let unsuitableReferences: Set<String> = ["cocktail-daiquiri", "cocktail-mai-tai", "cocktail-guava-soda", "cocktail-lychee-lagoon"]
}

/// BAR-owned vector category art. It deliberately depicts no brand or packaging.
/// Labels appear only when there is room; tiny list thumbnails stay uncluttered.
struct BarCategoryArtwork: View {
    let category: String
    private var label: String { category.components(separatedBy: " / ").first ?? category }
    private var motif: String {
        switch category {
        case "Wine", "Sparkling / Champagne", "Cocktail": "glass"
        case "Fresh Herbs", "Garnishes": "leaf"
        case "Fresh Fruit": "fruit"
        case "Beer / Cider", "Non-Alcoholic", "Soft Drinks", "Mixers": "can"
        case "Other", "Ingredient", "Prep", "Purees": "jar"
        default: "bottle"
        }
    }
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let detailed = geometry.size.width >= 110 && geometry.size.height >= 120
            ZStack {
                BarTheme.card
                Circle().fill(BarTheme.sage.opacity(0.24)).frame(width: side * 0.84, height: side * 0.84)
                VStack(spacing: detailed ? 12 : 0) {
                    CategoryLineDrawing(motif: motif)
                        .stroke(BarTheme.olive, style: StrokeStyle(lineWidth: max(1.1, side * 0.009), lineCap: .round, lineJoin: .round))
                        .frame(width: side * 0.56, height: side * (detailed ? 0.50 : 0.68))
                    if detailed {
                        Text(label.uppercased()).font(.system(size: 10, weight: .medium)).tracking(1.3)
                            .foregroundStyle(BarTheme.olive).lineLimit(2).multilineTextAlignment(.center)
                        Text("BAR").font(.custom("Georgia", size: 10)).tracking(2).foregroundStyle(BarTheme.muted)
                    }
                }.padding(.horizontal, 8)
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.accessibilityHidden(true)
    }
}

private struct CategoryLineDrawing: Shape {
    let motif: String
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        func move(_ x: CGFloat, _ y: CGFloat) { p.move(to: point(x, y)) }
        func line(_ x: CGFloat, _ y: CGFloat) { p.addLine(to: point(x, y)) }
        switch motif {
        case "glass":
            move(0.18, 0.12); line(0.82, 0.12)
            p.addQuadCurve(to: point(0.5, 0.60), control: point(0.87, 0.57))
            p.addQuadCurve(to: point(0.18, 0.12), control: point(0.13, 0.57))
            move(0.5, 0.60); line(0.5, 0.90); move(0.29, 0.90); line(0.71, 0.90)
            move(0.25, 0.32); line(0.75, 0.32)
        case "leaf":
            move(0.27, 0.90); line(0.72, 0.12)
            p.addQuadCurve(to: point(0.31, 0.66), control: point(0.08, 0.15))
            p.addQuadCurve(to: point(0.72, 0.12), control: point(0.92, 0.78))
        case "fruit":
            p.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.28, width: rect.width * 0.64, height: rect.height * 0.59))
            move(0.5, 0.28); p.addQuadCurve(to: point(0.72, 0.10), control: point(0.48, 0.07))
            p.addQuadCurve(to: point(0.5, 0.28), control: point(0.77, 0.28))
        case "can", "jar":
            p.addRoundedRect(in: CGRect(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.14, width: rect.width * 0.52, height: rect.height * 0.75), cornerSize: CGSize(width: rect.width * 0.07, height: rect.height * 0.07))
            move(0.26, 0.23); line(0.74, 0.23); move(0.26, 0.78); line(0.74, 0.78)
            move(0.38, 0.44); line(0.62, 0.44); move(0.38, 0.55); line(0.56, 0.55)
        default:
            move(0.40, 0.09); line(0.60, 0.09); line(0.60, 0.29)
            p.addQuadCurve(to: point(0.76, 0.48), control: point(0.76, 0.35))
            line(0.76, 0.90); line(0.24, 0.90); line(0.24, 0.48)
            p.addQuadCurve(to: point(0.40, 0.29), control: point(0.24, 0.35)); line(0.40, 0.09)
            move(0.40, 0.19); line(0.60, 0.19)
            move(0.34, 0.55); line(0.66, 0.55); line(0.66, 0.74); line(0.34, 0.74); line(0.34, 0.55)
        }
        return p
    }
}
struct DrinkCard: View {
    var cocktail: Cocktail
    var body: some View { VStack(alignment: .leading, spacing: 8) { DrinkArtwork(name: cocktail.imageName, spirit: cocktail.baseSpirit, height: 184).clipShape(RoundedRectangle(cornerRadius: 13)); Text(cocktail.name).font(BarTheme.title(17)).foregroundStyle(BarTheme.ink).fixedSize(horizontal: false, vertical: true); Text(cocktail.flavourTags.prefix(3).joined(separator: " · ")).font(.system(size: 10)).foregroundStyle(BarTheme.muted).lineLimit(1) }.frame(width: 145).accessibilityElement(children: .combine) }
}
struct IngredientRow: View {
    var ingredient: Ingredient
    var units = "ml"
    var measurement: String {
        if let source = ingredient.quantityDisplay { return source }; if units == "cl", let ml = ingredient.volumeML { return MeasurementFormatter.string(ml / 10, unit: .cl) }
        return ingredient.measurement
    }
    var body: some View { HStack(alignment: .firstTextBaseline) { Text(ingredient.name).font(.subheadline).fixedSize(horizontal: false, vertical: true); Spacer(minLength: 8); Text(measurement).font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit().fixedSize(horizontal: false, vertical: true).layoutPriority(1) }.padding(.vertical, 10).accessibilityElement(children: .combine) }
}
struct InfoCard: View {
    var title: String
    var value: String
    var systemImage: String
    var body: some View { VStack(spacing: 10) { Image(systemName: systemImage).font(.system(size: 23, weight: .light)).frame(height: 29); Text(title).font(.caption.weight(.semibold)); Text(value).font(.caption2).foregroundStyle(BarTheme.muted).multilineTextAlignment(.center) }.frame(maxWidth: .infinity, minHeight: 106, alignment: .top).padding(.vertical, 14).padding(.horizontal, 3).background(BarTheme.card, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(BarTheme.stone, lineWidth: 0.6)).accessibilityElement(children: .combine) }
}
