# Skill: spec-extract

Extract a module's behavior and business logic into an architecture-agnostic specification. The spec describes *what the module does* without prescribing *how it should be built*.

## When to use

Use this skill to compress a legacy module into a clean behavioral contract that can guide reimplementation in a modern architecture. The spec must be useful to an agent that has never seen UIKit and is building from scratch in SwiftUI+MVVM.

## Project layout

- **`./SecuroNet/`** — Legacy UIKit MVC/Coordinator code. Significant spaghetti. Business logic tangled into view controllers, delegate chains, storyboard/xib wiring. This is what you're extracting behavior FROM.
- **`./Packages/`** — New SwiftUI + MVVM Swift packages. Already-migrated modules live here. For `partial` modules, some code is here and some logic still lives in SecuroNet.

## Critical principle

**Separate behavior from implementation.** The SecuroNet code is spaghetti — business logic tangled with UIKit lifecycle, navigation mixed into view controllers and coordinators, state scattered across delegates. Your job is to untangle this and produce a spec that describes:

1. What the user sees and does (behavior)
2. What business rules govern the module (logic)
3. What data flows in and out (contracts)

Do NOT describe UIKit patterns, view controller lifecycle, delegate chains, storyboard connections, or any other implementation coupling. These are implementation details of the *old* architecture and must not leak into the spec.

Citations point to *where the logic lives* in legacy code so the implementing agent can study the algorithms and edge cases — not so it can copy the structure.

## Extraction order

Do NOT try to spec a massive view controller top-down in one pass. That produces either useless generalization or an encyclopedia of implementation details. Work bottom-up through the code in this order:

1. **Pure functions and data transformations** — easiest to spec, clear inputs/outputs, least tangled
2. **Delegate/protocol implementations** — the protocol defines the contract, read what the implementation actually does within that contract
3. **Navigation triggers** — what causes transitions to other screens, what data is passed, what conditions guard each transition
4. **Business rules** — the conditions that govern when actions are allowed, what validation runs, what state changes occur
5. **Lifecycle glue** (`viewDidLoad`, `viewWillAppear`, `viewDidDisappear`) — last, and most of this is accidental complexity that should NOT be specced. Only extract initialization logic that represents a real business requirement (e.g., "load user profile on screen entry"), not UIKit wiring.

This ordering builds understanding from concrete to abstract. By the time you reach lifecycle methods, you already know what the real business logic is and can distinguish it from plumbing.

## Accidental vs intentional behavior

Legacy spaghetti code contains bugs, workarounds, and accidents alongside real product behavior. You cannot always tell them apart. **Do not silently spec accidents as requirements.**

When you encounter something that looks wrong, inconsistent, or suspicious:
- A network error that is silently swallowed (no user feedback)
- A validation rule that contradicts another one
- A loading state that never resolves on timeout
- Dead code paths that can't be reached
- Hardcoded values that look like they should be configurable
- Retry logic that retries forever
- Empty catch blocks

Put these in `## Questionable Behaviors` with your best guess at what's happening and a source citation. The human reviewer decides whether to keep, drop, or fix each one during the checkpoint. **Never spec something you're unsure about as a definite requirement.**

## Instructions

### 1. Parse the bead description

Extract from the bead description:
- `module_name` — the module being analyzed
- `module_group` — the directory group (e.g., auth, camera)
- `module_status` — todo, partial, or done
- `legacy_files` — comma-separated list of legacy source files
- `source_files` — comma-separated list of already-migrated files (may be empty)
- `test_files` — comma-separated list of existing test files (may be empty)

### 2. Read all files

- Read every file listed in legacy_files, source_files, and test_files
- Use subagents to read files in parallel when there are more than 3 files
- As you read, mentally separate: what is *behavior* (user-facing) vs *plumbing* (UIKit wiring, delegate glue, storyboard setup)

