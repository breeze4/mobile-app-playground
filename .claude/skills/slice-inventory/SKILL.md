# Skill: slice-inventory

Identify all packages and modules in a project and produce a structured inventory YAML file.

## When to use

Use this skill when you need to catalog all source packages and files in a project before proposing slices or mapping files to slices. This is the first step in the slice planning pipeline.

## Instructions

### 1. Determine project boundaries

- Read `.gitignore` to know which directories to exclude (build artifacts, generated files, IDE config, dependencies)
- Identify the project root (current working directory unless specified)
- Focus on **source files only** — skip build output, caches, generated code, vendored dependencies, and tooling config

### 2. Identify package/module boundaries

Look for these signals to determine where package boundaries are:

- **Android/JVM**: Directories containing source files under a Java/Kotlin package structure (`src/main/java/...`, `src/main/kotlin/...`). Each leaf package (directory with source files) is a package.
- **Gradle/Maven modules**: Directories with their own `build.gradle`, `build.gradle.kts`, or `pom.xml` are module boundaries.
- **General**: Any directory that contains source files and represents a logical grouping. Use build files, directory naming conventions, and file co-location as guides.

For Android projects specifically:
- Each Gradle module (has its own `build.gradle.kts`) is a top-level package
- Within a module, Java/Kotlin package directories that contain source files are sub-packages
- Resource directories (`res/`) are their own package within a module
- The `AndroidManifest.xml` belongs to the module-level package

### 3. Walk the file tree

- Use `find` or equivalent to list all files, excluding `.gitignore` patterns
- Skip hidden directories (`.git`, `.gradle`, `.idea`, etc.)
- Skip binary files, build output, and generated code
- Include: source code, configuration files, manifests, resource files

### 4. Group files under packages

- Assign each file to exactly one package based on its directory location
- Give each package a human-readable `name` derived from its path (e.g., `com.playground.hello` from `app/src/main/java/com/playground/hello/`)
- Write a one-line `description` for each package based on the files it contains (scan file names and, if needed, first few lines)

### 5. Produce output

Write the inventory to `docs/slices/inventory.yaml` in the following format:

```yaml
version: "1"
kind: package-inventory
project_root: "."
generated_at: "<ISO 8601 timestamp>"
packages:
  - path: "relative/path/to/package"
    name: "human-readable-name"
    description: "One-line description"
    files:
      - path: "relative/path/to/file"
summary:
  total_packages: <count>
  total_files: <count>
```

See `docs/schemas/slice-schemas.md` for the full schema reference.

### 6. Validate

After generating the YAML:
- Confirm it parses as valid YAML
- Verify `summary.total_packages` matches the length of `packages`
- Verify `summary.total_files` matches the total count of all files across all packages
- Verify no build artifacts or generated files are included
- Verify every source file under the project is accounted for

## What this skill does NOT do

- No deep code analysis or understanding of file contents beyond basic identification
- No slice assignment — that comes in later skills
- No dependency analysis between packages
