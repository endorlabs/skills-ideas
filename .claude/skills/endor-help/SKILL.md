---
name: endor-help
description: |
  Discover all available Endor Labs commands and their usage. Quick reference for all security scanning and analysis capabilities.
  - MANDATORY TRIGGERS: endor help, endor commands, endor usage, what can endor do, endor reference
---

# Endor Labs Command Reference

Display a comprehensive reference of all available Endor Labs commands.

## Output

Present this reference to the user:

```markdown
## Endor Labs Commands

### Getting Started
| Command | Description |
|---------|-------------|
| `/endor` | Main assistant - describe what you need in natural language |
| `/endor-setup` | First-time setup wizard (install, auth, configure) |
| `/endor-demo` | Try Endor Labs without an account |
| `/endor-help` | This command reference |

### Scanning
| Command | Description |
|---------|-------------|
| `/endor-scan` | Quick security scan (seconds) |
| `/endor-scan-full` | Full scan with reachability analysis (minutes) |
| `/endor-sca` | Scan dependencies for known vulnerabilities (SCA) |
| `/endor-sast` | Static application security testing |
| `/endor-secrets` | Scan for exposed secrets and credentials |
| `/endor-container` | Scan container images and Dockerfiles |

### Dependency Analysis
| Command | Description |
|---------|-------------|
| `/endor-check <package>` | Check a dependency for vulnerabilities |
| `/endor-score <package>` | View package health scores |
| `/endor-upgrade <package>` | Analyze upgrade impact (breaking changes) |
| `/endor-license` | Check license compliance |

### Findings & Remediation
| Command | Description |
|---------|-------------|
| `/endor-findings` | View security findings with filters |
| `/endor-fix <CVE>` | Get remediation guidance for a vulnerability |
| `/endor-explain <CVE>` | Get detailed CVE or finding information |
| `/endor-troubleshoot` | Diagnose scan errors and get resolution guidance |

### Compliance & Governance
| Command | Description |
|---------|-------------|
| `/endor-review` | Pre-PR security review |
| `/endor-sbom` | Software Bill of Materials management |
| `/endor-policy` | Security policy management |
| `/endor-cicd` | Generate CI/CD security pipelines |

### Advanced
| Command | Description |
|---------|-------------|
| `/endor-api` | Execute custom API queries |

### Examples

```
/endor-scan                          # Quick scan current repo
/endor-check lodash 4.17.15         # Check specific version
/endor-fix CVE-2021-23337           # Fix a vulnerability
/endor-score express                 # Evaluate a package
/endor-upgrade lodash 4.17.21       # Check upgrade impact
/endor-findings critical reachable  # Filter findings
/endor-review                        # Pre-PR security check
/endor-troubleshoot                  # Diagnose scan errors
```

### Tips

- Start with `/endor-scan` for a quick security overview
- Use `/endor-scan-full` before releases for comprehensive analysis
- Run `/endor-review` before creating pull requests
- Check `/endor-score` before adding new dependencies
- Use `/endor-troubleshoot` when a scan fails to diagnose the issue
```

## Contextual Help

If the user asks about a specific command, provide detailed usage for that command rather than the full reference.
