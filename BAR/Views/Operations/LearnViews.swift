import SwiftUI
import BARCore

struct LearnView: View {
    @Environment(AppStore.self) private var store
    @State private var learningSet = "Classics"
    private var classics: [Cocktail] { store.cocktails.filter { $0.recipeVerified }.filter { !$0.venueSpecific || $0.isHouseClassic } }
    private var masteredCount: Int { classics.filter { store.training.masteredCocktailIDs.contains($0.id) }.count }
    private var mastery: Double { classics.isEmpty ? 0 : Double(masteredCount) / Double(classics.count) }
    private var studyCocktails: [Cocktail] {
        switch learningSet {
        case "Venue": return store.cocktails.filter { $0.recipeVerified }.filter { $0.venueSpecific && !$0.isHouseClassic }
        case "All drinks": return store.cocktails.filter { $0.recipeVerified }
        default: return classics
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A little practice.\nA more confident service.").font(BarTheme.title(30))
                    Text("Learn the drinks on your bar, one recipe at a time.").font(.subheadline).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Classics mastered").font(BarTheme.title(22))
                        Spacer()
                        Text(mastery, format: .percent.precision(.fractionLength(0))).font(.title.weight(.medium).monospacedDigit()).foregroundStyle(BarTheme.olive)
                    }
                    ProgressView(value: mastery).tint(BarTheme.olive)
                    Text("\(masteredCount) of \(classics.count) classics most recently answered correctly.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Label("\(store.training.answered) answers", systemImage: "checklist")
                        Spacer()
                        Text(store.training.answered == 0 ? "Your first session awaits" : "\(Int((store.training.accuracy * 100).rounded()))% accuracy")
                    }.font(.caption)
                }.barCard()
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Choose your drinks")
                    Picker("Learning set", selection: $learningSet) {
                        Text("Classics").tag("Classics")
                        Text("Venue").tag("Venue")
                        Text("All drinks").tag("All drinks")
                    }.pickerStyle(.segmented)
                }
                if studyCocktails.isEmpty {
                    EmptyStateView(title: "No drinks in this set", message: "Choose another set to start learning.", systemImage: "book")
                } else {
                    VStack(spacing: 12) {
                        NavigationLink { FlashcardSessionView(cocktails: studyCocktails) } label: {
                            learningCard(title: "Cocktail flashcards", detail: "Turn over a drink. Recall the specification.", symbol: "rectangle.on.rectangle.angled", count: "\(studyCocktails.count) drinks")
                        }
                        NavigationLink { QuizSessionView(cocktails: studyCocktails, kind: .recipe) } label: {
                            learningCard(title: "Recipe quiz", detail: "Choose the ingredients that belong together.", symbol: "list.bullet.clipboard", count: "\(min(10, studyCocktails.count)) questions")
                        }
                        NavigationLink { QuizSessionView(cocktails: studyCocktails, kind: .ingredient) } label: {
                            learningCard(title: "Ingredient quiz", detail: "Know what goes into every serve.", symbol: "drop", count: "\(min(10, studyCocktails.count)) questions")
                        }
                    }.buttonStyle(.plain)
                }
                Text("Questions use the recipes currently loaded for your venue. Sample venue recipes are for practice until your verified menu is imported.")
                    .font(.caption).foregroundStyle(.secondary).lineSpacing(3)
            }.padding(20)
        }.barScreen().navigationTitle("Learn").navigationBarTitleDisplayMode(.inline)
    }

    private func learningCard(title: String, detail: String, symbol: String, count: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 27, weight: .light)).foregroundStyle(BarTheme.olive)
                .frame(width: 54, height: 66).background(BarTheme.sage.opacity(0.3), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(BarTheme.title(22))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                Text(count.uppercased()).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(BarTheme.olive)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
        }.barCard()
    }
}

