# outskirts-action

Official GitHub Action for [outskirts](https://outskirts.dev), a Swift dead-code scanner (a maintained fork of Periphery).

It downloads a released `outskirts` binary from [tiny-earth-moon/outskirts](https://github.com/tiny-earth-moon/outskirts/releases), verifies its SHA-256 checksum and its build provenance attestation, puts it on `PATH` and runs `outskirts scan`. By default results show up as annotations on the pull request and the step fails when unused code is found.

What each check guarantees:

- The SHA-256 checksum is downloaded from the same release as the archive. It only catches a corrupted or truncated download; it does not prove where the archive comes from.
- The build provenance attestation (`gh attestation verify`, outskirts 3.22.0 and later) proves the archive was built by the release workflow of `tiny-earth-moon/outskirts`. This is the check that protects against a tampered release. It needs the GitHub CLI (`gh`) on the runner, which GitHub-hosted macOS runners provide. Releases before 3.22.0 have no attestation and get the checksum only, announced by a notice.

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
| `args` | `""` | Extra arguments for `outskirts scan`, split on spaces, tabs and newlines (one or several lines). Single or double quotes keep a value with spaces together (`--schemes "My App"`); there are no escapes, and the text is never evaluated by a shell (`$(...)`, `;`, `*` stay literal). An unterminated quote is an error. |
| `working-directory` | `.` | Directory the scan runs in. |
| `format` | `github-actions` | `--format` value; `github-actions` emits annotations. |
| `fail-on-results` | `true` | `true` passes `--strict`: the step fails when results are reported. `false` passes `--no-strict`, which overrides `strict: true` in the configuration file, and never fails on results, only on real errors (build failure, bad configuration). |
| `verify-attestation` | `true` | Verify the build provenance attestation of the archive (outskirts 3.22.0 and later; older releases are checked against their checksum only). `false` skips it and leaves only the checksum, which does not protect against a tampered release: use it only when `gh` is not available on a self-hosted runner. |
| `github-token` | `${{ github.token }}` | Token used to resolve `latest` and to verify the attestation. |

## Outputs

| Name | Description |
|------|-------------|
| `version` | The installed outskirts version. |

## Pinning

`@v1` follows the latest compatible release of this action. For reproducible builds, pin the action to a full commit SHA and set `version` to an exact outskirts release, so a new scanner release cannot change your results unexpectedly:

```yaml
      - uses: tiny-earth-moon/outskirts-action@ca927cb20581e1f9a4cd92ef34311d0a99aed0bd # v1.1.0
        with:
          version: 3.23.0
```

## License

MIT
