---
name: macos-app-architecture
description: >-
  Use when structuring a macOS SwiftUI app's code: App/@main entry point,
  Scene types (WindowGroup, Window, Settings, DocumentGroup, MenuBarExtra),
  multi-window/multi-scene setups, state management (@State, @Binding,
  @Observable, @Bindable, @Environment, legacy @StateObject/@ObservedObject/
  @EnvironmentObject), MV vs MVVM data flow, avoiding massive views, or AppKit
  interop (NSViewRepresentable, NSHostingController, NSApplicationDelegateAdaptor)
  for macOS 26 Tahoe SwiftUI apps.
---

Structure the code, state, and data flow of a macOS 26 Tahoe SwiftUI app so views stay thin, state has one clear owner, and AppKit is used only where SwiftUI has no equivalent.

## Use this skill when

- Deciding how to declare `@main`, the `App` struct, and which `Scene` type(s) to use.
- Wiring up a second window, a Settings scene, a document-based app, or a menu bar extra.
- Choosing between `@State`, `@Observable`, `@Environment`, or legacy `@StateObject`/`@ObservedObject`/`@EnvironmentObject`.
- Deciding where business logic should live vs. view logic, or splitting up a massive view.
- Passing shared/dependency state down through a view hierarchy (dependency injection).
- Wrapping an `NSView`/`NSViewController` for use in SwiftUI, or embedding SwiftUI in AppKit.
- Needing an `NSApplicationDelegate` callback SwiftUI doesn't expose (dock menu, open-file-from-Finder, etc.).

## Do not use this skill when

- Choosing colors/typography/materials — use macos-hig-foundations.
- Choosing which specific window/control component to render — use macos-hig-components-structure or macos-hig-components-controls.
- Deciding layout, navigation, or interaction patterns at the HIG level — use macos-hig-patterns.
- Picking a specific input control's behavior — use macos-hig-inputs.
- Testing, sandboxing, code signing, or distributing the app — use macos-best-practices.
- Fixing Swift-language-level concurrency/Sendable errors unrelated to SwiftUI state — that's a separate swift-concurrency skill outside this repo.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested architecture works.

1. Identify the architectural question and open EXACTLY ONE reference file from the list below.
2. Default to `@Observable` for any new view model or shared model — only reach for `@StateObject`/`@ObservedObject`/`@EnvironmentObject` when maintaining pre-Observation code.
3. Keep views declarative and thin: no business logic in view bodies. Push logic, validation, and networking into an `@Observable` model type.
4. Give each piece of state exactly one owner (`@State` in the view that creates it, or an `@Observable` model injected via `@Environment`/initializer). Never duplicate the same fact in two places.
5. For sharing state across a view subtree, prefer `@Environment` injection of an `@Observable` model over passing bindings through many layers.
6. Only drop to AppKit (`NSViewRepresentable`, `NSApplicationDelegateAdaptor`, etc.) when SwiftUI genuinely has no API for what's needed — check the reference file before assuming that's the case.
7. Verify the fix compiles conceptually (correct property wrappers, no missing `@MainActor` on UI-touching model methods) and that data flows one direction: model to view, and back through explicit actions/bindings.
8. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not introduce a second competing state-management pattern in the same feature.
- Do not mix `@Observable` and `@StateObject`/`ObservableObject` for the same model type.
- Stop as soon as data flows correctly end-to-end.

## Reference files

- `references/app-scene-window-structure.md` — open when setting up `@main`/`App`, choosing or combining `Scene` types, or handling multi-window/multi-scene behavior.
- `references/state-management-data-flow.md` — open when choosing property wrappers, structuring MV/MVVM, injecting dependencies, or splitting up a massive view.
- `references/appkit-interop.md` — open when wrapping AppKit views/controllers for SwiftUI, or needing `NSApplicationDelegate` callbacks SwiftUI doesn't expose.
