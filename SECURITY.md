# Security Policy

## Supported versions

Only the latest release of the action receives security fixes.

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub Security Advisories:
<https://github.com/tiny-earth-moon/outskirts-action/security/advisories/new>

Do not open a public issue for a security problem. This is a volunteer-maintained project: expect an initial response within about 7 days. There is no bug bounty.

## Scanning untrusted projects

The action runs outskirts, which builds the project being analysed with `xcodebuild` or `swift build`. A build can execute arbitrary code from that project (build scripts, plugins, macros): only run the action on code you trust, and take care with workflows triggered by pull requests from forks.
