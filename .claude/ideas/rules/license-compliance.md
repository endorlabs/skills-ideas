# License Compliance Rule

Check license compatibility when adding or modifying dependencies.

## Trigger

This rule activates when:
- Adding new dependencies to any manifest file
- Updating dependency versions
- Creating new projects with dependencies

## License Categories

| Category | Licenses | Risk |
|----------|----------|------|
| Permissive | MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC | Low |
| Weak Copyleft | LGPL-2.1, LGPL-3.0, MPL-2.0 | Medium |
| Strong Copyleft | GPL-2.0, GPL-3.0, AGPL-3.0, SSPL | High |
| Unknown | No license, custom, UNLICENSED | High |

## Required Actions

When adding a dependency:

1. Check its license
2. If **Strong Copyleft** (GPL, AGPL): Warn the user. May require open-sourcing the project.
3. If **Unknown/No License**: Block. No license means no permission to use.
4. Suggest permissive alternatives for copyleft dependencies.

## Do Not Skip

License compliance is a legal requirement. Always check licenses when adding dependencies.
