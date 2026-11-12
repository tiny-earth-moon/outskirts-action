# outskirts-action

Official GitHub Action for [outskirts](https://outskirts.dev), a Swift dead-code scanner (a maintained fork of Periphery).

It downloads a released `outskirts` binary from [tiny-earth-moon/outskirts](https://github.com/tiny-earth-moon/outskirts/releases), verifies its SHA-256 checksum and its build provenance attestation, puts it on `PATH` and runs `outskirts scan`. By default results show up as annotations on the pull request and the step fails when unused code is found.

Requires a **macOS arm64** runner (`macos-15`, `macos-latest`) with Xcode.

## Usage

```yaml
name: dead-code
on: [push, pull_request]

jobs:
  outskirts:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      # Swift package
      - uses: tiny-earth-moon/outskirts-action@v1

      # Xcode project
      - uses: tiny-earth-moon/outskirts-action@v1
        with:
          args: --project App.xcodeproj --schemes App
```

A `.outskirts.yml` (or `.periphery.yml`) in the working directory is picked up as usual, so `args` can often stay empty.

## Inputs

| Name | Default | Description |
|------|---------|-------------|
| `version` | `latest` | outskirts version: `latest`, `3.20.0` or `v3.20.0`. |
| `args` | `""` | Extra arguments for `outskirts scan`, split on whitespace. |
| `working-directory` | `.` | Directory the scan runs in. |
| `format` | `github-actions` | `--format` value; `github-actions` emits annotations. |
| `fail-on-results` | `true` | `true` passes `--strict`: the step fails when results are reported. `false` never fails on results, only on real errors (build failure, bad configuration). |
| `verify-attestation` | `true` | Verify the build provenance attestation of the archive (outskirts 3.22.0 and later; older releases are checked against their checksum only). |
| `github-token` | `${{ github.token }}` | Token used to resolve `latest` and to verify the attestation. |

## Outputs

| Name | Description |
|------|-------------|
| `version` | The installed outskirts version. |

## Pinning

`@v1` follows the latest compatible release of this action. For reproducible builds, pin the action to a full commit SHA and set `version` to an exact outskirts release, so a new scanner release cannot change your results unexpectedly:

```yaml
      - uses: tiny-earth-moon/outskirts-action@591df5739c4bf1a6a9896b03e8dbec86950dd8c5 # v1.0.0
        with:
          version: 3.23.0
```

## License

MIT
