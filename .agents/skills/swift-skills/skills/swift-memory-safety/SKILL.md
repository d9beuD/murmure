---
name: swift-memory-safety
description: >-
  Use when diagnosing or preventing Swift memory issues — ARC retain cycles,
  strong/weak/unowned references, closure capture lists ([weak self],
  [unowned self]), struct/enum value semantics vs class reference semantics
  and copy-on-write, ownership modifiers (borrowing, consuming, inout,
  exclusivity), noncopyable (~Copyable, ~Escapable) types and their deinit,
  or unsafe pointer/Unmanaged interop.
---

Diagnose and fix ARC retain cycles, choose correct ownership modifiers, and model noncopyable resource types correctly in Swift 6.3.

## Use this skill when

- A class instance, closure, or Combine/async callback appears to leak (deinit never runs, memory grows).
- Deciding whether a closure capture needs `[weak self]`, `[unowned self]`, or no capture list at all.
- Choosing `struct`/`enum` (value semantics, copy-on-write) vs `class` (reference semantics, shared mutable state) for a specific type.
- Adding `borrowing`, `consuming`, or `inout` to a function signature, or hitting an exclusivity-violation ("simultaneous access") diagnostic.
- Modeling a unique, non-duplicable resource (file handle, lock, hardware handle) with `~Copyable`/`~Escapable` and giving it a `deinit`.
- Reviewing/writing code that touches `UnsafePointer`, `UnsafeMutablePointer`, or `Unmanaged` for C/Objective-C interop.

## Do not use this skill when

- Fixing Sendable/data-race concurrency diagnostics — use swift-concurrency.
- Choosing between struct/class purely for API design (protocols, generics) — use swift-types-generics; come back here only for the ownership/retention consequences of that choice.
- Debugging a crash from force-unwrapping an Optional or general error propagation — use swift-error-handling.
- Writing plain algorithmic/control-flow Swift with no ownership, ARC, or lifetime question involved — use swift-fundamentals.
- The issue is a C/C++/Objective-C bridging header or module-map problem rather than a pointer-lifetime problem — use swift-interop.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested feature works.

1. Identify the task type and open EXACTLY ONE reference file from the list below.
2. If diagnosing a leak: find the strong-reference cycle first (class ↔ class, or closure stored on `self` capturing `self` strongly). Prefer `[weak self]` for escaping closures stored as a property or handler that outlives the call; use `[unowned self]` only when `self` is guaranteed to outlive the closure (e.g. `self` owns the closure's only caller and never escapes past `self`'s lifetime).
3. If designing a type: default to `struct`/`enum` for data with no required identity or sharing; use `class` only when identity/sharing/mutation-in-place across owners is the actual requirement.
4. If touching function parameter ownership: use plain (implicit `borrowing`) parameters by default; add `consuming` only when the function must take ownership (e.g. store it, forward it into another consuming API); add `inout` only when the function must mutate the caller's variable in place; reach for `~Copyable` only when a real uniqueness/resource-ownership invariant (must not be duplicated) needs enforcing at compile time.
5. If an exclusivity ("simultaneous access") diagnostic appears, find the overlapping read/write of the same `inout`/mutating-method access and restructure so accesses don't overlap — do not silence it with `withoutActuallyEscaping` or similar tricks.
6. Only touch `UnsafePointer`/`UnsafeMutablePointer`/`Unmanaged` when a C/Objective-C API literally requires it; otherwise remove it in favor of safe Swift.
7. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not add `[weak self]` reflexively everywhere — only where a genuine retain cycle exists (see the reference file's decision guidance).
- Stop as soon as the retain cycle is broken / the ownership requirement is satisfied. Do not keep refactoring correct code.

## Reference files

- `references/arc-closures-capture.md` — open when working with class references, retain cycles, closure capture lists, or struct/class semantics choices.
- `references/ownership-noncopyable.md` — open when working with `borrowing`/`consuming`/`inout`, exclusivity errors, `~Copyable`/`~Escapable` types, or `UnsafePointer`/`Unmanaged` interop.
