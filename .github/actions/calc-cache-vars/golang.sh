#!/bin/bash

# Export Target Cache Type (e.g. "app-name" or "MONO_REPO")
target=$(find . -name go.mod | wc -l | awk '{print ($1>1)?"${APP_NAME}":"MONO_REPO"}')
echo "target=$([ "$target" = "MONO_REPO" ] && echo "*" || echo "$target")" >> "$GITHUB_OUTPUT"
echo "$target"
echo "target=$([ "$target" = "MONO_REPO" ] && echo "*" || echo "$target")" 

# Export Go Cache Paths
echo "go-build=/home/runner/.cache/go-build" >> "$GITHUB_OUTPUT"
echo "go-mod=/home/runner/go/pkg/mod" >> "$GITHUB_OUTPUT"

# FIRELY-CACHE-MANAGER Variables Modifications
if [ "$IS_CACHE_MANAGER" == "true" ]; then
    is_invoker=$(if [ $(find . -name go.mod | wc -l) -gt 1 ] && [ "${APP_NAME}" = "*" ]; then echo "yes"; else echo "no"; fi)
    echo "is-invoker=${is_invoker}" >> "$GITHUB_OUTPUT"
    # Override GO_VERSION from go.mod
    if [ "$target" == "MONO_REPO" ]; then
        GO_VERSION=$(grep '^go ' go.mod | awk '{print $2}')
    fi
fi

# Trim Patch Version (e.g. 1.23.0 -> 1.23)
go_version_short=$(echo $GO_VERSION | cut -d'.' -f1-2)
key_prefix="golang-v$go_version_short-$OS_RUNNER_KEY-$ARCHITECTURE-$VERB"

# Export Go Version
echo "go-version=$GO_VERSION" >> "$GITHUB_OUTPUT"
echo "go-version-short=$go_version_short" >> "$GITHUB_OUTPUT"

# Export Cache Keys
if [ "$target" == "MONO_REPO" ]; then
    checksum=$(echo $MONO_GO_SUM_HASH | cut -c 1-6)
    echo "cache-key=$key_prefix-checksum-$checksum" >> "$GITHUB_OUTPUT"
    echo "cache-key-any=$key_prefix-checksum-" >> "$GITHUB_OUTPUT"
else
    app_dir="$(make --dry-run ci-build-$APP_NAME 2>/dev/null | grep "go build"  | grep -oE '[^ ]+\.go' || echo)"
    app_dir="$(dirname $app_dir 2>/dev/null || echo)"
    go_sum_path="$([ -z "$app_dir" ] && ls **/go.sum | head -n 1 || echo "$app_dir/go.sum")"
    checksum=$(sha256sum $go_sum_path | awk '{print $1}' | cut -c 1-6)
    echo "cache-key=$key_prefix-$APP_NAME-checksum-$checksum" >> "$GITHUB_OUTPUT"
    echo "cache-key-any=$key_prefix-$APP_NAME-checksum-" >> "$GITHUB_OUTPUT"
    echo "cache-key-any2=$key_prefix-" >> "$GITHUB_OUTPUT"
fi
