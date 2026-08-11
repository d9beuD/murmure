---
name: swift-fundamentals
description: >-
  Use when writing or fixing basic Swift syntax — let/var declarations, type
  inference, Int/Double/Bool/String basics, optionals (Optional<T>, nil, ?/!,
  if let, guard let, shorthand if let x, nil-coalescing ??, optional
  chaining), control flow (if, switch pattern matching, for-in, while,
  repeat-while), collections (Array, Dictionary, Set), string interpolation
  and multiline strings, or tuples.
---

Write correct, idiomatic Swift 6.3 for core language syntax: variables, optionals, control flow, collections, and strings.

## Use this skill when

- Declaring constants/variables and reasoning about type inference.
- Unwrapping or propagating optionals (`if let`, `guard let`, `??`, optional chaining, force unwrap).
- Writing `switch` statements with tuple, range, `where`, or binding patterns.
- Iterating or transforming `Array`, `Dictionary`, or `Set`.
- Building strings via interpolation, multiline literals, or common `String` APIs.
- Working with tuples (creation, destructuring, labeled elements).

## Do not use this skill when

- Defining structs, enums, classes, protocols, or generics — use swift-types-generics.
- Writing `async`/`await`, actors, or Task-based concurrency — use swift-concurrency.
- Throwing, catching, or designing `Error` types and `Result` — use swift-error-handling.
- Reasoning about ownership, `inout`, closures capturing memory, or `Unmanaged`/unsafe pointers — use swift-memory-safety.
- Writing or expanding macros, or reflection-heavy metaprogramming — use swift-macros-metaprogramming.
- Writing XCTest/Swift Testing test cases or configuring build tooling — use swift-testing-tooling.
- Bridging to C/Objective-C/other languages — use swift-interop.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested feature works.

1. Identify the task type and open EXACTLY ONE reference file from the list below. Do not open more than one unless the task spans areas.
2. Match the task to the narrowest applicable Swift construct (e.g. prefer `guard let` for early-exit unwrapping over nested `if let`; prefer `switch` over chained `if/else` for multi-case matching).
3. Write the smallest correct snippet that satisfies the request, using Swift 6 language mode conventions (explicit `let` over `var` unless mutation is required, `Any`/force-unwrap avoided unless unavoidable).
4. Check that optionals are unwrapped safely (no unnecessary `!`) and that `switch` statements are exhaustive.
5. Stop here.

Anti-loop rules:
- ONE reference file per task. If unsure which, pick the closest match and proceed.
- Do not regenerate or rewrite code that already works.
- Stop as soon as the requested feature is implemented. Do not add unrequested behavior.

## Reference files

- `references/basic-types-optionals.md` — open when declaring variables/constants, working with Int/Double/Bool/String basics, or handling optionals (`if let`, `guard let`, `??`, chaining, force unwrap).
- `references/control-flow-pattern-matching.md` — open when writing `if`/`switch`/`for-in`/`while`/`repeat-while`, or building tuple/range/`where` pattern matches.
- `references/collections-strings.md` — open when creating or iterating `Array`/`Dictionary`/`Set`, or building strings via interpolation, multiline literals, or `String` APIs.
