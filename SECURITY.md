# Security Policy

## Supported Versions

Security updates and patches are provided for the current active release line.

| Version | Supported          |
| ------- | ------------------ |
| main    | Yes                |
| < 1.0   | No                 |

## Reporting a Vulnerability

If you discover a security vulnerability in SplitSpace, please report it privately rather than opening a public issue.

- Submit a report through GitHub Private Vulnerability Reporting on this repository.
- Alternatively, reach out directly to the maintainer via GitHub profile contact information.

Please include the following details in your report:
- A clear description of the vulnerability.
- Steps to reproduce the issue or proof-of-concept code.
- Potential impact and affected components.
- Any suggested mitigations.

You will receive an initial response within 48 hours acknowledging receipt of the report.

## Security Architecture and Boundaries

SplitSpace is designed with the following security principles:

- Standard User Privileges: SplitSpace never requires or requests administrative elevation (UAC). It operates entirely within the local user context.
- Local Isolation: Multi-window sessions are isolated locally using dedicated `--user-data-dir` profiles within `$env:LOCALAPPDATA\SplitSpace`.
- No Network Telemetry: SplitSpace does not collect, log, or transmit telemetry or analytical data to any remote server.
- Clean Lifecycle: The uninstaller cleans up generated shortcuts and registry Jump List registrations created by the installer.
