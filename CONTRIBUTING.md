# Contributing to SwiftSynapseMacros

Thank you for your interest in contributing to SwiftSynapseMacros!

This project uses **spec-driven development**. Markdown specification files are the single source of truth for all code — every `.swift` file is generated from specs, not written by hand. This workflow currently requires a single maintainer to perform spec-to-code generation, so direct code contributions (pull requests) are not accepted at this time.

The best way to contribute is by **opening an issue**.

## How to Contribute

### Report a Bug

If you've found a bug or unexpected behavior, [open a bug report](https://github.com/RichNasz/SwiftSynapseMacros/issues/new?template=bug-report.yml). A good bug report includes:

- A clear description of what happened
- Steps to reproduce the behavior
- What you expected to happen instead
- Your platform (macOS, iOS, visionOS) and Swift version

### Request a Feature

Have an idea for a new capability or improvement? [Open a feature request](https://github.com/RichNasz/SwiftSynapseMacros/issues/new?template=feature-request.yml). Focus on the **use case** — describe the problem you're trying to solve, not just the solution you have in mind.

## What Happens Next

The maintainer triages incoming issues, updates the relevant specs, generates code from those specs, and ships the changes. This is a solo-maintainer project — issues are addressed as time permits, with no guaranteed timeline.

## Why Not Pull Requests?

All code in this project is generated from Markdown specs. A pull request that modifies `.swift` files directly would be overwritten the next time code is generated from specs, so code PRs cannot be merged.

This may evolve in the future as the project explores ways for the community to contribute to specs directly.

## Security Vulnerabilities

Do not open a public issue for security vulnerabilities. See [SECURITY.md](SECURITY.md) for responsible disclosure instructions.

## Code of Conduct

This project follows the Contributor Covenant. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

By participating in this project, you agree that any contributions will be licensed under the [Apache License 2.0](LICENSE).
