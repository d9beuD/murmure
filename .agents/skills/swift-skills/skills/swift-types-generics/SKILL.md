---
name: swift-types-generics
description: >-
  Use when designing or reviewing Swift types and generic code — choosing
  struct vs class vs enum, enums with associated values or raw values,
  CaseIterable, indirect enum, protocols and protocol extensions,
  protocol-oriented programming, Self requirements, protocol composition (&),
  generic functions/types, generic constraints, where clauses, associated
  types, some/any, extending existing types, conditional conformance,
  computed properties, willSet/didSet, or custom @propertyWrapper types.
---

Design and implement Swift 6.3 types, protocols, and generics with correct value/reference semantics and protocol-oriented patterns.

## Use this skill when

- Deciding whether a new type should be a struct, a class, or an enum.
- Modeling state with enums that carry associated values, raw values, or `CaseIterable`/`indirect` cases.
- Writing a protocol, giving it a default implementation via a protocol extension, or composing protocols with `&`.
- Writing generic functions/types, adding generic constraints or `where` clauses, or defining/using associated types.
- Choosing between `some` (opaque type) and `any` (existential) for a return type or property.
- Extending an existing type (including conditional conformance) or writing a custom `@propertyWrapper`.
- Adding computed properties or `willSet`/`didSet` observers to a type.

## Do not use this skill when

- Writing basic syntax, optionals, control flow, or collections — use swift-fundamentals.
- Working with `async`/`await`, actors, `Task`, or `Sendable` conformance — use swift-concurrency.
- Defining or throwing `Error` types, `Result`, or `try`/`catch` flow — use swift-error-handling.
- Managing ownership, `weak`/`unowned`, retain cycles, or `~Copyable` — use swift-memory-safety.
- Writing `@Macro`/`#macro` declarations or compile-time code generation — use swift-macros-metaprogramming.
- Writing unit tests, Swift Testing (`@Test`), or XCTest — use swift-testing-tooling.
- Bridging to C/C++/Objective-C — use swift-interop.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested feature works.

1. Identify the task type and open EXACTLY ONE reference file from the list below.
2. Default to `struct` for value types with no identity; use `class` only when you need reference identity, inheritance, or shared mutable state; use `enum` when the type has a small closed set of cases.
3. If the task involves shared behavior across unrelated types, prefer a protocol with a default implementation (protocol extension) over a base class.
4. If the task involves an unknown/variable number of conforming types at compile time but a single concrete type at each call site, use `some`; use `any` only when you truly need a heterogeneous collection or runtime-boxed value.
5. Add generic constraints (`<T: Protocol>`) or a `where` clause as narrowly as the code actually needs — do not over-generalize.
6. Write the minimal correct code directly in the target file; match existing project style (naming, access control) if visible.
7. Stop here.

Anti-loop rules:
- ONE reference file per task. If unsure which, pick the closest match and proceed.
- Do not regenerate or rewrite code that already works.
- Stop as soon as the requested feature is implemented.

## Reference files

- `references/structs-classes-enums.md` — open when choosing struct vs class vs enum, or working with associated/raw-value enums, `CaseIterable`, `indirect enum`, computed properties, or `willSet`/`didSet`.
- `references/protocols-generics.md` — open when writing protocols, protocol extensions, protocol composition, generic functions/types, constraints, `where` clauses, associated types, or `some`/`any`.
- `references/extensions-property-wrappers.md` — open when extending an existing type, adding conditional conformance, or writing a custom `@propertyWrapper`.
