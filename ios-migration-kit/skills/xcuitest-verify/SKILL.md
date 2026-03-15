# Skill: xcuitest-verify

Write and run XCUITest e2e tests for a module based on its behavioral spec.

## When to use

Use this skill after migration-implement has completed the module. This skill reads the behavioral specification, writes XCUITest classes, runs them, and debugs failures.

## Instructions

### 0. Reset simulator state

Before running any tests, reset the simulator to a clean state:
```bash
xcrun simctl shutdown all
xcrun simctl erase all
xcrun simctl boot "{simulator_name}"
```
This prevents state pollution from previous test runs.

### 1. Read the spec

Read the spec file from the bead description (e.g., `specs/{group}/{module}.md`). Focus on the **Behavior Specification** section — each given/when/then block becomes a test case.

### 2. Design test cases

From the behavioral spec, produce an ordered list of test cases:
1. Happy paths first
2. Edge cases second
3. Error states last

Each test case needs:
- A descriptive method name: `test_{flowName}_{scenario}` (e.g., `test_login_validCredentials`)
- Setup steps (the "given")
- Action steps (the "when")
- Assertion steps (the "then")

### 3. Write XCUITest classes

Create test files at `{UITestTarget}/{ModuleGroup}/{ModuleName}Tests.swift`.

Follow these XCUITest patterns:

```swift
import XCTest

final class {ModuleName}Tests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func test_{flowName}_{scenario}() throws {
        // Given - navigate to the right state
        // ...

        // When - perform the action
        app.buttons["Submit"].tap()

        // Then - verify the result
        XCTAssertTrue(app.staticTexts["Success"].waitForExistence(timeout: 5))
    }
}
```

Key XCUITest APIs to use:
- `app.buttons["label"]`, `app.textFields["placeholder"]`, `app.staticTexts["text"]`
- `.tap()`, `.typeText("...")`, `.swipeUp()`, `.swipeDown()`
- `.waitForExistence(timeout:)` for async UI updates
- `XCTAssertTrue(element.exists)`, `XCTAssertEqual(element.label, "expected")`
- `app.navigationBars["Title"]` for navigation verification
- `app.alerts.buttons["OK"].tap()` for alert handling

Accessibility identifiers: Prefer `app.buttons["accessibilityIdentifier"]` over label matching when the implementation uses `accessibilityIdentifier`. Check the source via spec citations.

### 4. Run the tests

```bash
xcodebuild test \
  -scheme {UITestScheme} \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:{UITestTarget}/{ModuleName}Tests \
  2>&1
```

### 5. Handle failures

On test failure:
1. Read the `xcodebuild` output to understand what failed
2. Classify each failure before retrying:
   - **Retryable**: "element not found within timeout", simulator crash, app launch failure — increase waits or reset simulator and retry
   - **Real failure**: assertion failed with wrong value, wrong screen shown, business logic error — fix the test if it's a test bug, note it in results if it's an app bug
   - **Infrastructure**: Xcode build failure, code signing error, disk space — do NOT retry, fail the bead with a clear note
3. Fix the test (not the app) and retry for retryable and real failures
4. Maximum 3 retries for retryable failures. Do not count infrastructure failures as retries.

### 6. Capture screenshots

Add screenshot capture at key assertion points:

```swift
let screenshot = XCUIScreen.main.screenshot()
let attachment = XCTAttachment(screenshot: screenshot)
attachment.name = "{module}_{scenario}"
attachment.lifetime = .keepAlways
add(attachment)
```

### 7. Produce results

Write results to `e2e/output/{module_name}/results.yaml`:

```yaml
module: {module_name}
timestamp: {ISO 8601}
test_count: {total}
passed: {count}
failed: {count}
skipped: {count}
tests:
  - name: test_{flowName}_{scenario}
    status: passed | failed | skipped
    duration_ms: {number}
    failure_reason: {only if failed}
  - name: ...
retries: {0, 1, or 2}
notes: {any observations about flaky tests, missing accessibility IDs, etc.}
```

Create the output directory if it doesn't exist.

## What this skill does NOT do

- Does not modify application source code — if a test reveals a bug, note it in results
- Does not write unit tests (migration-implement handles those)
- Does not modify the spec file
- Does not test functionality marked as `manual` in triage