private struct FlashcardSessionView: View {
    let cocktails: [Cocktail]
    @Environment(AppStore.self) private var store
    @State private var cards: [Cocktail] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var correct = 0
    @State private var started = false
    private var complete: Bool { started && !cards.isEmpty && index >= cards.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if complete {
                    sessionFinished
                } else if cards.indices.contains(index) {
                    let drink = cards[index]
                    HStack {
                        Text("CARD \(index + 1) OF \(cards.count)").font(.caption.weight(.semibold)).tracking(1.4)
                        Spacer()
                        Text("Recall, then reveal").font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(index), total: Double(cards.count)).tint(BarTheme.olive)
                    VStack(alignment: .leading, spacing: 18) {
                        DrinkArtwork(name: drink.imageName, spirit: drink.baseSpirit, height: 220).clipShape(RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 8) {
                            Text(drink.name).font(BarTheme.title(30))
                            Text(drink.baseSpirit + " · " + drink.category).font(.subheadline).foregroundStyle(.secondary)
                            if drink.isSample { SampleLabel() }
                        }
                        if revealed {
                            Divider()
                            ForEach(drink.ingredients) { ingredient in IngredientRow(ingredient: ingredient, units: store.preferences.units) }
                            Divider()
                            Label("\(drink.method) · \(drink.glass)", systemImage: "wineglass").font(.subheadline.weight(.medium))
                            if !drink.garnish.isEmpty { Text("Garnish: \(drink.garnish)").font(.subheadline) }
                        } else {
                            Text("Can you recall the ingredients, measurements and method?").font(.subheadline).lineSpacing(3).foregroundStyle(.secondary)
                        }
                    }.barCard()
                    if revealed {
                        HStack(spacing: 12) {
                            Button { answer(correctly: false) } label: {
                                Label("Review again", systemImage: "arrow.counterclockwise").font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 54).background(BarTheme.stone.opacity(0.65), in: RoundedRectangle(cornerRadius: 13))
                            }.buttonStyle(.plain)
                            PrimaryButton(title: "I knew it", systemImage: "checkmark") { answer(correctly: true) }
                        }
                    } else {
                        PrimaryButton(title: "Reveal specification", systemImage: "eye") { withAnimation(.easeInOut(duration: 0.2)) { revealed = true } }
                    }
                } else {
                    EmptyStateView(title: "No flashcards available", message: "Add recipes to your venue library to begin a session.", systemImage: "book")
                }
            }.padding(20)
        }.id(index).barScreen().navigationTitle("Flashcards").navigationBarTitleDisplayMode(.inline)
            .onAppear { if !started { restart() } }
    }

    private var sessionFinished: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "checkmark.seal").font(.system(size: 42, weight: .light)).foregroundStyle(BarTheme.olive)
            Text("Practice, poured in.").font(BarTheme.title(32))
            Text("You recalled \(correct) of \(cards.count) recipes. Your progress is saved for next time.").font(.body).lineSpacing(4)
            PrimaryButton(title: "Practise again", systemImage: "arrow.clockwise") { restart() }
        }.barCard()
    }

    private func answer(correctly: Bool) {
        guard cards.indices.contains(index) else { return }
        store.recordTraining(cocktailID: cards[index].id, correct: correctly)
        if correctly { correct += 1 }
        index += 1
        revealed = false
    }

    private func restart() {
        cards = cocktails.shuffled()
        index = 0
        correct = 0
        revealed = false
        started = true
    }
}

