# Distribution, Signing, Notarization & Localization (macOS 26 Tahoe / Xcode 26)

## Code signing concepts

Every distributed app needs a valid signing identity (Developer ID Application for outside-the-App-Store distribution, Apple Distribution for the Mac App Store) and, for Developer ID builds, the **Hardened Runtime** capability enabled in Signing & Capabilities. Hardened Runtime restricts things like unsigned code loading and DYLD environment variables; if your app needs an exception (e.g., a JIT, or loading an unsigned plugin), add the specific entitlement rather than disabling the runtime.

```xml
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

Check current signing state at any time:

```bash
codesign --verify --deep --strict --verbose=2 /Applications/MyApp.app
codesign -dv --entitlements :- /Applications/MyApp.app
```

## Developer ID vs. Mac App Store

Developer ID builds are signed with a Developer ID Application certificate, notarized directly by you, and distributed via your own download/DMG — App Sandbox is optional (but still recommended) and you have full control of update cadence and entitlements. Mac App Store builds are signed with an Apple Distribution certificate, submitted through Xcode/Transporter for App Review, and **must** have App Sandbox enabled — every entitlement you request is visible to reviewers, so request the minimum. Choose Developer ID when you need entitlements the sandbox can't grant (e.g., broad filesystem access, certain kernel/driver work) or want to ship outside review timelines; choose the Mac App Store for discoverability and StoreKit-based purchases.

## Notarizing with notarytool

`altool` is retired; `notarytool` is the only supported path. Store credentials once in the keychain, then submit the built, signed app (zipped or as a DMG/pkg) and wait for the result.

```bash
# One-time: store an app-specific-password based profile
xcrun notarytool store-credentials "AC_NOTARY_PROFILE" \
  --apple-id "you@example.com" \
  --team-id "ABCDE12345" \
  --password "app-specific-password"

# Submit and wait synchronously for Apple's response
ditto -c -k --keepParent "MyApp.app" "MyApp.zip"
xcrun notarytool submit "MyApp.zip" \
  --keychain-profile "AC_NOTARY_PROFILE" \
  --wait

# If something fails, pull the detailed log
xcrun notarytool log <submission-id> --keychain-profile "AC_NOTARY_PROFILE"
```

## Stapling

Staple the notarization ticket to the app (and to the DMG/pkg you distribute) so Gatekeeper can verify offline, then confirm Gatekeeper accepts it.

```bash
xcrun stapler staple "MyApp.app"
spctl --assess --type execute --verbose "MyApp.app"
```

Staple every artifact you actually ship (the `.app` inside a `.dmg`, and/or the `.dmg`/`.pkg` itself) — a stapled `.app` inside an unstapled `.dmg` still needs network access to verify on first launch.

## Sandboxing requirements for the Mac App Store

App Review rejects submissions without `com.apple.security.app-sandbox` set to `true`. Audit your entitlements file before submission: remove anything left over from debugging (e.g., a broad `files.all` style entitlement you no longer need) and make sure every entitlement maps to a feature actually present in the build.

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

## Localization basics

Prefer `String(localized:)` over `NSLocalizedString` in new SwiftUI code — it infers the key from the string itself and integrates with Xcode's `.xcstrings` catalogs.

```swift
Text(String(localized: "welcome.title", defaultValue: "Welcome back"))

Label(
    String(localized: "file.count", defaultValue: "^[\(count) file](inflect: true)"),
    systemImage: "doc"
)
```

## String Catalogs (.xcstrings)

Add a `Localizable.xcstrings` file to the target (**File > New > File > String Catalog**); Xcode extracts `String(localized:)` calls automatically and shows translation state (New/Needs Review/Translated) per language in its built-in editor — no manual `.strings`/`.stringsdict` merging needed.

## Pluralization

For plural-sensitive strings, use the `xcstrings` catalog's plural variation editor (backed by `.stringsdict`-style rules) rather than hand-rolling `if count == 1` branches, so each locale's actual plural rules (which can have more than the English two forms) apply automatically.

```swift
Text("^[\(itemCount) item](inflect: true)")
```

Keep interpolated values as arguments to the localized string (not string-concatenated afterward) so translators can reorder them for languages with different word order.
