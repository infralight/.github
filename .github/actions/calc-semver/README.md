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
| `should-tag` | Whether git tag should be created |

## Usage

```yaml
- uses: ./.github/actions/calc-semver
  with:
    prefix: 'ci-runner-worker/'
    watch-paths: 'components/runners pkg'
    target-env: staging

- name: Tag and Push
  if: steps.semver.outputs.should-tag == 'true'
  run: |
    git tag "${{ steps.semver.outputs.git-tag }}"
    git push origin "${{ steps.semver.outputs.git-tag }}"
```

## Tag Format

- **Dev**: `v1.2.3-dev.abc123`
- **Staging**: `v1.2.3-rc.1`
- **Prod**: `v1.2.3`
