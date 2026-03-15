# Skill: module-triage

Walk an iOS project and produce a structured inventory of all modules with their migration status. Uses parallel subagents to handle large codebases.

## When to use

Use this skill once at the start of a migration project to produce the initial `specs/_triage.yaml`. The user then reviews and classifies each module before scaffolding beads.

## Project layout

The codebase has a clean split:

- **`./Packages/`** — New architecture. Swift packages with SwiftUI + MVVM. Some unit test coverage already exists. These modules are either `done` or `partial`.
- **`./SecuroNet/`** — Legacy. UIKit MVC/Coordinator with significant spaghetti. Business logic tangled into view controllers, delegate chains, storyboard wiring. These modules are `todo` (or `manual` for hardware/AR/animation-dependent stuff).

This directory split means classification doesn't require reading file contents to detect UIKit vs SwiftUI — location tells you. The subagent work is about understanding *what each module does*, finding its counterpart (if any) on the other side, and listing the files accurately.

## Instructions

### Stage 1: Structural scan (coordinator)

Do this yourself, no subagents needed.

1. Read `.gitignore` to exclude build artifacts
2. Read `Package.swift` files in `./Packages/` to understand the new module structure — each package or target is likely one module
3. Use `Glob` and `ls` on `./SecuroNet/` to map legacy directories — identify feature groupings (e.g., `SecuroNet/Auth/`, `SecuroNet/Camera/`)
4. Identify Xcode targets, test targets, UI test target, and scheme from `.xcodeproj/project.pbxproj`
5. Produce a preliminary module list pairing legacy directories to their new-architecture counterparts where they exist

Output: a list of `(legacy_dir, new_package_or_none, test_dir_or_none)` triples.

### Stage 2: Per-module deep scan (parallel subagents)

Launch one subagent per module (or batch 3-5 small modules per subagent).

**For legacy-only modules** (`./SecuroNet/` with no `./Packages/` counterpart):

1. Read all `.swift` files in the legacy directory
2. Identify the module's purpose — what user-facing feature does it provide?
3. List all files with one-line role descriptions
4. Note the severity of spaghetti:
   - How many view controllers? How large are they?
   - Is business logic in view controllers or separated?
   - Are there protocols/managers that could map to ViewModels?
   - Any Objective-C files or bridging headers?
