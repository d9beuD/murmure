# Documents, Drag and Drop, and Data Entry

## Document-based apps: pick the right scene

If the app's primary content is user-created files (text, drawings, projects), use SwiftUI's `DocumentGroup` scene instead of hand-rolling window/file management. `DocumentGroup` gives you the standard File menu (New, Open, Open Recent, Save, Save As/Duplicate, Move To, Rename, Revert To), the open panel, and per-document windows for free. Conform your model to `FileDocument` (value types, synchronous) or `ReferenceFileDocument` (reference types, supports incremental undo-friendly edits) — don't implement `NSDocument` directly unless you need AppKit-only behavior `DocumentGroup` doesn't expose.

```swift
struct RecipeDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var recipe: Recipe

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        recipe = try JSONDecoder().decode(Recipe.self, from: data)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try JSONEncoder().encode(recipe))
    }
}

@main
struct RecipeApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: RecipeDocument(recipe: .blank)) { file in
            RecipeEditor(document: file.$document)
        }
    }
}
```

## Autosave and versions, not manual Save

macOS users expect autosave: the document saves continuously in the background, and "Save" becomes optional except when explicitly duplicating. `DocumentGroup` and `NSDocument` both support autosave and integrate with the Versions browser (Time Machine-backed) automatically when you opt into `NSDocument`'s `autosavesInPlace` — for `DocumentGroup` this is largely handled for you. Never build a custom "unsaved changes" dialog that blocks quitting when the system's Save/Don't Save/Cancel sheet already covers it; let the standard dirty-tracking (`updateChangeCount` / SwiftUI's document diffing) drive it instead of a bespoke flag you maintain in parallel.

## Open and save panels

Use `NSOpenPanel`/`NSSavePanel` (or SwiftUI's `.fileImporter`/`.fileExporter`) rather than a custom in-app file browser — users rely on the system panel's sidebar, tags, search, and recents. Set `allowedContentTypes` narrowly, set a sensible `directoryURL` default (last-used location, not always home), and give the panel a specific `message` or prompt string so the user knows what they're choosing a location for.

```swift
.fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
    // handle Result<URL, Error>
}
```

## Drag and drop

Make anything a user would reasonably expect to relocate draggable: list rows, canvas objects, files, images, text selections. Use `.draggable(_:)` to source a drag with a `Transferable` payload, and `.dropDestination(for:)` to accept one; both are the SwiftUI-native replacement for manually configuring `NSItemProvider`, which you still reach for only when interoperating with AppKit views or `NSPasteboard`-specific types SwiftUI doesn't yet model.

```swift
List(items) { item in
    ItemRow(item: item)
        .draggable(item)
}
.dropDestination(for: Item.self) { dropped, location in
    items.append(contentsOf: dropped)
    return true
}
```

Always provide a preview that represents the dragged content (a snapshot of the row/thumbnail, not a generic icon) and show a clear insertion point or highlight on the destination while hovering — SwiftUI generates a reasonable default preview automatically from the view being dragged, but override it with `.draggable(_:preview:)` when the default (e.g. a whole wide row) is visually noisy. Support dragging out to the Finder and other apps wherever the content is meaningful outside your app (files, images, text), and dragging in from Finder/other apps as an alternative to the Open panel, not the only way in.

## Entering data: order, defaults, validation

Lay out forms top-to-bottom in the order a person would naturally fill them in, group related fields with `Section`/`LabeledContent`, and pre-fill every field you can reasonably infer (last-used value, system locale, a computed default) rather than leaving fields empty and making the user do avoidable work. Use `Form` for macOS settings-style and inspector-style data entry; it lays out labels and controls consistently without manual alignment code.

```swift
Form {
    Section("Shipping Address") {
        TextField("Street", text: $address.street)
        TextField("City", text: $address.city)
        TextField("Postal Code", text: $address.postalCode)
            .textContentType(.postalCode)
    }
}
```

## Inline validation and AutoFill

Validate as the user finishes a field (on commit/blur), not on every keystroke and not only at final submit — show the problem inline next to the field with specific, actionable text ("Postal code must be 5 digits"), not a blocking alert. Reserve a blocking alert for a submit-time check that spans multiple fields or has a real consequence. Set `textContentType` (`.emailAddress`, `.postalCode`, `.name`, `.password`, etc.) on relevant fields so the system can offer AutoFill and password-manager suggestions; without it, AutoFill has nothing to match against and the form feels less native.

```swift
TextField("Email", text: $email)
    .textContentType(.emailAddress)
    .overlay(alignment: .trailing) {
        if let error = emailError { Text(error).foregroundStyle(.red).font(.caption) }
    }
```

Disable the submit action until required fields are valid rather than letting the user submit and then scolding them with an alert full of errors — surfacing problems earlier and locally is both faster to fix and less disruptive.
