import SwiftUI
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
    static func title(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .medium, design: .serif) }
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
    var body: some View { Text(title).font(.system(.caption, design: .rounded).weight(.medium)).padding(.horizontal, 13).padding(.vertical, 9).foregroundStyle(selected ? .white : BarTheme.ink).background(selected ? BarTheme.olive : BarTheme.stone.opacity(0.6), in: Capsule()).accessibilityAddTraits(selected ? .isSelected : []) }
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
    var placeholder = "Cocktails, wine, ingredients…"
    var body: some View { HStack(spacing: 10) { Image(systemName: "magnifyingglass").font(.title3); TextField(placeholder, text: $text).font(.subheadline).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search).focused($editing).onSubmit { editing = false }.accessibilityIdentifier("universal-search"); if !text.isEmpty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(BarTheme.muted).frame(width: 44, height: 44) }.accessibilityLabel("Clear search") } }.padding(.leading, 16).padding(.trailing, 8).frame(minHeight: 54).background(BarTheme.card, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(BarTheme.stone, lineWidth: 0.6)).toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } } } }
}
struct DrinkArtwork: View {
    let name: String
    var spirit = ""
    var height: CGFloat = 190
    var body: some View {
        Group {
            if !name.isEmpty, UIImage(named: name) != nil { Image(name).resizable().scaledToFill() }
            else {
                ZStack {
                    LinearGradient(colors: [BarTheme.stone, BarTheme.sage.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(BarTheme.card.opacity(0.45)).frame(width: height * 0.65).offset(x: height * 0.1, y: -height * 0.06)
                    Image(systemName: spirit == "Wine" ? "wineglass" : "wineglass.fill").font(.system(size: height * 0.42, weight: .ultraLight)).foregroundStyle(BarTheme.olive.opacity(0.7)).shadow(color: BarTheme.olive.opacity(0.12), radius: 6, y: 10)
                }
            }
        }.frame(height: height).clipped().accessibilityHidden(true)
    }
}
struct DrinkCard: View {
    var cocktail: Cocktail
    var body: some View { VStack(alignment: .leading, spacing: 8) { DrinkArtwork(name: cocktail.imageName, spirit: cocktail.baseSpirit, height: 184).clipShape(RoundedRectangle(cornerRadius: 13)); Text(cocktail.name).font(BarTheme.title(17)).foregroundStyle(BarTheme.ink).lineLimit(1); Text(cocktail.flavourTags.prefix(3).joined(separator: " · ")).font(.system(size: 10)).foregroundStyle(BarTheme.muted).lineLimit(1) }.frame(width: 145).accessibilityElement(children: .combine) }
}
struct IngredientRow: View {
    var ingredient: Ingredient
    var units = "ml"
    var measurement: String {
        if units == "cl", let ml = ingredient.volumeML { return MeasurementFormatter.string(ml / 10, unit: .cl) }
        return ingredient.measurement
    }
    var body: some View { HStack(alignment: .firstTextBaseline) { Text(ingredient.name).font(.subheadline); Spacer(minLength: 8); Text(measurement).font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit() }.padding(.vertical, 10).accessibilityElement(children: .combine) }
}
struct InfoCard: View {
    var title: String
    var value: String
    var systemImage: String
    var body: some View { VStack(spacing: 10) { Image(systemName: systemImage).font(.system(size: 23, weight: .light)).frame(height: 29); Text(title).font(.caption.weight(.semibold)); Text(value).font(.caption2).foregroundStyle(BarTheme.muted).multilineTextAlignment(.center) }.frame(maxWidth: .infinity, minHeight: 106, alignment: .top).padding(.vertical, 14).padding(.horizontal, 3).background(BarTheme.card, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(BarTheme.stone, lineWidth: 0.6)).accessibilityElement(children: .combine) }
}
