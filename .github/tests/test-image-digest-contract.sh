#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_WORKFLOW="$ROOT/.github/workflows/cached-golang-ecr-image-managed.yaml"
SYNC_WORKFLOW="$ROOT/.github/workflows/argocd-sync.yaml"
export PRIVATE_ECR_CONDITION="inputs.ecr-public-registry == '' || inputs.environment != 'prod'"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_yq() {
  local expression=$1
  local file=$2
  local description=$3
  [ "$(yq -r "$expression" "$file")" = "true" ] || fail "$description"
}

assert_yq '.on.workflow_call.outputs.image-digest.value == "${{ jobs.build-push-ecr.outputs.image-digest }}"' "$BUILD_WORKFLOW" \
  'workflow_call must expose image-digest'
assert_yq '.jobs.build-push-ecr.outputs.image-digest == "${{ steps.image-digest.outputs.image-digest }}"' "$BUILD_WORKFLOW" \
  'build job must expose the resolver output'
assert_yq '[.jobs.build-push-ecr.steps[] | select(.id == "image-digest")] | length == 1' "$BUILD_WORKFLOW" \
  'build workflow must contain one digest resolver'
assert_yq '(.jobs.build-push-ecr.steps | to_entries | map(select(.value.name == "Resolve private ECR image digest") | .key) | .[0]) > (.jobs.build-push-ecr.steps | to_entries | map(select(.value.name == "[Build]: build image & upload to ECR - CUSTOM") | .key) | .[0])' "$BUILD_WORKFLOW" \
  'digest resolution must follow every push path'
assert_yq '(.jobs.build-push-ecr.steps[] | select(.id == "image-digest") | .if) == strenv(PRIVATE_ECR_CONDITION)' "$BUILD_WORKFLOW" \
  'digest resolution must be private-ECR-only'
assert_yq '(.jobs.build-push-ecr.steps[] | select(.id == "image-digest") | .run | contains("--repository-name \"$ECR_REPOSITORY\"")) and (.jobs.build-push-ecr.steps[] | select(.id == "image-digest") | .run | contains("--image-ids \"imageTag=$IMAGE_TAG\"")) and (.jobs.build-push-ecr.steps[] | select(.id == "image-digest") | .run | contains("^sha256:[0-9a-f]{64}$")) and (.jobs.build-push-ecr.steps[] | select(.id == "image-digest") | .run | contains("imageTag=latest") | not)' "$BUILD_WORKFLOW" \
  'resolver must query the produced tag and validate the authoritative digest'

assert_yq '.on.workflow_call.inputs.imageDigest.type == "string" and .on.workflow_call.inputs.imageDigest.default == ""' "$SYNC_WORKFLOW" \
  'imageDigest must be an optional string'
assert_yq '.on.workflow_call.inputs.imageDigestPath.type == "string" and .on.workflow_call.inputs.imageDigestPath.default == ""' "$SYNC_WORKFLOW" \
  'imageDigestPath must be an optional string'
assert_yq '.on.workflow_call.inputs.retryLimit.type == "string" and .on.workflow_call.inputs.retryLimit.default == "3"' "$SYNC_WORKFLOW" \
  'retryLimit must default to 3'
assert_yq '[.jobs.argocd.steps[] | select(.uses == "EndBug/add-and-commit@a94899bca583c204427a224a7af87c02f9b325d5")] | length == 1' "$SYNC_WORKFLOW" \
  'Argo workflow must retain a single commit step'
assert_yq '(.jobs.argocd.steps | to_entries | map(select(.value.name == "UPDATE IMAGE TAG") | .key) | max) < (.jobs.argocd.steps | to_entries | map(select(.value.name == "UPDATE IMAGE DIGEST") | .key) | .[0])' "$SYNC_WORKFLOW" \
  'tag mutation must precede digest mutation'
assert_yq '(.jobs.argocd.steps | to_entries | map(select(.value.name == "UPDATE IMAGE DIGEST") | .key) | .[0]) < (.jobs.argocd.steps | to_entries | map(select(.value.uses == "EndBug/add-and-commit@a94899bca583c204427a224a7af87c02f9b325d5") | .key) | .[0])' "$SYNC_WORKFLOW" \
  'digest mutation must precede the commit'
assert_yq '(.jobs.argocd.steps[] | select(.name == "[ArgoCD]: trigger sync") | .with.options) == "--retry-limit ${{ inputs.retryLimit }} --retry-backoff-duration 20s"' "$SYNC_WORKFLOW" \
  'Argo sync must use retryLimit'

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

VALIDATION_SCRIPT="$TMP_DIR/validate.sh"
yq -r '.jobs.argocd.steps[] | select(.name == "Validate image digest inputs") | .run' "$SYNC_WORKFLOW" > "$VALIDATION_SCRIPT"
chmod +x "$VALIDATION_SCRIPT"

GOOD_DIGEST="sha256:$(printf 'a%.0s' {1..64})"
run_validation() {
  IMAGE_DIGEST=$1 IMAGE_DIGEST_PATH=$2 RETRY_LIMIT=$3 bash "$VALIDATION_SCRIPT"
}

run_validation '' '' '3' || fail 'validation rejected tag-only defaults'
run_validation "$GOOD_DIGEST" '.image.digest' '5' || fail 'validation rejected paired digest inputs'
if run_validation "$GOOD_DIGEST" '' '3'; then fail 'validation accepted an unpaired digest'; fi
if run_validation '' '.image.digest' '3'; then fail 'validation accepted an unpaired digest path'; fi
if run_validation 'sha256:ABC' '.image.digest' '3'; then fail 'validation accepted a malformed digest'; fi
if run_validation "$GOOD_DIGEST" 'image..digest' '3'; then fail 'validation accepted a malformed dot path'; fi
if run_validation '' '' 'three'; then fail 'validation accepted a nonnumeric retryLimit'; fi

FIXTURE="$TMP_DIR/values.yaml"
cat > "$FIXTURE" <<'YAML'
image:
  tag: release-123
unrelated: preserved
YAML

MUTATION_SCRIPT="$TMP_DIR/mutate.sh"
yq -r '.jobs.argocd.steps[] | select(.name == "UPDATE IMAGE DIGEST") | .run' "$SYNC_WORKFLOW" > "$MUTATION_SCRIPT"
IMAGE_DIGEST="$GOOD_DIGEST" IMAGE_DIGEST_PATH='.image.digest' VALUES_FILE="$FIXTURE" bash "$MUTATION_SCRIPT"
[ "$(yq -r '.image.digest' "$FIXTURE")" = "$GOOD_DIGEST" ] || fail 'digest mutation did not set the requested path'
[ "$(yq -r '.image.tag' "$FIXTURE")" = 'release-123' ] || fail 'digest mutation changed the image tag'
[ "$(yq -r '.unrelated' "$FIXTURE")" = 'preserved' ] || fail 'digest mutation changed unrelated values'

echo 'Image digest contract validation passed.'
