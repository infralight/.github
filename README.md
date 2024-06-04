# Firefly Reusable GitHub Actions and Workflows

<!-- vim-markdown-toc GFM -->

* [Workflows](#workflows)
    * [cached-golang-ecr-image-managed](#cached-golang-ecr-image-managed)
* [Actions](#actions)
    * [bump-monorepo-version-tag](#bump-monorepo-version-tag)

<!-- vim-markdown-toc -->

This repository contains reusable GitHub actions and workflows for usage by
other Firefly repositories.

This page only documents a few of the provided actions/workflows.

## Workflows

### cached-golang-ecr-image-managed

This workflow compiles a Go application, packages it into a Dockerfile, and
pushes it to AWS ECR. The workflow requires the consuming project to have a
Makefile with two tasks: one to compile the project, and one to package into a
Docker image. The compile task must be named similarly to the application, and
the packaging task should be named similarly, but with a "-docker" suffix. For
example, if the workflow is used to build an application called "aws-fetcher",
then the Makefile must have an "aws-fetcher" task that compiles the application,
and an "aws-fetcher-docker" task that packages the compiled executable. It also
requires the "test" task for running unit tests.

The workflow has the advantage of caching Go dependencies and compiled assets,
reducing build times significantly. It supplies consuming projects with a
musl-libc compiler, which is generally required as our applications are packaged
into Alpine Linux images, which do not have glibc. To use musl-libc, the
compilation step in the Makefile must use the `$CC` environment variable:

```Makefile
aws-fetcher:
	CC=$(CC) go build -o bin/aws-fetcher applications/aws-fetcher/main.go
```

When packaging into a Docker image, the workflow provides the buildx plugin:

```Makefile
aws-fetcher-docker:
	docker buildx build --load -f Dockerfile -t aws-fetcher:latest .
```

See [workflows/cached-golang-ecr-image-managed.yaml](the workflow file) for a list and explanations
of all input fields accepted by the workflow.

## Actions

### bump-monorepo-version-tag

See the action's [own README.md](actions/bump-monorepo-version-tag) for documentation.
