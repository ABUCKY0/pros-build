# PROS Build Action

## Usage:

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
        uses: actions/checkout@v2

      - name: Run LemLib/pros-build
        id: test
        uses: LemLib/pros-build

      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name:  ${{ steps.test.outputs.name }}
          path:  ${{ github.workspace }}/template/*
```
