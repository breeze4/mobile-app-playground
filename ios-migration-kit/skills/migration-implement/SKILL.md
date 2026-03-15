# Skill: migration-implement

Implement or complete a module in SwiftUI + MVVM using a behavior spec with citations to legacy source code.

## When to use

Use this skill after spec-extract has produced a spec for the module. The spec describes behavior and business rules in architecture-agnostic terms. Your job is to implement them cleanly in the target architecture.

## Project layout

- **`./SecuroNet/`** — Legacy UIKit MVC/Coordinator code. Citations in specs point here. Read these to study algorithms and edge cases, NOT to replicate structure.
- **`./Packages/`** — New SwiftUI + MVVM Swift packages. Your implementation goes here. Study existing packages for patterns before writing anything.

## Critical principle

**You are not porting SecuroNet code to SwiftUI.** You are building a new implementation from a behavioral spec. The spec's `Source:` citations point to SecuroNet legacy code so you can study the *logic* (algorithms, validation rules, edge cases, API contracts) — not to replicate the *structure* (view controllers, coordinators, delegates, storyboard patterns).

When you follow a citation and find business logic tangled inside `viewDidLoad` or a `tableView(_:cellForRowAt:)`, extract the logic and put it where it belongs:
- Validation rules → ViewModel
- State management → ViewModel with `@Published` properties
- Data transformation → ViewModel or dedicated service
- API calls → Service/Repository layer
- Navigation → Coordinator or NavigationStack
- UI → SwiftUI View (thin, declarative, no business logic)

## Instructions

### 1. Read the spec

Read the spec file path from the bead description (e.g., `specs/{group}/{module}.md`). Understand:
- What the user does (Behavior Specification — this is your acceptance criteria)
- What business rules govern the module (Business Rules — this is your logic to implement)
- What is tangled in legacy code (Tangled Logic — this tells you where to look for hidden logic)
- What belongs elsewhere (Misplaced Logic — this tells you what to consume as a dependency, NOT reimplement)
- What is already done vs missing (Migration Gap section, if partial)

### 2. Study reference Packages FIRST

Before reading any SecuroNet code, read the **Reference Packages** listed in CLAUDE.md. These are the project's most architecturally representative packages, chosen by the team. Study:
- Package structure (Sources/, Tests/, Package.swift)
- How Views are structured (SwiftUI patterns, composition)
- How ViewModels expose state (`@Published`, `@Observable`)
- How dependency injection works (environment, init injection)
- How navigation is handled
- How services/repositories are structured
- How packages depend on each other
- How unit tests are written

This is your blueprint. Every file you write must match these patterns. Your implementation goes into `./Packages/{ModuleName}/`.

If CLAUDE.md does not list reference packages, find 2-3 `done` packages in `./Packages/` that have the most files and tests — those are likely the most representative.

### 3. Study SecuroNet logic via citations

Now follow the `Source:` references in the spec. These point into `./SecuroNet/`. Read them to understand:
- The exact validation rules and edge cases
- Algorithm details not fully captured in the spec
- API request/response shapes
- Error handling paths

**Extract the logic, not the pattern.** If the legacy code validates an email with a regex inside a `textFieldDidEndEditing` delegate method, you need the regex and the validation rule — not the delegate pattern.

Pay special attention to the spec's `## Tangled Logic` section. These are the spots where important business rules are buried in UIKit plumbing. Read each citation, extract the rule, and implement it in the appropriate layer.

### 4. Respect slice boundaries (Misplaced Logic)

The spec's `## Misplaced Logic` section lists things the legacy code does inline that belong to a horizontal or different vertical slice. **Do NOT reimplement this logic in your module.** Instead:

- For logic that belongs to a horizontal slice (networking, auth, persistence): import and call the horizontal package. If the horizontal package doesn't exist yet or doesn't expose the needed API, add a `// TODO: depends on {horizontal-slice-name} — using placeholder` comment and implement a minimal protocol/interface that the horizontal can satisfy later.
- For logic that belongs to a different vertical: do not include it at all. It's that module's responsibility.

This is how we prevent the new architecture from inheriting the old architecture's boundary violations. The legacy camera screen had inline networking? Your CameraViewModel calls `NetworkingService.fetch()`, it does not contain a URLSession.

### 5. Implement the module

Target architecture for each file:

| Layer | File Pattern | Responsibility |
|-------|-------------|----------------|
| View | `{Name}View.swift` | SwiftUI view, declarative UI, no business logic |
| ViewModel | `{Name}ViewModel.swift` | State, validation, business logic, async operations |
| Model | `{Name}.swift` | Data structures, Codable, Equatable |
| Service | `{Name}Service.swift` | API calls, persistence, external system interaction |

Rules:
- Views should be thin — they read ViewModel state and send user actions to it
- ViewModels own all mutable state and business logic
- ViewModels are testable without any UI framework
- Services are protocol-based for testability
- Use Swift concurrency (async/await) not completion handlers
- Do NOT modify files outside your package directory (no touching the root Package.swift, Xcode project file, or other packages' code)
- If you need a dependency on another package, add it to YOUR package's Package.swift only

For `todo` modules:
- Write all files from scratch
- Implement every behavior in the spec

For `partial` modules:
- Read the existing new-architecture files first
- Only build what is listed in the Migration Gap section
- Integrate with existing code — don't duplicate or restructure what's already done

### 6. Write unit tests

Write XCTest unit tests for the ViewModel and any service/logic layers:
- Test every validation rule from the spec's Business Rules section
- Test state transitions from the State Machine section
- Test business logic / data transformations
- Test error handling paths
- Do NOT write UI tests (that is the xcuitest-verify step)
- ViewModels should be fully testable by injecting mock services via protocols

Name test files `{ClassName}Tests.swift`. Place in the appropriate test target.

### 7. Verify compilation

Build your package independently first, then the full project:

```bash
# Package-level build (fast, catches your errors)
swift build --package-path Packages/{ModuleName}

# Full project build (optional — only if modifying shared files)
xcodebuild build -scheme {scheme} -destination 'generic/platform=iOS Simulator'
```

If the package-level build fails, fix it. If the full project build fails and you didn't touch shared files, the failure is from another module — note it in the bead comment and proceed. Do not try to fix other modules' code.

### 8. Run unit tests

```bash
# Package-level tests (fast, isolated)
swift test --package-path Packages/{ModuleName}
```

If tests fail, read failures, fix, re-run. Do not move on until tests pass.

### 9. Self-check against spec

Before closing the bead, re-read the Behavior Specification in the spec. For each given/when/then:
- Can you trace it to your implementation?
- Is there a unit test that covers the business logic behind it?
- Would the XCUITest step be able to verify this behavior in the UI?

If any behavior is missing, implement it.

## What this skill does NOT do

- Does not write XCUITest e2e tests (that is xcuitest-verify)
- Does not modify the spec file
- Does not replicate UIKit patterns — builds fresh in SwiftUI+MVVM
- Does not add features beyond what the spec documents
- Does not refactor existing migrated code unless necessary for integration
