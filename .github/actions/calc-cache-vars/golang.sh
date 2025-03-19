#!/bin/bash

echo Hi
echo $GO_VERSION

# Trim Patch Version (e.g. 1.23.0 -> 1.23)
go_version=$(echo $go_version | cut -d'.' -f1-2)

# Export Target App (e.g. "app-name" or "*")
target=$(find . -name go.mod | wc -l | awk '{print ($1>1)?"${APP_NAME}":"*"}')
echo "target=${target}" >> "$GITHUB_OUTPUT"

# Export Go Cache Paths
echo "go-build=/home/runner/.cache/go-build" >> "$GITHUB_OUTPUT"
echo "go-mod=/home/runner/go/pkg/mod" >> "$GITHUB_OUTPUT"

# DEBUG
echo $go_version
echo "$target"

# Export Cache Keys
if [ "$target" != "*" ]; then
    app_dir="$(make --dry-run ci-build-$APP_NAME 2>/dev/null | grep "go build"  | grep -oE '[^ ]+\.go' || echo)"
    app_dir="$(dirname $app_dir 2>/dev/null || echo)"
    go_sum_path="$([ -z "$app_dir" ] && ls **/go.sum | head -n 1 || echo "$app_dir/go.sum")"
    checksum=$(sha256sum $go_sum_path | awk '{print $1}' | cut -c 1-6)
    echo "cache-key=golang-v$go_version-$OS_RUNNER_KEY-$ARCHITECTURE-$VERB-$APP_NAME-checksum-$checksum" >> "$GITHUB_OUTPUT"
    echo "cache-key-any=golang-v$go_version-$OS_RUNNER_KEY-$ARCHITECTURE-$VERB-$APP_NAME-checksum-" >> "$GITHUB_OUTPUT"
    echo "cache-key-any2=golang-v$go_version-$OS_RUNNER_KEY-$ARCHITECTURE-$VERB-" >> "$GITHUB_OUTPUT"
else
    checksum=$(sha256sum **/go.sum  | awk '{print $1}' | cut -c 1-6)
    echo cache-key=golang-v$go_version-$OS_RUNNER_KEY-$ARCHITECTURE-$VERB-checksum-$checksum
    echo "cache-key=golang-v$go_version-$OS_RUNNER_KEY-$ARCHITECTURE-$VERB-checksum-$checksum" >> "$GITHUB_OUTPUT"
    echo "cache-key-any=golang-v$go_version-$OS_RUNNER_KEY-$ARCHITECTURE-$VERB-checksum-" >> "$GITHUB_OUTPUT"
fi