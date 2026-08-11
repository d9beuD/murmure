# Layout, Color, and Materials on macOS

## Window sizing and resizing

Mac windows are user-resizable by default; design for a range of sizes rather than one fixed layout. Set a sensible minimum content size so controls never clip or overlap, and let content reflow (wrap, truncate, or reveal more columns) as the window grows, instead of stretching whitespace. Avoid forcing a fixed window size unless the content genuinely cannot resize (e.g., a small utility panel).

```swift
ContentView()
    .frame(minWidth: 480, idealWidth: 800, minHeight: 300, idealHeight: 600)
```

## Adaptability across window and Split View sizes

A macOS window can be full-size, tiled in Split View, or manually resized to a narrow sliver — the same view hierarchy must handle all of these. Use `NavigationSplitView` so the sidebar collapses and the detail view takes over at narrow widths, and use `ViewThatFits` or conditional layouts when a toolbar or control group needs a compact alternative. Do not assume a minimum width based only on your default window size.

```swift
NavigationSplitView {
    SidebarView()
} detail: {
    DetailView()
}
```

## Safe areas and content insets

Content should not sit under the title bar, toolbar, or a translucent sidebar unless that's an intentional edge-to-edge design; respect `safeAreaInsets` so text and controls stay legible over materials. When you do extend content under a toolbar for a full-bleed look (common with `.toolbar` and translucent backgrounds in macOS 26), add your own padding so the first line of content clears the controls.

```swift
ScrollView {
    content
}
.contentMargins(.top, 12, for: .scrollContent)
```

## Alignment and spacing conventions

Mac layouts read as calm and grid-aligned: align labels, controls, and leading edges on a consistent baseline rather than eyeballing offsets. Use the 8-point spacing scale (4, 8, 12, 16, 20, 24…) for padding and gaps instead of arbitrary numbers, and let `Form`, `Grid`, or `LabeledContent` handle label/control alignment rather than manual `Spacer()` tuning.

```swift
Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 12) {
    GridRow { Text("Name"); TextField("", text: $name) }
    GridRow { Text("Path"); TextField("", text: $path) }
}
```

## System and semantic colors

Never hardcode a hex or RGB color for text, backgrounds, or separators — use the semantic roles Apple provides, which remap automatically for Dark Mode, increased contrast, and future appearance changes. On macOS the AppKit equivalents (`NSColor.labelColor`, `.secondaryLabelColor`, `.tertiaryLabelColor`, `.windowBackgroundColor`, `.controlBackgroundColor`, `.separatorColor`) back the SwiftUI semantic colors.

```swift
Text("Title").foregroundStyle(.primary)
Text("Subtitle").foregroundStyle(.secondary)
Divider().foregroundStyle(Color(nsColor: .separatorColor))
```

## Accent color and tinting

Respect the user's system accent color (set in System Settings > Appearance) for selection highlights, default buttons, and links — don't bake in a fixed brand blue for controls that should track the user's choice. Use `Color.accentColor` (or `Color(nsColor: .controlAccentColor)` in AppKit-bridged code) rather than a literal color, and reserve a custom brand tint for places, like a logo or a chart series, that intentionally shouldn't follow the system accent.

```swift
Button("Save") { save() }
    .tint(.accentColor)
```

## Dark Mode support

Every screen must be verified in both Light and Dark appearance; the most common bug is a hardcoded light-only background or an image asset without a dark variant. Test with System Settings > Appearance switching, and with `.preferredColorScheme(.dark)` in SwiftUI previews, rather than assuming semantic colors alone guarantee correctness for custom-drawn content or image assets.

```swift
#Preview("Dark") {
    ContentView().preferredColorScheme(.dark)
}
```

Provide "Any Appearance" (universal) or explicit dark variants for image and color assets in the asset catalog, and never composite a fixed opaque overlay color on top of vibrant/material backgrounds — it will look wrong in one appearance.

## Materials, vibrancy, and translucency

Materials give Mac chrome (sidebars, toolbars, popovers) a translucent, vibrant background that tints toward whatever is behind the window, unifying the app with the desktop. Pick the material by role, not by eyeballing opacity: use a thin/regular material for sidebars and toolbars, a thicker material for content that needs more contrast behind text, and let SwiftUI's built-in materials do the vibrancy math rather than approximating it with opacity.

```swift
List(items, selection: $selection) { item in
    Text(item.title)
}
.background(.regularMaterial)
```

Available SwiftUI `Material` levels are `.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial`, `.thickMaterial`, and `.ultraThickMaterial`, plus the toolbar/tab-bar-oriented `.bar` material. In AppKit-bridged code, `NSVisualEffectView` materials map to specific roles (`.sidebar`, `.headerView`, `.titlebar`, `.menu`, `.popover`, `.hudWindow`, `.underWindowBackground`, `.contentBackground`) — use the role that matches the surface, since each is tuned for how much of the desktop should show through and how vibrant foreground content should render.

## Liquid Glass materials (macOS 26 Tahoe)

macOS 26 introduced Liquid Glass, a system-wide material that adds specular highlights and dynamic light response on top of standard vibrancy for toolbars, sidebars, sheets, and controls. Let system components (toolbars, `NavigationSplitView` sidebars, sheets, alerts) pick up Liquid Glass automatically rather than re-implementing it with custom shaders; only reach for the `glassEffect` APIs on custom controls that sit in chrome-like contexts (floating panels, custom toolbars), and avoid stacking multiple glass surfaces directly on top of each other since it degrades legibility.

```swift
Label("Favorites", systemImage: "star.fill")
    .padding(8)
    .glassEffect()
```

## Avoiding hardcoded values

Any literal `Color(red:green:blue:)`, fixed point size, or fixed pixel offset is a signal to stop and ask whether a semantic color, system text style, or system spacing constant already exists for that purpose — in almost every case on macOS it does.
