---
name: endor-demo
description: >
  Demo Endor Labs capabilities using simulated data, no account required. Use when the
  user says "try endor", "demo", "endor without account", "show me what endor can do",
  or when MCP auth fails and user wants to see capabilities before signing up. Do NOT
  use when the user has a working Endor Labs account — use real scans instead.
---

# Endor Labs Demo Mode

Demonstrate Endor Labs capabilities using simulated data when no account is available.

## When to Use

- User wants to try before signing up
- MCP server not configured or auth unavailable
- User explicitly asks for a demo

## Workflow

### 1. Welcome

Tell user: This is a demo with simulated data. For real results, run `/endor-setup`.

### 2. Detect Project Info

Read current directory for real project context:
- Dependency manifests (package.json, go.mod, requirements.txt, pom.xml, Cargo.toml, etc.)
- Languages present
- Source file count

### 3. Simulated Scan Results

Present realistic results tailored to detected project type:

```markdown
## Demo Scan Results (Simulated)

**Project:** {name} | **Languages:** {detected} | **Dependencies:** {count}

### Vulnerability Summary

| Severity | Total | Reachable | Action |
|----------|-------|-----------|--------|
| Critical | 2 | 1 | Fix immediately |
| High | 5 | 2 | Fix urgently |
| Medium | 12 | 3 | Plan remediation |
| Low | 8 | 0 | Track as debt |

### What Endor Labs Provides

1. **Reachability Analysis** - Only 6 of 27 vulns are actually reachable
2. **Call Path Visualization** - See exactly how vulnerable code is called
3. **Prioritized Remediation** - Fix what matters first
4. **Upgrade Impact Analysis** - Predict breaking changes before upgrading
5. **Package Health Scores** - Evaluate packages before adoption
```

### 4. Feature Showcase

- `/endor-scan` - Quick scan in seconds
- `/endor-scan-full` - Deep analysis with call graphs
- `/endor-check lodash` - Check any package instantly
- `/endor-fix CVE-2024-XXXXX` - Get remediation steps
- `/endor-score express` - Evaluate package health
- `/endor-review` - Pre-PR security gate

### 5. Call to Action

End with: Ready for real results? Run `/endor-setup` or visit https://www.endorlabs.com to sign up free.

## Rules

- Clearly label ALL output as **simulated/demo** data
- Use obviously fake CVE numbers (e.g., CVE-2024-XXXXX)
- Tailor simulated packages to detected project type
- Never present simulated data as real results
