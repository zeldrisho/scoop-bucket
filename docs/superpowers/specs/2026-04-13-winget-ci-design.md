# Winget CI Refactor Design

## Goal

Improve the CI cost, maintainability, and correctness of the Winget automation by narrowing workflow responsibilities, removing silent data loss in the package map, and keeping manual dispatch support.

## Scope

Files in scope:

- `.github/workflows/winget.yml`
- `.github/workflows/excavator.yml`
- `winget/package-map.json`

Out of scope:

- Rewriting the version-replacement heuristics for all possible upstream version formats
- Replacing Komac with a custom submission script
- Changing Excavator scheduling or bucket update behavior

## Current Problems

1. `winget/package-map.json` contains duplicate `vcredist` keys. In JSON, only the last key is retained, so two intended mappings are discarded.
2. `winget.yml` performs substantial shell logic inline and repeats remote lookups for each package, which makes the workflow harder to reason about and slower in CI.
3. `excavator.yml` mixes the Excavator run with dispatch bookkeeping in a way that is correct but noisier than necessary.
4. The current flow has overlap between "detect changed manifests" and "submit Winget updates", which makes ownership between workflows less explicit.

## Chosen Approach

Keep two workflows with clearer separation of concerns.

- `excavator.yml` remains the scheduled/manual entrypoint. It runs Excavator, determines whether new commits were pushed, filters the changed manifests through `winget/package-map.json`, and dispatches `winget.yml` only when there is mapped work.
- `winget.yml` remains reusable through `workflow_dispatch`, but is refactored to be leaner and more CI-friendly on Linux. It resolves candidate package updates once in the detect phase, emits structured outputs, and submits updates through Komac with minimal downstream setup.
- `winget/package-map.json` is corrected so every intended mapping is represented unambiguously.

## Workflow Design

### Excavator Workflow

Responsibilities:

- Run Excavator on schedule or manual dispatch
- Detect whether Excavator pushed a new commit relative to the workflow start SHA
- Compute changed `bucket/*.json` manifests between the start SHA and resulting remote SHA
- Filter that manifest list to names present in `winget/package-map.json`
- Dispatch `winget.yml` with the filtered manifest list

Behavior:

- If Excavator does not push a commit, exit cleanly without dispatching Winget
- If no mapped manifests changed, exit cleanly without dispatching Winget
- Preserve `workflow_dispatch` support

### Winget Workflow

Responsibilities:

- Accept optional manifest names from manual or Excavator dispatch
- Determine which mapped packages are eligible for submission
- Skip packages without mapping, version, or usable upstream Winget state
- Submit eligible packages with Komac

Behavior:

- Continue to support manual dispatch without inputs by scanning all bucket manifests
- Continue to skip packages when the Scoop version is not newer than the latest Winget version
- Keep package-level failure isolation in the submit phase
- Prefer Linux-friendly execution and a smaller amount of per-package setup

## Package Map Design

The map file must contain unique JSON keys.

For `vcredist`, the current single manifest cannot safely map to three separate Winget identifiers in the current JSON object shape. The refactor will make this explicit instead of silently keeping only the last entry. The expected change is to retain the single effective mapping or reshape the data so multiple identifiers can be represented deterministically.

For this refactor, correctness and CI stability matter more than preserving an invalid multi-key illusion.

## Error Handling

- Missing `winget/package-map.json`: workflows exit without failure when dispatching would be meaningless
- Missing manifest version during manual dispatch: fail fast because the user explicitly requested processing
- Unreadable upstream Winget package path or installer manifest: skip that package and continue
- Missing `WINGET_TOKEN`: skip Komac submission with a warning instead of failing the workflow

## Testing And Verification

Verification for the implementation should include:

- YAML validation by reading the rendered workflow after edits
- JSON validation for `winget/package-map.json`
- A diff review to ensure manual dispatch, scheduled Excavator runs, and mapped-manifest dispatch still behave coherently

## Expected Outcome

- Less unnecessary CI work
- Clearer workflow boundaries
- Correct package map behavior
- Lower maintenance cost for future workflow changes