5. Suggest `todo` (or `manual` if it involves AR, complex animations, hardware sensors, or deep UIKit customization that won't have SwiftUI equivalents)
6. Return YAML fragment

**For modules with both legacy and new counterpart:**

1. Read the new package files in `./Packages/`
2. Read the legacy files in `./SecuroNet/`
3. Determine what's been migrated vs what's still missing:
   - Does the new package cover all the behaviors of the legacy code?
   - Is there legacy code still being called from the new package? (look for imports of SecuroNet types)
   - Are there unit tests in the package? How many, what do they cover?
4. Suggest `done` if the package fully replaces the legacy code with tests, `partial` otherwise
5. In notes, be specific: "LoginView and LoginViewModel migrated, but password reset flow still in SecuroNet/Auth/PasswordResetViewController.swift, 3 unit tests cover validation only"
6. Return YAML fragment

**For new-only modules** (`./Packages/` with no legacy counterpart — new features added during rewrite):

1. Read the package files
2. Check test coverage
3. Suggest `done` if tests exist, `partial` if no tests
4. Return YAML fragment

### Stage 3: Assemble (coordinator)

Collect all subagent results and assemble `specs/_triage.yaml`.

- Merge all module entries
- Sort by group, then by name
- Add the `project:` header block
- All statuses set to `unknown` with suggested status in a comment
- Create `specs/` directory if it doesn't exist

### Parallelism guidance

- For projects with <20 modules: launch all subagents at once
- For 20-50 modules: batch 3-5 per subagent
- For 50+ modules: batch 5-10 per subagent
- Each subagent gets the full file list and classification criteria — no re-discovery needed

### Module boundary rules

**New code (`./Packages/`) defines the module boundaries.** Each Swift package (or target within a package) is one module. These boundaries are clean — they were designed intentionally.

**Legacy code (`./SecuroNet/`) does NOT define boundaries.** The legacy code has poor slice boundaries. Expect:
- A single view controller implementing logic for what should be 3 different modules
- "Utility" classes that are half business logic, half framework glue
- A `Helpers/` or `Extensions/` directory with code that belongs to many different modules
- Shared managers that mix concerns (e.g., a `SessionManager` that handles auth tokens AND user preferences AND analytics)
- No 1:1 correspondence between legacy directories and modules

**How to handle this:**
- Define modules based on what the NEW architecture should look like, not how the legacy code is organized
- If a `./Packages/` counterpart exists, that defines the module — find ALL legacy files that contribute to that module's functionality, even if they're scattered across SecuroNet directories
- If no package counterpart exists, define the module by user-facing feature or logical responsibility — a single legacy view controller that does 3 things should be listed under all 3 modules
- A legacy file CAN appear in multiple modules' `legacy_files` lists — that's expected when the legacy code mixes concerns
- When a legacy file contributes to multiple modules, add a note like `"SecuroNet/Shared/SessionManager.swift — auth token portion only"`

### Vertical vs horizontal slices

Every module is either vertical or horizontal. This isn't a formal label in the code — determine it from what the module does:

- **Vertical** — a user-facing feature. Has screens, user interactions, a flow the user can walk through. Examples: login, camera capture, alert rules, settings export. The spec for a vertical focuses on user behavior (given/when/then).
- **Horizontal** — shared infrastructure consumed by multiple verticals. No screens of its own (or very few). Examples: networking layer, auth token management, persistence/Core Data stack, design system components, analytics, push notification handling. The spec for a horizontal focuses on API surface and contracts.

**Why this matters for ordering**: Horizontals must be migrated before the verticals that depend on them. If the networking layer is still in SecuroNet, every vertical that makes API calls depends on it. The scaffold step uses this to set up bead dependencies.

**How to detect**:
- If it lives in a `Core/`, `Common/`, `Shared/`, `Infrastructure/`, or `Services/` directory → likely horizontal
- If it's a Swift package that other packages depend on → horizontal
- If it has view controllers / screens as its primary purpose → vertical
- If multiple unrelated features import it → horizontal

Set `slice: vertical` or `slice: horizontal` in the YAML. When unsure, default to vertical — the user will correct it.

### Output format

Write to `specs/_triage.yaml`:

```yaml
# Module triage for iOS migration
# Review each module and set status: done | partial | todo | manual
# Then run scripts/scaffold.sh to create beads
#
# Legacy code: ./SecuroNet/ (UIKit MVC/Coordinator)
# New code: ./Packages/ (SwiftUI + MVVM, Swift packages)

project:
  name: SecuroNet
  legacy_dir: SecuroNet
  packages_dir: Packages
  legacy_pattern: "UIKit MVC/Coordinator in ./SecuroNet/"
  target_pattern: "SwiftUI + MVVM in ./Packages/"
  test_target: SecuroNetTests
  ui_test_target: SecuroNetUITests
  scheme: SecuroNet

modules:
  # --- Horizontal slices (shared infrastructure, migrate first) ---

  - name: networking
    group: core
    slice: horizontal
    status: unknown  # suggested: done
    legacy_files:
      - SecuroNet/Core/APIClient.swift
      - SecuroNet/Core/RequestBuilder.swift
    source_files:
      - Packages/Networking/Sources/APIClient.swift
      - Packages/Networking/Sources/Endpoint.swift
    test_files:
      - Packages/Networking/Tests/APIClientTests.swift
    notes: "Fully migrated, protocol-based, 8 unit tests"

  - name: auth-token
    group: core
    slice: horizontal
    status: unknown  # suggested: partial
    legacy_files:
      - SecuroNet/Core/TokenManager.swift
      - SecuroNet/Core/KeychainWrapper.swift
    source_files:
      - Packages/Auth/Sources/TokenStore.swift
    test_files: []
    notes: "TokenStore exists but still wraps legacy KeychainWrapper, no tests"

  # --- Vertical slices (user-facing features) ---

  - name: login
    group: auth
    slice: vertical
    status: unknown  # suggested: done
    legacy_files:
      - SecuroNet/Auth/LoginViewController.swift
      - SecuroNet/Auth/LoginCoordinator.swift
    source_files:
      - Packages/Auth/Sources/LoginView.swift
      - Packages/Auth/Sources/LoginViewModel.swift
    test_files:
      - Packages/Auth/Tests/LoginViewModelTests.swift
    notes: "Fully migrated to SwiftUI+MVVM package, 12 unit tests, legacy files unused"

  - name: camera-capture
    group: camera
    slice: vertical
    status: unknown  # suggested: partial
    legacy_files:
      - SecuroNet/Camera/CaptureViewController.swift
      - SecuroNet/Camera/CaptureManager.swift
      - SecuroNet/Camera/PhotoProcessor.swift
    source_files:
      - Packages/Camera/Sources/CaptureView.swift
    test_files: []
    notes: "SwiftUI view exists but still imports SecuroNet.CaptureManager, no tests, PhotoProcessor logic not ported"

  - name: alert-rules
    group: alerts
    slice: vertical
    status: unknown  # suggested: todo
    legacy_files:
      - SecuroNet/Alerts/AlertRulesViewController.swift
      - SecuroNet/Alerts/AlertRuleCell.swift
      - SecuroNet/Alerts/AlertRulesDataSource.swift
      - SecuroNet/Alerts/AlertRuleDetailViewController.swift
    source_files: []
    test_files: []
    notes: "4 UIKit files, ~800 lines total, business logic in data source and detail VC, no package counterpart"

  - name: live-video
    group: camera
    slice: vertical
    status: unknown  # suggested: manual
    legacy_files:
      - SecuroNet/Camera/LiveVideoViewController.swift
      - SecuroNet/Camera/VideoStreamManager.swift
    source_files: []
    test_files: []
    notes: "Real-time video streaming with custom AVCaptureSession pipeline, needs device testing"
```

## What this skill does NOT do

- Does not create beads (scaffold.sh handles that)
- Does not write specs (spec-extract handles that)
- Does not modify any source code
- Does not make final migration decisions — it suggests, the human decides
