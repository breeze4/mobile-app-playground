# E2E Tests (Maestro)

End-to-end test flows using [Maestro](https://maestro.mobile.dev/).

## Directory structure

```
e2e/
  flows/
    {slice-name}/
      flow-NNN-{test-name}.yaml
  config/
    env.old.yaml    # Environment for existing app (com.playground.hello)
    env.new.yaml    # Environment for new app (com.playground.hello.new)
  output/           # Screenshots, videos, and test artifacts (gitignored)
```

## Prerequisites

Maestro CLI must be installed. It is NOT installed automatically by this repo.

Install steps:
```bash
# macOS / Linux
curl -Ls "https://get.maestro.mobile.dev" | bash

# Verify
maestro --version
```

An Android emulator (or physical device) must be running and accessible via ADB.

## Running flows

Run a single flow:
```bash
maestro test -e APP_ID=com.playground.hello e2e/flows/hello-ui/flow-001-app-launches.yaml
```

Run all flows for a slice:
```bash
maestro test -e APP_ID=com.playground.hello e2e/flows/hello-ui/
```

Use an environment file:
```bash
maestro test --env e2e/config/env.old.yaml e2e/flows/hello-ui/
```

## Writing flows

Each flow file follows this pattern:

```yaml
appId: ${APP_ID}
---
# {slice-name}: {test-name}
# Given: <precondition>
# When: <action>
# Then: <expected result>
- launchApp
- assertVisible: "Expected Text"
- takeScreenshot: "{slice-name}-{test-name}-final"
```

Naming convention: `flow-NNN-{descriptive-name}.yaml` where NNN is a zero-padded sequence number.

See the Maestro docs for the full command reference: https://maestro.mobile.dev/reference/commands

## Note

No Android emulator is available in the current development environment. All structure and scripts are created but verification requires a running emulator with the app installed.
