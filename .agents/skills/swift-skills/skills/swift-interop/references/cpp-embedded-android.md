# C++ Interop, Module Name Selectors, Embedded Swift, and Android

## Importing C++ via a modulemap

C++ interop is opt-in per target: declare a modulemap for the C++ headers and enable the C++ interoperability mode on the Swift target so imported declarations get C++-aware translation (templates, namespaces, references) instead of being treated as plain C.

```
// module.modulemap
module CppWidget {
    header "Widget.hpp"
    requires cplusplus
    export *
}
```

```swift
// Package.swift target settings
.target(
    name: "MySwiftTarget",
    swiftSettings: [.interoperabilityMode(.Cxx)]
)
```

## Calling C++ member functions

Imported C++ classes appear as Swift structs or classes with their public member functions callable directly; constructors map to `init`, and simple value types (no user-defined destructor complexity) are usable by value.

```cpp
// Widget.hpp
class Widget {
public:
    Widget(double speed) : speed_(speed) {}
    double spin() const { return speed_ * 2.0; }
private:
    double speed_;
};
```

```swift
import CppWidget

var w = Widget(2.0)
let result = w.spin()
```

## Known limitations

C++ templates only import when instantiated in headers the modulemap exposes (no arbitrary generic instantiation from Swift); overloaded operators, multiple inheritance, and complex template metaprogramming may not import cleanly or at all. Prefer wrapping tricky C++ APIs in a small C++ shim with simple, concrete (non-template) signatures rather than fighting an unsupported import — treat that as the minimal surface to expose.

```cpp
// shim.hpp — concrete wrapper around a template-heavy API
inline double widget_spin(const Widget& w) { return w.spin(); }
```

## Module name selectors (Module::identifier, Swift 6.3)

When two imported modules declare identically-named types or functions, Swift 6.3 lets you disambiguate at the use site with `ModuleName::identifier` instead of renaming imports or fully qualifying via workarounds.

```swift
import CWidget
import CppWidget

// Both modules declare `Status` — disambiguate with the module selector.
let a: CWidget::Status = .ok
let b: CppWidget::Status = .failed
```

Use this only where a genuine collision exists; do not sprinkle `Module::` selectors on unambiguous names — it adds noise without disambiguating anything.

## Embedded Swift overview

Embedded Swift is a compilation mode producing small, dependency-free binaries for constrained targets (microcontrollers, WebAssembly, kernel/bootloader code) by omitting the Swift runtime, ObjC metadata, and reflection; it supports a subset of the language (no `Any`, no full runtime-based existentials, restricted dynamic casting) and Swift 6.3 improved its C interop and debugging support.

```bash
swiftc -enable-experimental-feature Embedded -wmo main.swift -o firmware.o
```

```swift
// Embedded-compatible code avoids features requiring the runtime:
struct Sensor {
    var reading: Float
    func isHot() -> Bool { reading > 80.0 }   // no reflection, no Any, fine
}
```

Reach for Embedded Swift only when the target genuinely lacks a runtime environment (bare-metal, size-constrained); do not enable it for ordinary app or server targets where the full runtime is available and expected.

## Swift SDK for Android

Swift 6.3 ships the first official Swift SDK for Android, installed via the Swift toolchain's SDK manager and selected at build time with `swift build --swift-sdk`, enabling cross-compilation from macOS or Linux without a full Android NDK Swift build.

```bash
swift sdk install swift-6.3-RELEASE-android-0.1.artifactbundle.tar.gz
swift build --swift-sdk aarch64-unknown-linux-android24
```

List installed SDKs to confirm the exact identifier string before building, since it must match the installed artifact bundle's target triple exactly.

```bash
swift sdk list
```
