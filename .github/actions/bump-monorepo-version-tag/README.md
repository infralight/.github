# Automatic Monorepo Component Version Bump and Tag

<!-- vim-markdown-toc GFM -->

* [Overview](#overview)
* [Usage](#usage)
    * [Inputs](#inputs)
        * [`component-name`](#component-name)
        * [`component-path`](#component-path)
        * [`starting-version`](#starting-version)
    * [Outputs](#outputs)
        * [`tag`](#tag)
        * [`version`](#version)
    * [Example usage](#example-usage)
* [Development](#development)

<!-- vim-markdown-toc -->

## Overview

This GitHub action automatically bumps the version of a Go component in a
monorepo, and tags the commit with the new version, using the prefix
`COMPONENT-vVERSION`, where `COMPONENT` is the name of the component, and
`VERSION` is the new version, in [semantic versioning](https://semver.org/) format (i.e. MAJOR.MINOR.PATCH).

The action automatically determines the new version like so:

1. It takes the previous version number from the existing Git tags (if
   a tag for the component does not exist, a starting version is used
   as provided (defaults to '0.0.0').
2. It goes over all the commit messages that made changes to the
   component since the previous version, and looks for the hashtags
   `#major`, `#minor` and `#patch` in their messages. The largest hashtag wins
   (e.g. if there are 3 commits with `#patch` and one commit with `#minor`,
   then `#minor` wins. The winning version component is automatically
   bumped. If no hashtag exists, the minor component is bumped.
3. It tags the latest commit in the format described above.

## Usage

### Inputs

#### `component-name`

**Required**: The name of the component, in kebab-case.

#### `component-path`

**Required**: The path in the repository where the component lives.

#### `starting-version`

The starting version to use, in the format MAJOR.MINOR.PATCH. Do not provide the
"v" prefix (although the action will automatically remove it if it is provided).

### Outputs

#### `tag`

The full tag created, in the format `COMPONENT-vVERSION`.

#### `version`

The `VERSION` part of the full tag.

### Example usage

```yaml
jobs:
  your_job:
    runs-on: ubuntu-latest
    permissions:
      contents: write # Required for permission to push tags
    steps:
      - uses: actions/checkout@v2
      - uses: infralight/.github/.github/actions/bump-monorepo-version-tag@master
        with:
          component-name: 'some-microservice'
          component-path: 'path/to/microservice/'
          starting-version: '1.12.0' # optional, defaults to 0.0.0
```

## Development

NodeJS v20.x is required. The source file for the action is [index.js](index.js).
Install dependencies with `npm install`.

GitHub actions required NPM dependencies to be integrated into the project. To
avoid checking-in the node_modules directory, this action uses [@vercel/ncc](https://github.com/vercel/ncc)
to build a standalone version of the entire script, including its dependencies,
which is checked in under [dist/index.js](dist/index.js). This is done like this:

    npx ncc build index.js

Unit tests are also included:

    npm run test
