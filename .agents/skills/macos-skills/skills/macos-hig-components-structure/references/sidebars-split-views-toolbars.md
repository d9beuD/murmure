# Sidebars, Split Views, and Toolbars (macOS 26 Tahoe)

## NavigationSplitView is the default sidebar container

For any app with a primary list of items (mailboxes, projects, folders, chats), use `NavigationSplitView` rather than a hand-built `HSplitView` plus manual selection state — it gives you the standard sidebar look, the built-in sidebar toggle in the toolbar, correct behavior when resizing or collapsing, and free adaptation to compact widths.

```swift
struct MailApp: View {
    @State private var selectedMailbox: Mailbox.ID?

    var body: some View {
        NavigationSplitView {
            List(mailboxes, selection: $selectedMailbox) { mailbox in
                Label(mailbox.name, systemImage: mailbox.symbol)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            if let selectedMailbox {
                MessageListView(mailboxID: selectedMailbox)
            } else {
                Text("Select a Mailbox")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

Always show an explicit empty/placeholder state in the detail column when nothing is selected — don't leave it blank.

## Three-column split views

When the sidebar's selection drives a second list (e.g., mailbox → messages → message body), add a middle content column and keep the third as the detail. Give each column sane min/ideal/max widths so the layout doesn't collapse the content list to zero width on a small display.

```swift
struct MailApp: View {
    @State private var selectedMailbox: Mailbox.ID?
    @State private var selectedMessage: Message.ID?

    var body: some View {
        NavigationSplitView {
            SidebarList(selection: $selectedMailbox)
        } content: {
            MessageListView(mailboxID: selectedMailbox, selection: $selectedMessage)
                .navigationSplitViewColumnWidth(min: 240, ideal: 320)
        } detail: {
            MessageDetailView(messageID: selectedMessage)
        }
    }
}
```

Don't add a fourth column by nesting another `NavigationSplitView` inside the detail — if you need more structure at that depth, use tabs or a segmented control within the detail view instead.

## Sidebar content: sections and grouping

Group sidebar rows with `Section` when items fall into natural categories (Favorites, Mailboxes, Smart Mailboxes) — this matches Finder, Mail, and Notes. Use SF Symbols for row icons at a consistent, small size; don't mix custom glyph styles with system symbols in the same sidebar.

```swift
List(selection: $selection) {
    Section("Favorites") {
        ForEach(favorites) { item in
            Label(item.name, systemImage: item.symbol)
        }
    }
    Section("Mailboxes") {
        ForEach(mailboxes) { mailbox in
            Label(mailbox.name, systemImage: "tray")
        }
    }
}
.listStyle(.sidebar)
```

## Toggling the sidebar

Let the system-provided sidebar toggle button (added automatically in the toolbar's leading position by `NavigationSplitView`) handle show/hide — don't build a second custom sidebar-toggle button unless you're replacing the default behavior entirely. If you do need a custom toggle, drive `NavigationSplitViewVisibility` explicitly and keep only one control that changes it.

```swift
struct BrowserView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarList()
        } detail: {
            DetailView()
        }
    }
}
```

## Toolbars: action-oriented and consistent with menus

Populate `.toolbar { }` with the app's most frequent, high-value actions — not every menu command. Every toolbar item should have an equivalent menu command (with a keyboard shortcut, where conventional); never put an action in the toolbar that isn't reachable from a menu, and vice versa for primary actions.

```swift
ContentView()
    .toolbar {
        ToolbarItem(placement: .navigation) {
            Button {
                addItem()
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                share()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                toggleFilter()
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
    }
```

## Toolbar placement and icons

Use `ToolbarItem`/`ToolbarItemGroup` placements deliberately: `.navigation` for items near the sidebar toggle, `.primaryAction` for the single most important trailing action, `.secondaryAction` for supporting actions, and the default/`.automatic` for everything else, letting the system decide ordering. Prefer an SF Symbol + `Label` (icon-only display comes from the toolbar's own presentation, not from omitting the text label) so labels remain available in Customize Toolbar and via VoiceOver.

```swift
ToolbarItem(placement: .primaryAction) {
    Button {
        isInspectorVisible.toggle()
    } label: {
        Label("Inspector", systemImage: "sidebar.trailing")
    }
}
```

Keep icons at a consistent SF Symbol weight/scale across the toolbar (see macos-hig-foundations for symbol rendering details) and avoid mixing icon-only buttons with text-label buttons in the same toolbar row unless there's a strong reason (e.g., a search field).

## Customizable toolbars

If the app has more than a handful of toolbar actions, let users customize the toolbar rather than cramming every action in permanently. Give each `ToolbarItem` a stable `id` so customization state persists correctly across launches, and mark truly essential items so they can't be removed to an empty toolbar.

```swift
.toolbar(id: "mainToolbar") {
    ToolbarItem(id: "add", placement: .primaryAction) {
        Button("Add", systemImage: "plus") { addItem() }
    }
    ToolbarItem(id: "filter", placement: .secondaryAction) {
        Button("Filter", systemImage: "line.3.horizontal.decrease.circle") { toggleFilter() }
    }
}
```

Don't duplicate a toolbar customization identifier across windows that hold different content — each distinct toolbar layout needs its own `id`.
