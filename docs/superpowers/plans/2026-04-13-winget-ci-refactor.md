# Winget CI Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the Winget automation to run more efficiently in CI while preserving manual dispatch and correcting the package map.

**Architecture:** Keep `excavator.yml` as the workflow that detects Excavator-created manifest changes and dispatches `winget.yml` only when mapped manifests changed. Keep `winget.yml` as the reusable submission workflow, but simplify its detection and Komac execution path and make the package map unambiguous. The work stays limited to workflow YAML and the package map JSON.

**Tech Stack:** GitHub Actions YAML, Bash, PowerShell, `jq`, GitHub REST API, JSON

---

## File Structure

- Modify: `.github/workflows/winget.yml`
  Responsibility: detect eligible Winget submissions from changed manifests and submit them through Komac with lower CI overhead.
- Modify: `.github/workflows/excavator.yml`
  Responsibility: run Excavator, identify mapped manifest changes from the pushed commit range, and dispatch the Winget workflow only when needed.
- Modify: `winget/package-map.json`
  Responsibility: map Scoop manifest names to a single unambiguous Winget identifier per manifest.

### Task 1: Correct The Package Map

**Files:**
- Modify: `winget/package-map.json`

- [ ] **Step 1: Write the failing validation expectation**

Use this check to confirm the current file is semantically wrong for duplicate keys:

```bash
jq -r '.vcredist' winget/package-map.json
```

Expected: a single value is returned even though the source file visually lists three `vcredist` entries, proving the current shape silently drops data.

- [ ] **Step 2: Inspect the related manifest to choose the one effective mapping to keep**

Run:

```bash
sed -n '1,220p' bucket/vcredist.json
```

Expected: confirm the manifest is a single Scoop package, so the JSON map must resolve to a single Winget identifier in this refactor.

- [ ] **Step 3: Replace the duplicate-key section with one explicit mapping**

Update the `vcredist` entries so the JSON object contains only one `vcredist` key. The edit should reduce:

```json
"vcredist": "Microsoft.VCRedist.2015+.arm64",
"vcredist": "Microsoft.VCRedist.2015+.x64",
"vcredist": "Microsoft.VCRedist.2015+.x86"
```

to one concrete entry:

```json
"vcredist": "Microsoft.VCRedist.2015+.x86"
```

- [ ] **Step 4: Validate the JSON after the edit**

Run:

```bash
jq empty winget/package-map.json
```

Expected: command exits successfully with no output.

- [ ] **Step 5: Commit the package-map fix**

```bash
git add winget/package-map.json
git commit -m "fix: remove duplicate winget package map keys"
```

### Task 2: Refactor The Excavator Dispatch Workflow

**Files:**
- Modify: `.github/workflows/excavator.yml`

- [ ] **Step 1: Capture the current workflow shape before editing**

Run:

```bash
sed -n '1,240p' .github/workflows/excavator.yml
```

Expected: confirm the existing workflow runs on `windows-latest`, executes Excavator, compares SHAs, filters manifests through `winget/package-map.json`, and dispatches `winget.yml`.

- [ ] **Step 2: Simplify the dispatch step while preserving behavior**

Edit the workflow so the dispatch logic:

```yaml
- keeps the existing schedule and manual trigger
- keeps `actions/checkout@main`
- keeps the Excavator action invocation
- clearly exits early when no remote SHA change occurred
- clearly exits early when `winget/package-map.json` is missing
- computes changed `bucket/*.json` manifests from the compare API response
- filters only manifest names that exist in the map file
- dispatches `winget.yml` with a comma-separated `manifests` input
```

The target shape should remain a single PowerShell step after Excavator, but with tighter variable naming and fewer incidental branches than the current script.

- [ ] **Step 3: Read the edited workflow to verify structure**

Run:

```bash
sed -n '1,240p' .github/workflows/excavator.yml
```

Expected: the workflow still has one `excavate` job and one dispatch step, but the control flow is easier to follow and only dispatches when mapped manifests changed.

- [ ] **Step 4: Perform a syntax sanity check**

Run:

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/excavator.yml"); puts "ok"'
```

Expected: prints `ok`.

- [ ] **Step 5: Commit the Excavator workflow refactor**

```bash
git add .github/workflows/excavator.yml
git commit -m "refactor: streamline winget dispatch from excavator"
```

### Task 3: Refactor The Winget Submission Workflow

**Files:**
- Modify: `.github/workflows/winget.yml`

- [ ] **Step 1: Capture the current workflow before editing**

Run:

```bash
sed -n '1,320p' .github/workflows/winget.yml
```

Expected: confirm the current detect job computes package candidates and the submit job runs Komac in a per-package matrix.

- [ ] **Step 2: Reshape the detect job for cleaner CI behavior**

Edit `.github/workflows/winget.yml` so the detect phase still supports:

```yaml
- manual dispatch with optional `manifests` input
- diff-based detection for non-dispatch runs
- skipping packages without map entries
- skipping packages without a version
- skipping packages whose Scoop version is not newer than the latest Winget version
```

The refactor should also:

```yaml
- keep the workflow on `ubuntu-latest`
- keep a single structured JSON output for downstream package submission
- reduce avoidable branching and repeated shell bookkeeping where possible
- keep package-level failure isolation in the submit matrix
```

- [ ] **Step 3: Align the Komac submission step with the leaner flow**

Preserve the token gate and submission behavior, but keep the submit job focused on:

```yaml
- checkout only if still needed by the final script shape
- resolve `WINGET_TOKEN` once per matrix entry
- call the Komac action with `update`, `--version`, and `--urls`
```

The resulting job should not perform extra unrelated setup.

- [ ] **Step 4: Read the edited workflow to verify outputs and job boundaries**

Run:

```bash
sed -n '1,320p' .github/workflows/winget.yml
```

Expected: the workflow has a clean `detect` job with `has_updates` and `packages` outputs and a `submit` matrix job gated on those outputs.

- [ ] **Step 5: Perform syntax and JSON-shape sanity checks**

Run:

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/winget.yml"); puts "ok"'
jq empty winget/package-map.json
```

Expected: YAML validation prints `ok`, and the JSON validation exits successfully.

- [ ] **Step 6: Review the final diff**

Run:

```bash
git diff -- .github/workflows/winget.yml .github/workflows/excavator.yml winget/package-map.json
```

Expected: the diff shows only the intended workflow and mapping refactors with no unrelated file changes.

- [ ] **Step 7: Commit the Winget workflow refactor**

```bash
git add .github/workflows/winget.yml .github/workflows/excavator.yml winget/package-map.json
git commit -m "refactor: optimize winget ci workflows"
```
