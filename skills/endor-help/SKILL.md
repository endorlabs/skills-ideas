---
name: endor-help
description: >
  Quick reference for all available Endor Labs commands. Use when the user says "endor
  help", "what commands are available", "endor usage", "what can endor do", or wants to
  discover available security scanning capabilities. Do NOT use when the user already
  knows which specific command they want — route to that skill directly.
---

# Endor Labs Command Reference

Present this reference to the user:

```markdown
## Endor Labs Commands

### Getting Started
| Command | Description |
|---------|-------------|
| `/endor` | Natural language assistant |
| `/endor-setup` | First-time setup (install, auth, configure) |
| `/endor-demo` | Try without an account |
| `/endor-help` | This reference |

### Scanning
| Command | Description |
|---------|-------------|
| `/endor-scan` | Quick security scan (seconds) |
| `/endor-scan-full` | Full scan with reachability (minutes) |
| `/endor-sca` | Dependency vulnerability scan (SCA) |
| `/endor-sast` | Static application security testing |
| `/endor-secrets` | Scan for exposed secrets |
| `/endor-container` | Scan container images and Dockerfiles |

### Dependency Analysis
| Command | Description |
|---------|-------------|
| `/endor-check <pkg>` | Check dependency for vulnerabilities |
| `/endor-score <pkg>` | View package health scores |
| `/endor-upgrade-impact <pkg>` | Analyze upgrade impact |
| `/endor-license` | Check license compliance |

### Findings & Remediation
| Command | Description |
|---------|-------------|
| `/endor-findings` | View findings with filters |
| `/endor-fix <CVE>` | Remediation guidance |
| `/endor-explain <CVE>` | Detailed CVE/finding info |
| `/endor-troubleshoot` | Diagnose scan errors |

### Compliance & Governance
| Command | Description |
|---------|-------------|
| `/endor-review` | Pre-PR security review |
| `/endor-sbom` | SBOM management |
| `/endor-policy` | Security policy management |
| `/endor-cicd` | Generate CI/CD pipelines |

### Advanced
| Command | Description |
|---------|-------------|
| `/endor-api` | Custom API queries |

### Quick Examples
```
/endor-scan                          # Quick scan
/endor-check lodash 4.17.15         # Check version
/endor-fix CVE-2021-23337           # Fix a vuln
/endor-findings critical reachable  # Filter findings
/endor-review                        # Pre-PR check
```

### Tips
- `/endor-scan` for quick overview, `/endor-scan-full` before releases
- `/endor-review` before PRs, `/endor-score` before adding deps
- `/endor-troubleshoot` when scans fail
```

If the user asks about a specific command, provide detailed usage for that command only.