private struct QuizSessionView: View {
    let cocktails: [Cocktail]
    let kind: QuizKind
    @Environment(AppStore.self) private var store
    @State private var questions: [QuizQuestion] = []
    @State private var index = 0
    @State private var selected: String?
    @State private var correct = 0
    @State private var started = false
    private var title: String { kind == .recipe ? "Recipe quiz" : "Ingredient quiz" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if !questions.isEmpty && index >= questions.count {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: "checkmark.seal").font(.system(size: 42, weight: .light)).foregroundStyle(BarTheme.olive)
                        Text("A stronger next service.").font(BarTheme.title(31))
                        Text("\(correct) / \(questions.count)").font(.system(size: 48, weight: .medium, design: .serif)).foregroundStyle(BarTheme.olive)
                        Text(correct == questions.count ? "Every recipe recalled. Keep the knowledge fresh with another session." : "Good practice. Revisit the recipes you missed and come back for another round.")
                            .font(.body).lineSpacing(4)
                        Text("Progress saved on this device.").font(.caption).foregroundStyle(.secondary)
                        PrimaryButton(title: "New quiz", systemImage: "arrow.clockwise") { restart() }
                    }.barCard()
                } else if questions.indices.contains(index) {
                    let question = questions[index]
                    HStack {
                        Text("QUESTION \(index + 1) OF \(questions.count)").font(.caption.weight(.semibold)).tracking(1.3)
                        Spacer()
                        Text("\(correct) correct").font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(index), total: Double(questions.count)).tint(BarTheme.olive)
                    Text(question.prompt).font(BarTheme.title(29)).padding(.vertical, 10)
                    VStack(spacing: 12) {
                        ForEach(question.options, id: \.self) { option in
                            Button { choose(option, question: question) } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    Text(option).font(.body).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                                    if selected != nil && question.isCorrect(option) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(BarTheme.olive)
                                    } else if selected == option {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color(red: 0.65, green: 0.29, blue: 0.23))
                                    } else {
                                        Circle().stroke(BarTheme.stone, lineWidth: 1.5).frame(width: 22, height: 22)
                                    }
                                }.frame(minHeight: 38).padding(16)
                                    .background(optionBackground(option, question: question), in: RoundedRectangle(cornerRadius: 15))
                                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(selected == option ? BarTheme.olive : BarTheme.stone.opacity(0.6), lineWidth: selected == option ? 1.3 : 0.6))
                            }.buttonStyle(.plain).disabled(selected != nil)
                                .accessibilityIdentifier("quiz-option-" + String(question.options.firstIndex(of: option) ?? 0))
                                .accessibilityLabel(option + (selected != nil && question.isCorrect(option) ? ", correct answer" : ""))
                        }
                    }
                    if let selected {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(question.isCorrect(selected) ? "Exactly right." : "One to remember.").font(BarTheme.title(23))
                            if !question.isCorrect(selected) { Text("Correct answer: \(question.correctAnswer)").font(.subheadline).lineSpacing(3) }
                            NavigationLink { CocktailDetailView(cocktailID: question.cocktailID) } label: { Label("Review the full specification", systemImage: "book") }.font(.subheadline.weight(.medium))
                        }.barCard()
                        PrimaryButton(title: index + 1 == questions.count ? "See results" : "Next question", systemImage: "arrow.right") {
                            index += 1
                            self.selected = nil
                        }
                    }
                } else {
                    EmptyStateView(title: "A few more recipes needed", message: "Choose a larger learning set to generate useful multiple-choice questions.", systemImage: "book")
                }
            }.padding(20)
        }.id(index).barScreen().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .onAppear { if !started { restart() } }
    }

    private func optionBackground(_ option: String, question: QuizQuestion) -> Color {
        guard selected != nil else { return BarTheme.card }
        if question.isCorrect(option) { return BarTheme.sage.opacity(0.5) }
        if selected == option { return BarTheme.coral.opacity(0.35) }
        return BarTheme.card
    }

    private func choose(_ option: String, question: QuizQuestion) {
        guard selected == nil else { return }
        selected = option
        let isCorrect = question.isCorrect(option)
        if isCorrect { correct += 1 }
        store.recordTraining(cocktailID: question.cocktailID, correct: isCorrect)
    }

    private func restart() {
        questions = QuizService.questions(cocktails: cocktails.shuffled(), kind: kind, limit: 10)
        index = 0
        correct = 0
        selected = nil
        started = true
    }
}
