---
name: endor-demo
description: |
  Demo Endor Labs capabilities without requiring an account. Uses simulated data to showcase vulnerability scanning, dependency checking, and remediation workflows.
  - MANDATORY TRIGGERS: endor demo, try endor, endor trial, demo security scan, endor without account
---

# Endor Labs Demo Mode

Demonstrate Endor Labs capabilities using simulated data. This lets users experience the workflow without requiring an account.

## When to Use

- User wants to try Endor Labs before signing up
- MCP server is not configured
- Authentication is not available
- User explicitly asks for a demo

## Demo Workflow

### 1. Welcome Message

Tell the user:

> This is a demo of Endor Labs security scanning. I'll simulate a scan of your repository to show what Endor Labs can do. For real results, run `/endor-setup` to connect your account.

### 2. Detect Project Info

Read the current directory to gather real project context:

- Check for dependency manifest files (package.json, go.mod, requirements.txt, pom.xml, Cargo.toml, etc.)
- Detect programming languages present
- Count source files

### 3. Simulated Scan Results

Present simulated but realistic results based on the detected project type. Use this format:

```markdown
## Demo Scan Results (Simulated)

**Project:** {detected project name}
**Languages:** {detected languages}
**Dependencies:** {estimated count from manifest}

### Vulnerability Summary

| Severity | Total | Reachable | Action |
|----------|-------|-----------|--------|
| Critical | 2 | 1 | Fix immediately |
| High | 5 | 2 | Fix urgently |
| Medium | 12 | 3 | Plan remediation |
| Low | 8 | 0 | Track as debt |

### Top Reachable Vulnerabilities (Simulated)

| Package | CVE | Severity | Description |
|---------|-----|----------|-------------|
| {relevant-pkg} | CVE-2024-XXXXX | Critical | Prototype Pollution |
| {relevant-pkg} | CVE-2024-XXXXX | High | Remote Code Execution |

### What Endor Labs Provides

1. **Reachability Analysis** - Only 6 of 27 vulnerabilities are actually reachable in your code
2. **Call Path Visualization** - See exactly how vulnerable code is called
3. **Prioritized Remediation** - Fix what matters first
4. **Upgrade Impact Analysis** - Predict breaking changes before upgrading
5. **Package Health Scores** - Evaluate packages before adoption
```

### 4. Demo Feature Showcase

Briefly demonstrate what each command does:

- `/endor-scan` - Quick scan in seconds
- `/endor-scan-full` - Deep analysis with call graphs
- `/endor-check lodash` - Check any package instantly
- `/endor-fix CVE-2024-XXXXX` - Get remediation steps
- `/endor-score express` - Evaluate package health
- `/endor-review` - Pre-PR security gate

### 5. Call to Action

End with:

> Ready to get real results? Run `/endor-setup` to connect your Endor Labs account, or visit https://www.endorlabs.com to sign up for free.

## Important Notes

- Clearly label all output as **simulated/demo** data
- Use realistic but obviously fake CVE numbers (e.g., CVE-2024-XXXXX)
- Tailor simulated packages to the actual project type detected
- Never present simulated data as real scan results
