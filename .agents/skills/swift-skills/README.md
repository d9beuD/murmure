# Swift Skills

A set of [Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills) for the **Swift 6.3** language, built from the official Swift documentation. They give AI coding agents accurate, version-correct guidance for writing Swift.

These skills are designed for **autonomous agents running small / local models** (limited context, low temperature, loop-prone). Each `SKILL.md` is a short, deterministic router: it points the agent to exactly one reference file per task, uses numbered imperative steps, and includes explicit anti-loop and stop criteria. Detailed code examples live in `references/*.md` and are loaded only when needed (progressive disclosure).

## Skills

| Skill | Scope |
|-------|-------|
| `swift-fundamentals` | Syntax, constants/variables, type inference, optionals, control flow & pattern matching, collections (Array/Dictionary/Set), strings, tuples |
| `swift-types-generics` | Structs vs classes vs enums, protocols & protocol-oriented programming, generics & `where` clauses, `some`/`any`, extensions, custom property wrappers |
| `swift-concurrency` | async/await, structured concurrency (`async let`, `TaskGroup`), actors, `@MainActor`, `Sendable`/`sending`, Swift 6 strict concurrency, `AsyncSequence`, checked continuations |
| `swift-error-handling` | `do`/`try`/`catch`, typed throws, custom `Error` types, `Result`, `defer`, `rethrows`, error propagation |
| `swift-memory-safety` | ARC, retain cycles, closure capture lists (`weak`/`unowned`), value vs reference semantics, `borrowing`/`consuming`, noncopyable types (`~Copyable`) |
| `swift-macros-metaprogramming` | Freestanding & attached macros, writing a macro with SwiftSyntax, result builders (`@resultBuilder`), reflection |
| `swift-testing-tooling` | Swift Testing (`@Test`, `#expect`), Swift Package Manager & the Swift Build preview engine, DocC documentation comments |
| `swift-interop` | Objective-C interop (`@objc`, bridging headers), C interop (`@c` attribute), C++ interop, module name selectors (`::`), Embedded Swift, Swift SDK for Android |

## Layout

```
skills/
└── swift-<name>/
    ├── SKILL.md            # short router: when to use, numbered steps, anti-loop rules
    └── references/         # detailed, code-rich docs loaded on demand
        └── *.md
```

## Installation

Copy the skills you want into your agent's skills directory. For example:

```bash
# Claude Code / agents using a .claude/skills directory
cp -R skills/swift-* /path/to/your/project/.claude/skills/

# or an .agents/skills directory
cp -R skills/swift-* /path/to/your/project/.agents/skills/
```

Each skill is self-contained — install only the ones you need.

## Versioning

Content targets **Swift 6.3** (released March 24, 2026, currently at patch 6.3.3), with Swift 6 language mode (strict concurrency checking) as the default. Update this pack when a new Swift release changes syntax, defaults, or removes previewed features.

## Contributing

Issues and pull requests are welcome — corrections, new references, or additional skills. Keep `SKILL.md` files short and router-style; put detail in `references/`.

## License

[MIT](LICENSE) © 2026 Vincent Bathelier.

Skill content is derived from the official [Swift documentation](https://www.swift.org/documentation/) and [Swift evolution proposals](https://github.com/swiftlang/swift-evolution). "Swift" is a trademark of Apple Inc.; this is an independent, unofficial project.
