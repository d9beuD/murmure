---
name: swift-macros-metaprogramming
description: >-
  Use when writing or consuming Swift macros and compile-time metaprogramming —
  freestanding #macroName(...) invocations, attached macros (@attached(member/
  peer/accessor/extension/conformance), @AttachedMacro), macro declarations
  (macro foo() = #externalMacro(...)), SwiftSyntax-based macro implementations
  (ExpressionMacro, MemberMacro, MacroExpansionContext), built-in macros like
  @Observable, #Preview, #warning/#error, result builders (@resultBuilder,
  buildBlock, buildOptional, buildEither, buildArray, custom DSLs), or runtime
  introspection with the Swift Reflection module.
---

Helps an agent correctly consume and, when truly needed, author Swift 6.3 macros, result builders, and reflection-based introspection.

## Use this skill when

- Using or debugging a built-in/framework macro: `@Observable`, `#Preview`, `#warning`, `#error`, `@Model` (SwiftData), or similar.
- Writing a freestanding macro call site (`#macroName(...)`) or an attached macro attribute (`@MacroName`) on a type/property/function.
- Declaring a new macro (`macro name(...) = #externalMacro(module:type:)`) or implementing one with SwiftSyntax/SwiftSyntaxMacros.
- Designing or debugging a result-builder-based DSL (`@resultBuilder`, `buildBlock`, `buildOptional`, `buildEither`, `buildArray`), including understanding how `@ViewBuilder`-style code compiles.
- Inspecting a value's structure at runtime via `Mirror` or the Swift 6.2+ `Reflection` module.
- Diagnosing a macro-expansion compiler error or an "ambiguous use of buildBlock" / branch-type error in a result-builder body.

## Do not use this skill when

- Consuming SwiftUI-specific view builders in a SwiftUI app UI layer — that belongs to the macOS/SwiftUI skill set, not this language-level skill.
- Defining ordinary protocols/generics with no macro or builder syntax involved — use swift-types-generics.
- The task is about `async`/`await`, actors, or `Task` — use swift-concurrency.
- The task is about `throws`/`Result`/error propagation — use swift-error-handling.
- The task is basic syntax, structs/enums, or control flow with no macro/builder/reflection involved — use swift-fundamentals.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested feature works.

1. Identify the task type and open EXACTLY ONE reference file from the list below.
2. If the task is "use this framework macro" (e.g. `@Observable`, `#Preview`), apply it directly per `references/macros.md` — do not write a macro implementation for behavior a stdlib/framework macro already provides.
3. If the task requires a genuinely new macro (repeated boilerplate with no existing macro covering it), declare it with `#externalMacro` and implement the minimal conforming protocol (`ExpressionMacro`, `MemberMacro`, etc.) shown in `references/macros.md`.
4. If the task is a DSL / builder-style API (chained statements, conditionals, loops producing a composed value), model it with `@resultBuilder` per `references/result-builders-reflection.md`, implementing only the `buildX` methods the DSL's control flow actually needs.
5. If the task is runtime inspection of a value's fields, use `Mirror` (or `Reflection` on Swift 6.2+) per `references/result-builders-reflection.md`, and prefer it only when static typing cannot express the requirement.
6. Compile/build after each change; if a macro-expansion error appears, re-check the macro's declared role/signature before adding code.
7. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not hand-write a macro implementation when a stdlib/framework macro already does the job.
- Do not implement `buildEither`/`buildArray` unless the DSL body actually contains `if/else` or loops.
- Stop as soon as the requested behavior works.

## Reference files

- `references/macros.md` — open when using, declaring, or implementing freestanding/attached macros, or recognizing built-in macros like `@Observable`, `#Preview`, `#warning`/`#error`.
- `references/result-builders-reflection.md` — open when writing/debugging a `@resultBuilder` DSL or inspecting values at runtime with `Mirror`/`Reflection`.
