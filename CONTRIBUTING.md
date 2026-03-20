# Contributing to SwiftSynapseMacros

Thank you for your interest in contributing to SwiftSynapseMacros!

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a new branch for your feature or bug fix
4. Make your changes
5. Run the tests: `swift test`
6. Commit your changes using conventional commit format
7. Push to your fork and submit a pull request

## Spec-First Workflow

This project follows a spec-driven development model. All `.swift` files are generated from specs in `CodeGenSpecs/`.

1. **Spec changes come first**: When adding or changing functionality, update the relevant spec in `CodeGenSpecs/` before modifying code.
2. **AI generates code from specs**: AI reads the updated specs and generates the corresponding implementation. Specs are the authoritative source -- code is derived from them.
3. **Never edit `.swift` files directly**: Every generated file has a header comment pointing to its source spec. Edit the spec, then re-generate.
4. **Review cycle**: Spec review (are the requirements correct?), code generation (does the output match the spec?), test verification (`swift build && swift test` pass).

When reviewing contributions, verify that spec changes accompany any behavioral code changes. A code change without a corresponding spec update should be questioned.

## Development Setup

### Requirements

- Swift 6.2+
- macOS 26+

### Building

```bash
swift build
```

### Testing

```bash
swift test
```

## Commit Conventions

All commits must follow the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <subject>
```

### Types

| Type | Usage |
|---|---|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `test` | Adding or updating tests |
| `docs` | Documentation changes |
| `spec` | Spec file changes |
| `refactor` | Code restructuring without behavior change |
| `chore` | Build, dependencies, CI, tooling |

### Scopes

`agent`, `output`, `capability`, `types`, `plugin`, `tests`, `docs`, `specs`

### Examples

```
feat(agent): add streaming support to @SpecDrivenAgent
fix(output): correct type name extraction in @StructuredOutput
test(agent): add expansion test for diagnostic on struct
spec(agent): add streaming run method to spec
docs(docs): update README installation section
```

## AI Attribution

This project is human-led by [RichNasz](https://github.com/RichNasz), with [Claude Code](https://claude.ai/code) as the code generation tool. All AI-generated code is reviewed and approved by a human maintainer.

Commits with AI-assisted code must include the following trailer:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Pull Request Standards

PRs should:

- Follow the conventional commit format for the title
- Include a summary of changes (1-3 bullet points)
- Have a test plan with checklist items
- Pass all checks before requesting review

### Review Checklist

- [ ] `swift build` succeeds with no warnings
- [ ] `swift test` passes all tests
- [ ] New features have macro expansion tests
- [ ] Conventional commit format used
- [ ] Spec files updated if behavior changes
- [ ] Documentation updated if public API changes

## Code of Conduct

This project follows the Contributor Covenant. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Reporting Issues

If you find a bug or have a feature request, please open a GitHub Issue.

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