**Important: legacy files have poor boundaries.** A legacy file may appear in multiple modules' file lists because the SecuroNet code mixes concerns. When reading a legacy file:
- Only extract behavior and logic relevant to THIS module into the main spec sections
- If the file note says something like "auth token portion only", focus on that portion
- A 500-line view controller might only have 50 lines relevant to your module — cite those specific lines, not the whole file
- **Do NOT ignore code that belongs to other slices** — instead, log it in `## Misplaced Logic` (see step 5). This is how we catch logic that the legacy code put in the wrong place.

### 3. Extract behavior specification

The approach differs by slice type:

**Vertical slices** (user-facing features): Describe what the user experiences. Each flow should read like a product requirement, not a code walkthrough. Use given/when/then blocks.

**Horizontal slices** (shared infrastructure): There may be no user-visible behavior. Instead, document the **API surface** — what do consumers call, what do they get back, what errors can occur? Write contract-style specs: "When a consumer calls `fetchUser(id:)`, it returns a `User` or throws `NetworkError.notFound`." Still use given/when/then but from the perspective of the calling code, not the end user.

For each behavior or contract:
- Write a given/when/then block using **plain language** — no class names, no UIKit types, no implementation jargon
- The "given" is a user state, not a code state (e.g., "user is on the login screen" not "LoginViewController is presented")
- The "when" is a user action (e.g., "user taps Submit" not "submitButton.sendActions(.touchUpInside)")
- The "then" is a visible outcome (e.g., "error message appears below the password field" not "errorLabel.isHidden = false")
- Add `Source:` with `filename.swift:startLine-endLine` pointing to where this behavior is implemented — these are breadcrumbs for the implementing agent to study the *logic*, not the *structure*

Order: happy paths first, then edge cases, then error states.

Cross-reference: note which test files cover which behaviors. Identify gaps.

### 4. Extract business rules

Document the pure logic that exists independent of any UI framework. Pull these OUT of the view controller code and describe them cleanly:

- **Data Model**: What entities exist, their properties, relationships, how they're persisted. Describe the shape, not the NSManagedObject subclass.
- **Validation Rules**: What inputs are valid/invalid, what constraints are enforced, what error messages result. List each rule explicitly.
- **State Machine**: What states can the module be in, what transitions are allowed, what triggers them. If there's no explicit state machine but the view controller has implicit states (loading, error, empty, loaded), name them.
- **Business Logic**: Algorithms, calculations, transformations. Describe what the function *computes*, not how UIKit calls it.
- **API Contracts**: What network calls are made, request/response shapes, error handling. Describe the contract, not the URLSession implementation.

Each section gets `Source:` citations pointing to where the logic lives in legacy code.

### 5. Sort misplaced logic

Legacy code puts logic in the wrong place. A view controller for the camera screen might contain inline networking code, persistence logic, or auth token refresh — none of which belongs to the camera-capture vertical slice.

As you read, classify every piece of logic you find:

**Belongs here** — it's specific to this module's feature. Spec it normally in Behavior Specification and Business Rules.

**Belongs to a horizontal slice** — it's infrastructure that should be shared. Common examples:
- Networking/API calls embedded directly in a view controller instead of going through a service
- Auth token checks or refresh logic inlined before API calls
- Core Data / persistence operations done inside a view controller
- Analytics tracking calls scattered through UI code
- Error handling patterns that should be centralized
- Keychain access done inline

**Belongs to a different vertical** — the legacy code does something for another feature in this file. Example: a settings screen that also handles logout (which belongs to the auth module).

Log everything that doesn't belong here in `## Misplaced Logic`. For each item:
- What the logic does (architecture-free description)
- Where it is (`Source:` citation)
- Where it SHOULD live (which horizontal or vertical slice)
- Whether the implementing agent should call a dependency instead of reimplementing it

This section serves two purposes:
1. It tells the implementing agent "do NOT put this in your ViewModel — call the networking/auth/persistence horizontal instead"
2. It feeds back into the triage — if many verticals flag the same misplaced logic, that's a horizontal slice that may be missing from the triage

### 6. Identify what is tangled

