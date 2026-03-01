#!/bin/bash

set -e

# Find last production tag (exclude dev/rc)
LAST_TAG=$(git tag -l "${PREFIX}v*" | grep -v -E -- '-(dev|rc)\.' | sort -V | tail -n1)

NEXT_V="${INITIAL_VER}"
CHANGED="true"

if [ -n "$LAST_TAG" ]; then
    BASE_VERSION=${LAST_TAG#${PREFIX}v}

    # Get commit logs for watched paths
    if [ -z "$WATCH_PATHS" ]; then
        LOGS=$(git log $LAST_TAG..HEAD --format=%s -- . ':!.github')
    else
        LOGS=$(git log $LAST_TAG..HEAD --format=%s -- $WATCH_PATHS)
    fi

    if [ -z "$LOGS" ]; then
        NEXT_V="$BASE_VERSION"
        CHANGED="false"
    else
        # Parse version and bump based on conventional commits
        IFS='.' read -r v1 v2 v3 <<< "$BASE_VERSION"

        if echo "$LOGS" | grep -qE "BREAKING CHANGE|!"; then
            v1=$((v1+1)); v2=0; v3=0
        elif echo "$LOGS" | grep -qE "^feat"; then
            v2=$((v2+1)); v3=0
        else
            v3=$((v3+1))
        fi

        NEXT_V="$v1.$v2.$v3"
    fi
fi

# Calculate environment-specific tag
case "$TARGET_ENV" in
    dev)
        ECR_TAG="v${NEXT_V}-dev.${GITHUB_SHA::6}"
        ;;
    staging)
        LATEST_RC=$(git tag -l "${PREFIX}v${NEXT_V}-rc.*" | sort -V | tail -n1)
        if [ -z "$LATEST_RC" ]; then
            RC_NUM=1
        else
            RC_NUM=$(echo "$LATEST_RC" | grep -oE 'rc\.([0-9]+)$' | cut -d'.' -f2)
            RC_NUM=$((RC_NUM + 1))
        fi
        ECR_TAG="v${NEXT_V}-rc.${RC_NUM}"
        ;;
    prod)
        ECR_TAG="v${NEXT_V}"
        ;;
esac

GIT_TAG="${PREFIX}${ECR_TAG}"

# Create and push git tag (not for dev)
if [ "$CHANGED" == "true" ] && [ "$TARGET_ENV" != "dev" ]; then
    echo "Creating git tag: $GIT_TAG"
    git tag "$GIT_TAG"
    git push origin "$GIT_TAG"
    echo "✓ Tag created and pushed"
else
    if [ "$TARGET_ENV" == "dev" ]; then
        echo "Skipping git tag for dev environment"
    else
        echo "No changes detected, skipping git tag"
    fi
fi

# Output
echo "changed=$CHANGED" >> "$GITHUB_OUTPUT"
echo "next-version=$NEXT_V" >> "$GITHUB_OUTPUT"
echo "ecr-tag=$ECR_TAG" >> "$GITHUB_OUTPUT"
echo "git-tag=$GIT_TAG" >> "$GITHUB_OUTPUT"

echo "Version: $NEXT_V | ECR Tag: $ECR_TAG | Changed: $CHANGED"
