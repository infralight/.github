# Calculate Semantic Version

Calculates semantic versions based on git history and conventional commits.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `prefix` | Yes | - | Version tag prefix (e.g., 'ci-runner-worker/') |
| `initial-version` | No | `1.0.0` | Initial version if no tags exist |
| `watch-paths` | No | `""` | Paths to watch (empty = all except .github) |
| `target-env` | Yes | - | Target environment: dev, staging, or prod |

## Outputs

| Output | Description |
|--------|-------------|
| `changed` | Whether version has changed (true/false) |
| `next-version` | Next semantic version (e.g., 1.2.3) |
| `ecr-tag` | ECR tag with environment suffix |
| `git-tag` | Full git tag with prefix |

## Usage

```yaml
- name: Calculate Version and Tag
  id: semver
  uses: ./.github/actions/calc-semver
  with:
    prefix: 'ci-runner-worker/'
    watch-paths: 'components/runners pkg'
    target-env: staging

- name: Build and Push
  if: steps.semver.outputs.changed == 'true'
  run: |
    docker build -t my-image:${{ steps.semver.outputs.ecr-tag }} .
    # Push to ECR using ${{ steps.semver.outputs.ecr-tag }}
```

## Behavior

- Automatically creates and pushes git tags for **staging** and **prod** environments
- Skips git tagging for **dev** environment
- Only tags when changes are detected in watched paths

## Tag Format

- **Dev**: `v1.2.3-dev.abc123` (no git tag created)
- **Staging**: `v1.2.3-rc.1` (git tag created)
- **Prod**: `v1.2.3` (git tag created)
