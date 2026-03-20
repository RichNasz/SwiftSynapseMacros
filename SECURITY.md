# Security Policy

## Scope

SwiftSynapseMacros is a Swift macro package that generates code at compile time. Security concerns for this project include:

- **Macro-generated code safety**: Ensuring generated code does not introduce vulnerabilities (injection, unsafe memory access, etc.)
- **Dependency vulnerabilities**: Issues in swift-syntax, SwiftLLMToolMacros, or SwiftOpenResponsesDSL that could affect this package
- **Spec integrity**: Ensuring spec files cannot be manipulated to produce unsafe generated code

## Supported Versions

| Version | Supported |
|---------|-----------|
| main branch | Yes |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public GitHub Issue for security vulnerabilities
2. Email the maintainer or use GitHub's private vulnerability reporting feature
3. Include a description of the vulnerability, steps to reproduce, and potential impact

## Response Timeline

- **Acknowledgment**: Within 48 hours of report
- **Assessment**: Within 1 week
- **Fix**: Dependent on severity; critical issues prioritized for immediate resolution

## Security Considerations for Macro Packages

Swift macros execute at compile time within the Swift compiler's sandbox. However, the generated code runs at application runtime. Contributors and users should be aware that:

- Generated code inherits the permissions of the host application
- `@SpecDrivenAgent` generates network-calling code (via `LLMClient`) -- ensure API keys are handled securely
- `@StructuredOutput` bridges JSON schema definitions -- validate schema sources
- Dependencies are pinned to branch references; review dependency updates carefully
