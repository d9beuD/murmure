---
name: swift-interop
description: >-
  Use when crossing a language boundary from Swift — Objective-C interop
  (@objc, @objc(name:), @objcMembers, bridging headers, NSObject subclassing,
  @objc delegate protocols), C interop (importing headers/modulemaps, C
  structs/unions/function pointers, the Swift 6.3 @c attribute for exposing
  Swift to C), C++ interop via modulemap, module name selectors (Module::name
  disambiguation, new in 6.3), Embedded Swift for constrained targets, or the
  Swift SDK for Android cross-compilation.
---

Build and debug correct, minimal-surface interop between Swift 6.3 and C, Objective-C, or C++, or target Embedded Swift / Android.

## Use this skill when

- Exposing Swift APIs to Objective-C (`@objc`, `@objcMembers`, `NSObject` subclasses) or consuming Objective-C/Cocoa APIs from Swift.
- Importing a C header, modulemap, or C++ header into a Swift target, or calling a C function/struct/union/function-pointer from Swift.
- Exposing a Swift function or enum to C using the Swift 6.3 `@c` attribute, including custom C-visible naming.
- Resolving a name collision between two imported modules with a `ModuleName::identifier` selector.
- Deciding whether a target should use Embedded Swift (no runtime, no ObjC metadata) or building/cross-compiling for Android with `swift build --swift-sdk`.
- Setting up or debugging a bridging header for a mixed Objective-C/Swift target.

## Do not use this skill when

- Writing pure Swift-only code with no C/C++/Objective-C boundary — use the relevant other swift-* skill (swift-fundamentals, swift-types-generics, swift-concurrency, swift-error-handling, swift-memory-safety, swift-macros-metaprogramming, swift-testing-tooling).
- Building AppKit/SwiftUI interop for macOS UI specifically — that belongs to the macOS UI skill set, not this interop skill, even though it technically touches Objective-C frameworks.
- Writing Swift macros or metaprogramming — use swift-macros-metaprogramming.
- Debugging concurrency/data-race issues across the boundary that aren't about the boundary itself — use swift-concurrency.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested feature works.

1. Identify the task type and open EXACTLY ONE reference file from the list below.
2. Identify which language boundary is being crossed (Swift→ObjC, ObjC→Swift, Swift↔C, Swift↔C++, or a build-target concern like Embedded/Android) before writing any interop code.
3. Expose or import only the minimal surface needed — one function, one type, one protocol — not a whole header or module.
4. For Swift-to-C/ObjC exposure, prefer the supported attribute (`@objc`, `@objc(name:)`, `@c`) over manual shims, `unsafeBitCast`, or raw pointer tricks.
5. For name collisions between imported modules, use a `ModuleName::identifier` selector instead of renaming or re-exporting.
6. Build/compile after each change; fix the first error before making further edits.
7. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not add unsafe pointer workarounds when a supported interop attribute (`@objc`, `@c`) already solves the problem.
- Stop as soon as the boundary compiles and the call works both directions as required.

## Reference files

- `references/c-objc-interop.md` — open when the task involves Objective-C (`@objc`, bridging headers, `NSObject`, delegate protocols) or C (headers, modulemaps, structs, function pointers, the `@c` attribute) interop.
- `references/cpp-embedded-android.md` — open when the task involves C++ interop, module name selectors (`::`), Embedded Swift, or the Swift SDK for Android.