SecuroNet's MVC/Coordinator code has business logic buried inside:
- `viewDidLoad` / `viewWillAppear` — initialization logic that should be in a ViewModel
- `tableView(_:cellForRowAt:)` / `collectionView(_:cellForItemAt:)` — data transformation logic mixed with cell configuration
- `@IBAction` methods — validation + state changes + navigation all in one method
- Coordinator methods — business decisions mixed into navigation flow
- Delegate callbacks — business logic responding to framework events
- `prepare(for segue:)` — data passing logic coupled to storyboard transitions

Call these out in a `## Tangled Logic` section. For each, describe:
- What the business rule actually is (architecture-free)
- Where it's buried (`Source:` citation)
- What it's tangled with (e.g., "validation logic mixed into the submit button action alongside navigation and error presentation")

This section is critical — it tells the implementing agent where to look for logic that needs to be extracted into a ViewModel or service.

### 7. Handle partial modules

If `module_status` is `partial`:
- Read the already-migrated files (source_files)
- Note what is already properly separated in the new architecture
- In `## Migration Gap`, list only the behaviors and logic that are NOT yet migrated
- Be specific: "login validation rules are migrated, but password reset flow is still in legacy"

If `module_status` is `done`:
- Still produce the full spec (it serves as reference for other modules)
- Note that implementation is complete

### 8. Document dependencies

List:
- Other modules this module depends on (shared models, services, navigation targets)
- Modules that depend on this one
- External frameworks used (beyond UIKit/Foundation)

### 9. Write output

Write the spec to `specs/{module_group}/{module_name}.md`. Create the directory if it doesn't exist.

## Output format

```markdown
# Module: {module_name}
Status: {todo | partial | done}
Group: {module_group}

## Source Files
- `path/to/LegacyFile.swift` — {one-line role description}
- `path/to/NewFile.swift` — {one-line role, marked as [migrated]}

## Test Files
- `path/to/Tests.swift` — {what it tests}

## Behavior Specification

### {User Flow Name}
- **Given** {user state in plain language}
- **When** {user action in plain language}
- **Then** {visible outcome in plain language}
- **Source**: `LegacyViewController.swift:45-67`, `Tests.swift:12-30`

## Business Rules

### Data Model
{Architecture-free description of entities and relationships}
Source: `Model.swift:1-50`

### Validation Rules
- {Rule 1: e.g., "Email must contain @ and a domain"}
- {Rule 2: e.g., "Password minimum 8 characters, at least one number"}
Source: `ViewController.swift:120-145` (buried in submitTapped action)

### State Machine
States: {list states}
Transitions: {state -> state on trigger}
Source: `ViewController.swift:30-90` (implicit in viewDidLoad + delegate callbacks)

### Business Logic
{Algorithms, calculations, transformations}
Source: `ViewController.swift:200-250`

### API Contracts
{Request/response shapes, endpoints, error codes}
Source: `NetworkManager.swift:40-80`

## Misplaced Logic
Logic found in this module's legacy files that belongs elsewhere. Do NOT reimplement — consume as a dependency.
- **{What it does}**: {description}. Source: `ViewController.swift:80-95`. **Belongs to**: {slice name} ({horizontal | vertical}). **Implementation note**: {call the networking service instead of inlining URLSession / use the auth module's token refresh / etc.}

## Tangled Logic
- **{Business rule}**: {what it is} — tangled with {what UIKit concern}. Source: `File.swift:100-130`

## Questionable Behaviors
Behaviors that may be bugs, workarounds, or accidents — NOT confirmed requirements.
Human review required before implementing these.
- **{Description}**: {what the code does and why it looks wrong}. Source: `File.swift:200-210`. Likely: {bug | workaround | dead code | unclear}

## Migration Gap
{Only for partial modules — specific behaviors/logic not yet migrated}

## Dependencies
- Depends on: {module names}
- Required by: {module names}

## Test Coverage Gaps
- {Behaviors with no existing test coverage}
```

## What this skill does NOT do

- Does not write implementation code
- Does not write tests
- Does not modify any source files
- Does not prescribe architecture — it extracts behavior and logic, architecture-free
- Does not describe UIKit patterns, delegate chains, storyboard flows, or view controller lifecycle as if they should be replicated
