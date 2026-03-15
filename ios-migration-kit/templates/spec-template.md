# Module: {module_name}
Status: {todo | partial | done}
Group: {module_group}

## Source Files
- `path/to/LegacyFile.swift` — {one-line role description}
- `path/to/NewFile.swift` — {one-line role, marked as [migrated]}

## Test Files
- `path/to/Tests.swift` — {what it tests}

## Behavior Specification

Write in plain language. No class names, no UIKit types, no implementation jargon.

### {User Flow Name}
- **Given** {user state — e.g., "user is on the login screen with empty fields"}
- **When** {user action — e.g., "user enters valid email and password, taps Submit"}
- **Then** {visible outcome — e.g., "loading indicator appears, then home screen is shown"}
- **Source**: `LegacyViewController.swift:45-67`

### {Another Flow}
- **Given** {user state}
- **When** {user action}
- **Then** {visible outcome}
- **Source**: `AnotherFile.swift:10-25`

## Business Rules

Describe pure logic, independent of any UI framework.

### Data Model
{Entities, properties, relationships — describe the shape, not the ORM}
Source: `Model.swift:1-50`

### Validation Rules
- {Rule: e.g., "Email must contain @ and a domain"}
- {Rule: e.g., "Password minimum 8 characters, at least one number"}
Source: `ViewController.swift:120-145` (buried in submitTapped action)

### State Machine
States: {e.g., idle, loading, loaded, error, empty}
Transitions:
- idle -> loading: {trigger}
- loading -> loaded: {trigger}
- loading -> error: {trigger}
Source: `ViewController.swift:30-90` (implicit in lifecycle + delegate callbacks)

### Business Logic
{Algorithms, calculations, data transformations}
Source: `ViewController.swift:200-250`

### API Contracts
{Endpoints, request/response shapes, error codes, retry behavior}
Source: `NetworkManager.swift:40-80`

## Misplaced Logic
Logic found here that belongs to a different slice. Do NOT reimplement — consume as a dependency.
- **{What it does}**: {description}. Source: `ViewController.swift:80-95`. **Belongs to**: {slice name} ({horizontal | vertical}). **Implementation note**: {call the networking service / use auth module's token refresh / etc.}

## Tangled Logic
Business rules buried in UIKit plumbing that need extraction:
- **{Rule name}**: {what the rule is} — tangled with {UIKit concern}. Source: `File.swift:100-130`

## Questionable Behaviors
Things that may be bugs, workarounds, or accidents — NOT confirmed requirements.
Human review required before implementing.
- **{Description}**: {what the code does and why it looks wrong}. Source: `File.swift:200-210`. Likely: {bug | workaround | dead code | unclear}

## Migration Gap
{Only for partial modules — list specific behaviors and logic not yet migrated}

## Dependencies
- Depends on: {module names this module imports/uses}
- Required by: {modules that depend on this one}

## Test Coverage Gaps
- {Behaviors documented above that have no existing test coverage}
