# C and Objective-C Interop

## Bridging headers (Swift consuming Objective-C)

A bridging header exposes Objective-C headers to Swift files in the same target; it is not a module and is not imported explicitly. Set `Objective-C Bridging Header` in build settings (or `-import-objc-header path` for SwiftPM/manual builds) to a header that `#import`s the Objective-C APIs you need.

```c
// MyTarget-Bridging-Header.h
#import "LegacyWidget.h"
#import <Foundation/Foundation.h>
```

```swift
// Any Swift file in the target can now use LegacyWidget directly, no import needed.
let widget = LegacyWidget()
widget.spin(withSpeed: 2.0)
```

## Exposing Swift to Objective-C with @objc

Mark a Swift declaration `@objc` to make it visible to the Objective-C runtime and to any Objective-C code that imports the generated `-Swift.h` header. The declaring type must itself be `@objc`-compatible (a class inheriting, directly or indirectly, from `NSObject`, or an `@objc` protocol).

```swift
@objc class Widget: NSObject {
    @objc var speed: Double = 1.0
    @objc(spinWithSpeed:) func spin(withSpeed speed: Double) {
        self.speed = speed
    }
}
```

Use `@objc(name:)` to control the exact selector or class name seen from Objective-C — required whenever the Swift name would be ambiguous or non-idiomatic in Objective-C (e.g., Swift's argument-label-free `init(speed:)` needs `@objc(initWithSpeed:)`).

```swift
@objc(WGWidget)
class Widget: NSObject {
    @objc(initWithSpeed:) init(speed: Double) { self.speed = speed }
}
```

## @objcMembers

`@objcMembers` on a class implicitly applies `@objc` to every member, saving per-declaration annotations; use it for classes that are almost entirely Objective-C-facing (e.g., legacy view controllers), not for mostly-Swift types where it would leak internal API to Objective-C.

```swift
@objcMembers
class LegacyViewController: NSObject {
    var title: String = ""
    func reload() { /* ... */ }
}
```

## NSObject subclassing requirements

Only classes that inherit from `NSObject` (directly or transitively) can be marked `@objc`, participate in key-value observation, or satisfy `@objc` protocols. Pure Swift `struct`s, `enum`s, and non-`NSObject` classes cannot be exposed to Objective-C at all — wrap or bridge them instead.

```swift
class Coordinate: NSObject {   // must inherit NSObject to be @objc-visible
    @objc let x: Double
    @objc let y: Double
    @objc init(x: Double, y: Double) { self.x = x; self.y = y }
}
```

## @objc protocols for delegates

Delegate patterns require `@objc protocol` when the conforming type may be Objective-C, when using optional protocol methods, or when the protocol is checked with `responds(to:)`. Only `@objc` protocols support `@objc optional` requirements.

```swift
@objc protocol WidgetDelegate: AnyObject {
    func widgetDidSpin(_ widget: Widget)
    @objc optional func widget(_ widget: Widget, willSpinAt speed: Double)
}

class Widget: NSObject {
    weak var delegate: WidgetDelegate?
    func spin() {
        delegate?.widget?(self, willSpinAt: speed)
        delegate?.widgetDidSpin(self)
    }
}
```

## Importing C headers and modulemaps

A C library becomes a Swift module via a `module.modulemap` that names the module and lists its umbrella header; SwiftPM targets of type `.target` with a C-family source layout generate this automatically, or you supply one for a system library.

```
// module.modulemap
module CWidget {
    header "widget.h"
    export *
}
```

```swift
import CWidget

var w = widget_create(2.0)   // C function imported directly
```

## C structs, unions, and function pointers in Swift

C structs import as Swift structs with memberwise access; C unions import as Swift structs with computed properties over the same storage (accessing one property invalidates others, matching C semantics); C function pointer typedefs import as Swift closures with `@convention(c)`.

```c
// widget.h
typedef struct { double x, y; } Point;
typedef union { int i; float f; } Number;
typedef void (*Callback)(int status);

void widget_register(Callback cb);
```

```swift
var p = Point(x: 1.0, y: 2.0)
let cb: @convention(c) (Int32) -> Void = { status in print(status) }
widget_register(cb)
```

## Exposing Swift to C with @c (Swift 6.3)

The Swift 6.3 `@c` attribute exposes a Swift function or enum to plain C (not just Objective-C), generating a C-callable symbol and header declaration without requiring `NSObject` or the Objective-C runtime — the right tool when the consumer is a C library, not Objective-C/Cocoa. Use `@c(name)` to give the C-visible symbol a different name than the Swift declaration.

```swift
@c
func computeChecksum(_ data: UnsafePointer<UInt8>, _ length: Int32) -> Int32 {
    // pure Swift implementation
    return 0
}

@c("WidgetStatus")
enum Status: Int32 {
    case ok = 0
    case failed = 1
}
```

```c
// generated header, consumed from plain C
int32_t computeChecksum(const uint8_t *data, int32_t length);
```

Prefer `@c` over hand-written C shims or `@_cdecl` when you need a stable, named C entry point paired with a normal Swift implementation — it keeps the naming and the implementation in one declaration instead of splitting them across files.
