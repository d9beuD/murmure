# Lists, Tables, Pickers, Text Input, and Labels (macOS 26 Tahoe)

## Menu-style pickers for larger or open-ended option sets

Use `Picker` with the default `.menu` style (or explicit `.menu`) when there are more options than a radio group should show, or the set can grow (fonts, encodings, user-defined presets). This renders as a pop-up button showing the current value.

```swift
Picker("Font", selection: $fontName) {
    ForEach(availableFonts, id: \.self) { name in
        Text(name).tag(name)
    }
}
.pickerStyle(.menu)
```

## Editable combo-box-style pickers

AppKit's `NSComboBox` (free text entry plus a drop-down of suggestions) has no direct SwiftUI control; approximate it by pairing a `TextField` with a `Menu` or a filtered suggestion list, keeping the text field as the source of truth. Only reach for this when users legitimately need to enter a value outside the suggested set — otherwise use a plain `Picker`.

```swift
HStack {
    TextField("Tag", text: $tagText)
        .textFieldStyle(.roundedBorder)
    Menu {
        ForEach(recentTags, id: \.self) { tag in
            Button(tag) { tagText = tag }
        }
    } label: {
        Image(systemName: "chevron.down")
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
}
```

## Lists for simple, single-column, selectable rows

Use `List` for homogeneous rows of content where a single column of information (optionally with a leading icon/detail) is enough — sidebars, master lists, settings rows. Support single or multiple selection explicitly rather than relying on row taps alone.

```swift
List(items, selection: $selectedID) { item in
    Label(item.name, systemImage: item.symbolName)
}
.listStyle(.inset)
```

## Tables for multi-column, sortable data

Use `Table` on macOS whenever data has more than one comparable attribute the user should be able to scan and sort by (file size, date modified, status) — this is the direct Mac idiom for Finder-like or spreadsheet-like data, and it is not available in the same form on iOS.

```swift
struct Item: Identifiable {
    let id: UUID
    var name: String
    var size: Int
    var modified: Date
}

@State private var items: [Item] = []
@State private var sortOrder = [KeyPathComparator(\Item.modified, order: .reverse)]

Table(items, sortOrder: $sortOrder) {
    TableColumn("Name", value: \.name)
    TableColumn("Size") { item in
        Text(item.size, format: .byteCount(style: .file))
    }
    TableColumn("Modified", value: \.modified) { item in
        Text(item.modified, format: .dateTime.day().month().year())
    }
}
.onChange(of: sortOrder) { _, newOrder in
    items.sort(using: newOrder)
}
```

## Disclosure groups for a single collapsible section

Use `DisclosureGroup` for one section of optional detail the user expands on demand (advanced options, an inspector subsection). Keep the label short and state what's inside; don't nest more than one level deep — nest `OutlineGroup`/hierarchical data instead.

```swift
DisclosureGroup("Advanced Options", isExpanded: $showsAdvanced) {
    Toggle("Enable experimental renderer", isOn: $experimentalRenderer)
        .toggleStyle(.checkbox)
    Stepper("Cache size: \(cacheSizeMB) MB", value: $cacheSizeMB, in: 16...512, step: 16)
}
```

## Outline groups for recursive/tree data

Use `OutlineGroup` (or `List` with a recursive `children` key path) for genuinely hierarchical data — file systems, nested folders, outline documents — where rows can contain child rows of the same type. This gives the native Mac disclosure-triangle outline behavior.

```swift
struct Node: Identifiable {
    let id = UUID()
    var name: String
    var children: [Node]?
}

List(rootNodes, children: \.children) { node in
    Label(node.name, systemImage: node.children == nil ? "doc" : "folder")
}
```

## Text fields for single-line input

Use `TextField` for short, single-line values. Bind directly to a typed value with a `FormatStyle` when the field represents a number, currency, or date, rather than parsing strings by hand — this gives locale-correct formatting and inline validation for free.

```swift
TextField("Price", value: $price, format: .currency(code: "USD"))
    .textFieldStyle(.roundedBorder)

TextField("Quantity", value: $quantity, format: .number)
    .textFieldStyle(.roundedBorder)
    .multilineTextAlignment(.trailing)
```

## Secure fields for passwords and secrets

Use `SecureField` for passwords, tokens, and other secrets the user shouldn't see rendered on screen. Never substitute a plain `TextField` with manual character-masking.

```swift
SecureField("Password", text: $password)
    .textFieldStyle(.roundedBorder)
```

## Text editors for multi-line free-form text

Use `TextEditor` for paragraphs or longer free-form text (notes, descriptions, code snippets) where a single-line `TextField` would truncate content. Wrap it in a bordered container since `TextEditor` has no built-in chrome.

```swift
TextEditor(text: $notes)
    .font(.body)
    .frame(minHeight: 120)
    .overlay(
        RoundedRectangle(cornerRadius: 6)
            .stroke(.separator, lineWidth: 1)
    )
```

## Labels for icon + text pairs

Use `Label` anywhere an SF Symbol and a text string represent the same concept (list rows, buttons, status). Let the system, not manual `HStack`s, handle icon/text alignment and Dynamic Type/VoiceOver behavior; use `.labelStyle(.iconOnly)` or `.titleOnly` only when space genuinely requires it, and keep the hidden half available to accessibility.

```swift
Label("Downloads", systemImage: "arrow.down.circle")
    .labelStyle(.titleAndIcon)
```

Cross-reference: for the button, toggle, and radio/segmented controls that often sit next to these, see `references/buttons-toggles-selection-controls.md`. For determinate/indeterminate progress alongside a long-running list/table operation, see `references/progress-indicators-color-wells.md`.
