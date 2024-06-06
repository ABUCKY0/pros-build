# PROS Build Action

[![Test action](https://github.com/LemLib/pros-build/actions/workflows/test.yml/badge.svg)](https://github.com/LemLib/pros-build/actions/workflows/test.yml)

This action creates an environment capable of building PROS projects and templates, and builds them using [build.sh](/build-tools/build.sh)

Instructions on creating a custom build script, adding additional packages, and using this image as a base are located at the end of this readme.

## Usage:

### Inputs

- `multithreading`
  - Wether to use multithreading when building the project
  - Default: `true`
  - Required: `false`
- `no_commit_hash`
  - Wether to include a shortened commit hash at the end of the artifact name
  - Example: `LemLib@0.5.1+5881ac`
  - Default: `true`
  - Required: `false`
- `copy_readme_and_license_to_include`
  - Whether to make a VERSION file, copy the README(.md), and copy the LICENSE(.md) files to the `/include/(library name)` folder.
  - required: `false`
  - default: `false`
- `lib_folder_name`
  - The name of the library's folder name under the include directory.
  - required: `if copy_readme_and_license_to_include is set`
- `write_job_summary`
  - Whether to output build information to GitHub's Job Summary
  - required: `false`
  - default: `true`

### Outputs

```yml
name: PROS Build Example

on:
  push:
    branches: "**"
  pull_request:
    branches: "**"

  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run LemLib/pros-build
        id: test
        uses: LemLib/pros-build

      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ steps.test.outputs.name }}
          path: ${{ github.workspace }}/template/*
```

## Using the Container in your own build script

If you wish to use your own build script using this container as a base, you can do so with the following:

It by default includes the packages built into the Ubuntu docker image, and contains the additional packages below:

```
jq (Used to parse the GitHub API response in build.sh)
wget (Used to download the toolchain)
git (Used to get the HEAD SHA hash)
gawk (Used to get lines from the user project's Makefile)
python3-minimal (Minimal installation of Python used for pros-cli)
python3-pip (Used to install pros-cli in the Dockerfile)
unzip (Unzips the template so that it can be uploaded to Github Actions)
pros-cli (through python)
aha (markdown coloring make output)
```

### Editing the Dockerfile
```Dockerfile
FROM ghcr.io/LemLib/pros-build:main

# Remove the included build script.
RUN rm -rf /build.sh

## Do what you wish here, such as copying your own build script in, add dependencies, etc

# Override ENTRYPOINT with your own. This isn't strictly necessary if you name your build script build.sh and put it in the root of the container (Such as /build.sh)
ENTRYPOINT []
```
