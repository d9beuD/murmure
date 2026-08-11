# Accessibility, Privacy & App Sandbox (macOS 26 Tahoe / Xcode 26)

## VoiceOver labels, hints, and values

Every control that isn't self-describing from its visible text needs a label; use hint sparingly for non-obvious actions, and value for controls whose state changes (sliders, toggles, custom steppers).

```swift
Button(action: toggleMute) {
    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
}
.accessibilityLabel(isMuted ? "Unmute" : "Mute")
.accessibilityHint("Toggles audio for this track")

Slider(value: $volume, in: 0...1)
    .accessibilityLabel("Volume")
    .accessibilityValue("\(Int(volume * 100)) percent")
```

Add labels at the same time you write the control, not in a later pass — a control shipped without a label is a regression, not a follow-up task.

## Grouping and hiding decorative elements

Combine a cluster of views (icon + title + subtitle) into one VoiceOver stop with `.accessibilityElement(children:)`, and hide purely decorative children.

```swift
HStack {
    Image(systemName: "checkmark.circle.fill")
        .accessibilityHidden(true)
    VStack(alignment: .leading) {
        Text(item.title)
        Text(item.subtitle).font(.caption)
    }
}
.accessibilityElement(children: .combine)
.accessibilityLabel("\(item.title), \(item.subtitle)")
```

Use `.combine` when the sub-views' text can be concatenated sensibly; use `.ignore` plus an explicit `.accessibilityLabel` when you need full control over the announced string.

## Dynamic Type

Prefer `Font` text styles (`.body`, `.headline`, `.title2`, …) over fixed point sizes so text scales with the user's preferred reading size; use `@ScaledMetric` for spacing/icon sizes that should scale proportionally.

```swift
struct RowIcon: View {
    @ScaledMetric(relativeTo: .body) private var iconSize = 20

    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: iconSize))
    }
}
```

Test at the largest accessibility text sizes (System Settings > Accessibility > Display > Text size, or the Accessibility Inspector's Dynamic Type slider) to confirm layouts don't truncate or overlap.

## Reduce Motion and Reduce Transparency

Read the environment values and swap animated/translucent effects for simpler alternatives rather than ignoring the setting.

```swift
struct FadeInCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var visible = false

    var body: some View {
        CardContent()
            .opacity(visible ? 1 : 0)
            .background(reduceTransparency ? Color(.windowBackgroundColor) : .clear)
            .background(.thinMaterial.opacity(reduceTransparency ? 0 : 1))
            .onAppear {
                if reduceMotion {
                    visible = true
                } else {
                    withAnimation(.easeIn(duration: 0.3)) { visible = true }
                }
            }
    }
}
```

## Testing with Accessibility Inspector

Open **Xcode > Open Developer Tool > Accessibility Inspector**, point it at your running app, and use the Inspection pointer to check each control has a non-empty label/role; use the Audit tab to run automated checks (contrast, missing labels, small hit targets) against the whole window. Also do a manual VoiceOver pass (Cmd-F5) tabbing through the window with VO+Right Arrow to confirm reading order matches visual order.

## App Sandbox entitlements

Enable App Sandbox in the target's **Signing & Capabilities** tab, which creates/edits a `.entitlements` file. Request only the entitlements the current feature needs — each one widens the attack surface and is reviewed by App Review.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

Common keys: `com.apple.security.app-sandbox` (required to enable sandboxing at all), `com.apple.security.files.user-selected.read-only` / `read-write` (files the user picked via an open/save panel), `com.apple.security.files.bookmarks.app-scope` / `.document-scope` (persist that access across launches), `com.apple.security.network.client` / `.network.server`, `com.apple.security.device.camera`, `com.apple.security.device.microphone`, `com.apple.security.device.usb`, `com.apple.security.personal-information.location`, `com.apple.security.print`. Full reference: [Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox).

## Security-scoped bookmarks

A sandboxed app loses access to a user-picked file after relaunch unless you persist a security-scoped bookmark and re-resolve it.

```swift
// After the user picks a file in NSOpenPanel:
let bookmarkData = try url.bookmarkData(
    options: .withSecurityScope,
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)
UserDefaults.standard.set(bookmarkData, forKey: "savedFileBookmark")

// On a later launch:
var isStale = false
let restoredURL = try URL(
    resolvingBookmarkData: bookmarkData,
    options: .withSecurityScope,
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
)
guard restoredURL.startAccessingSecurityScopedResource() else { return }
defer { restoredURL.stopAccessingSecurityScopedResource() }
// ... read/write restoredURL ...
```

Always pair `startAccessingSecurityScopedResource()` with a matching `stopAccessingSecurityScopedResource()`, and re-create the bookmark if `isStale` comes back `true`.

## Privacy: Info.plist usage descriptions

Add a usage-description key before calling any API that triggers a system permission prompt — the app crashes at runtime if the key is missing. Write a short, specific reason string; do not request a permission the current feature doesn't use.

```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan documents into your notes.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Used to record voice memos attached to a note.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to tag new notes with your current location.</string>
```

Other common keys: `NSPhotoLibraryUsageDescription`, `NSContactsUsageDescription`, `NSCalendarsFullAccessUsageDescription`, `NSRemindersFullAccessUsageDescription`, `NSAppleEventsUsageDescription` (scripting other apps), `NSDesktopFolderUsageDescription`/`NSDocumentsFolderUsageDescription`/`NSDownloadsFolderUsageDescription` (direct access to those folders outside a picker), `NSRemovableVolumesUsageDescription`, `NSNetworkVolumesUsageDescription`. Request permission lazily, right when the feature is used, not at launch — and minimize what you collect/retain even after the user grants access.
