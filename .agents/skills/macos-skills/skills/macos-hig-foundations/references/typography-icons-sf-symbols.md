# Typography, SF Symbols, and App Icon Design on macOS

## The system font and text styles

Use the system font (San Francisco) via Apple's text styles instead of a fixed point size, so text automatically gets the right weight, tracking, and optical sizing at every size, and stays consistent with the rest of macOS. Reach for a specific style (`.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.subheadline`, `.body`, `.callout`, `.footnote`, `.caption`, `.caption2`) that matches the role of the text, not the pixel size you happen to want.

```swift
Text("Preferences")
    .font(.title2)
Text("Choose how Mail notifies you of new messages.")
    .font(.body)
    .foregroundStyle(.secondary)
```

## Dynamic Type on Mac

macOS supports Dynamic Type: users can increase text size in System Settings > Accessibility > Display, and apps built with system text styles resize automatically. Don't clip or truncate critical text at larger sizes — test layouts with a larger dynamic type size and let containers (`ScrollView`, `Grid`, multi-line `Text`) accommodate growth instead of fixed-height rows.

```swift
Text(item.title)
    .font(.body)
    .lineLimit(nil)
    .fixedSize(horizontal: false, vertical: true)
```

If a specific view must cap how large text can grow (e.g., a compact status item), scope the limit narrowly rather than disabling Dynamic Type app-wide.

```swift
StatusLabel(text)
    .dynamicTypeSize(...(.large))
```

## Monospaced and rounded font design variants

Use the monospaced design for code, file paths, numeric tables, or anything that benefits from fixed-width alignment; use the rounded design sparingly, for a friendlier, softer tone in specific branded contexts (e.g., a game or a large numeric readout) rather than for body text throughout the app.

```swift
Text(filePath)
    .font(.system(.body, design: .monospaced))

Text("42")
    .font(.system(.largeTitle, design: .rounded, weight: .bold))
```

## SF Symbols: weight and scale

Match a symbol's weight to the weight of the adjacent text, and its scale to the surrounding control size, so icon and label feel like one unit rather than two mismatched elements. Prefer `.imageScale(_:)` or a matching `Font.system(size:weight:)` over manually resizing the `Image` frame, which can distort the symbol's built-in optical balance.

```swift
Label("Delete", systemImage: "trash")
    .font(.system(size: 14, weight: .medium))

Image(systemName: "gearshape")
    .imageScale(.large)
```

## SF Symbols: rendering modes

SF Symbols support four rendering modes — choose the one that matches how much color meaning the symbol needs to carry. `.monochrome` (default) inherits a single foreground color or style; `.hierarchical` applies one base color at varying opacities to show depth; `.palette` lets you assign two or three explicit colors to a symbol's layers; `.multicolor` uses the symbol's own built-in palette (e.g., a flag or weather symbol) and should be used only when that built-in coloring is meaningful, not decorative.

```swift
Image(systemName: "wifi")
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(.blue)

Image(systemName: "folder.fill.badge.plus")
    .symbolRenderingMode(.palette)
    .foregroundStyle(.white, .blue)

Image(systemName: "sun.max.fill")
    .symbolRenderingMode(.multicolor)
```

## SF Symbols: variants and variable value

Prefer a symbol's built-in variant (`.fill`, `.circle`, `.square`, `.slash`) over composing your own overlay, since variants are hand-drawn to align correctly at every scale. For symbols that represent a continuous level (Wi-Fi strength, battery, volume), use `variableValue` instead of swapping between discrete symbol names.

```swift
Image(systemName: "star")
    .symbolVariant(.fill)

Image(systemName: "wifi", variableValue: signalStrength) // 0.0–1.0
```

## Choosing an SF Symbol

Pick the symbol whose name and metaphor already matches Apple's own usage elsewhere in macOS (check Settings, Finder, and first-party apps) so your icon vocabulary feels native; avoid inventing a novel glyph for a common action like delete, search, share, or settings when a standard SF Symbol exists.

## App icon design: the macOS grid

A macOS app icon is a single flat image on a canvas (1024×1024 pt at 1x) that the system automatically masks into the platform's rounded-rectangle (squircle) shape — do not pre-round the corners yourself or add your own drop shadow, since the system applies platform-consistent shadow and edge treatment. Keep the design's important content within the safe area Apple defines inside that canvas so it isn't clipped by the corner mask.

## App icon design: layered icons and Icon Composer

Starting with macOS 26 (Tahoe) and Xcode 26, app icons are authored as layered `.icon` documents in Icon Composer rather than flat PNGs: separate the design into a small number of layers (background, mid, foreground) so the system can apply Liquid Glass specular highlighting, parallax, and automatic light/dark/tinted appearance variants. Build a light and dark (and, if relevant, "clear"/tinted) variant of the icon's colors as part of the same layered document instead of shipping unrelated flat images per appearance.

Design guidance that still applies regardless of tooling: use a single bold, simple shape or mark rather than a busy scene; avoid embedding real UI screenshots, text, or the word "Mac" in the icon; keep a consistent front-on perspective and lighting; and make sure the icon reads clearly at small sizes (16–32 pt, as seen in the Dock, Finder list view, and menu bar) not just at 1024 pt.

## Icons at small sizes

Because the same icon scales down to 16 pt in list views and Spotlight, verify legibility at the smallest rendered size, not only in the full-size preview — simplify details that disappear or become mud at small scale rather than shrinking the whole composition uniformly.
