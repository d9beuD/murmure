# State Management and Data Flow

## @State for view-local, value-type state

`@State` owns simple, view-local data — the view that declares it is the source of truth, and SwiftUI persists it across body re-evaluations.

```swift
struct SearchField: View {
    @State private var query = ""

    var body: some View {
        TextField("Search", text: $query)
    }
}
```

Use `@State` for UI-only state (text field contents, toggle state, `isPresented` flags) that has no meaning outside this one view. Also use `@State` to hold an `@Observable` model instance when this view is the model's owner.

## @Binding for two-way references to state owned elsewhere

`@Binding` gives a child view read/write access to state owned by a parent, without the child owning or copying it.

```swift
struct Toggle_: View {
    @Binding var isOn: Bool
    var body: some View { Toggle("Enabled", isOn: $isOn) }
}
```

Pass bindings down explicitly for small, single-purpose child views; for anything larger, prefer injecting an `@Observable` model instead of threading many individual bindings.

## @Observable and @Bindable — the modern default

`@Observable` (Observation framework) turns a class into an observable model; SwiftUI tracks exactly which properties a view reads and only re-renders on changes to those. This is the default for new view models and shared models on macOS 26.

```swift
@Observable
final class NotesModel {
    var notes: [Note] = []
    var selection: Note.ID?

    func addNote() {
        notes.append(Note())
    }
}

struct NotesListView: View {
    @State private var model = NotesModel()

    var body: some View {
        List(model.notes, selection: Bindable(model).selection) { note in
            Text(note.title)
        }
    }
}
```

Own an `@Observable` model with `@State` at the point that creates it; further down the tree, take it as a plain `let`/property (no wrapper needed to just read it) or use `@Bindable` when a child needs a `$`-binding into one of its properties.

```swift
struct EditorView: View {
    @Bindable var model: NotesModel

    var body: some View {
        if let index = model.notes.firstIndex(where: { $0.id == model.selection }) {
            TextField("Title", text: $model.notes[index].title)
        }
    }
}
```

`@Bindable` is what unlocks `$model.property` syntax for an `@Observable` reference type passed into a view; without it you can read properties but can't derive a `Binding` from them.

## @Environment for dependency injection

`@Environment` reads a value placed into the view hierarchy by an ancestor via `.environment(_:)` — the standard way to inject shared `@Observable` models without threading them through every initializer.

```swift
@main
struct App_: App {
    @State private var session = UserSession()
    var body: some Scene {
        WindowGroup { RootView().environment(session) }
    }
}

struct ProfileView: View {
    @Environment(UserSession.self) private var session
    var body: some View { Text(session.displayName) }
}
```

`@Environment(Type.self)` (custom `@Observable` types) is distinct from `@Environment(\.keyPath)` (built-in environment values like `\.colorScheme` or custom `EnvironmentKey`s) — both use the same property wrapper but different subscripts.

## Legacy: @StateObject, @ObservedObject, @EnvironmentObject

Pre-Observation code (or code that must support older OS deployment targets) uses `ObservableObject` classes with `@Published` properties, owned via `@StateObject` and read via `@ObservedObject`/`@EnvironmentObject`.

```swift
final class LegacyModel: ObservableObject {
    @Published var count = 0
}

struct LegacyView: View {
    @StateObject private var model = LegacyModel()
    var body: some View { Button("\(model.count)") { model.count += 1 } }
}
```

You'll still see these in older codebases or tutorials; `@StateObject` is the ownership wrapper (like `@State` for reference types), `@ObservedObject` is for a passed-in reference you don't own, and `@EnvironmentObject` is the `ObservableObject`-era equivalent of `@Environment(Type.self)`. Don't mix `ObservableObject` and `@Observable` for the same type, and don't add new `ObservableObject` models to a codebase that's otherwise on `@Observable`.

## MV pattern: state directly in the view via an @Observable model

The lightweight "MV" (Model-View) pattern skips a dedicated ViewModel layer: an `@Observable` model holds both state and the logic that mutates it, and the view binds to it directly.

```swift
@Observable
final class CounterModel {
    var count = 0
    func increment() { count += 1 }
}

struct CounterView: View {
    @State private var model = CounterModel()
    var body: some View {
        Button("Count: \(model.count)") { model.increment() }
    }
}
```

MV works well when a screen's "business logic" is thin — the model *is* the view model, there's no separate translation layer, and SwiftUI's fine-grained observation makes the extra ViewModel indirection unnecessary busywork for simple screens.

## Fuller MVVM: separating view logic from business/domain logic

For screens with real domain logic (network calls, persistence, validation independent of any UI concern), keep a ViewModel that depends on domain/service types, separate from the domain types themselves.

```swift
@Observable
final class ArticleListViewModel {
    private let service: ArticleService
    var articles: [Article] = []
    var isLoading = false

    init(service: ArticleService) { self.service = service }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        articles = try? await service.fetchArticles() ?? []
    }
}

struct ArticleListView: View {
    @State var viewModel: ArticleListViewModel
    var body: some View {
        List(viewModel.articles) { ArticleRow(article: $0) }
            .task { await viewModel.load() }
    }
}
```

The ViewModel owns UI-facing state (`isLoading`, formatted strings) and orchestrates calls to injected services; the view stays declarative and never calls the network or database directly. Mark methods that mutate UI-observed state `@MainActor` (or make the whole class `@MainActor`) since `@Observable` property writes must happen on the main actor when views observe them.

## Avoiding massive views

When a view's body grows past a screenful, split by extracting subviews (not just computed properties) and by pushing decision-making into the model rather than `if`/`switch` chains in the body.

```swift
struct DashboardView: View {
    @State private var model = DashboardModel()
    var body: some View {
        VStack {
            DashboardHeader(model: model)
            DashboardContent(model: model)
        }
    }
}
```

Prefer many small `View` structs over one large body with local `@ViewBuilder` computed properties — separate structs get their own identity and diffing, which also limits how much of the tree re-evaluates per state change. Keep decision logic ("which state am I in") as a computed property or method on the model, not scattered across view conditionals.

## Choosing where business logic lives

Business/domain logic (validation rules, calculations, persistence, networking) belongs on the model or a service the model depends on — never inside a view's `body` or in a button's action closure beyond a one-line call into the model.

```swift
Button("Save") { model.save() }   // good: view delegates
Button("Save") {                  // avoid: logic in the view
    guard !model.name.isEmpty else { return }
    try? modelContext.save()
}
```

If an action closure needs more than a single call into the model/service, that's a sign the logic belongs on the model, not inlined in the view.
