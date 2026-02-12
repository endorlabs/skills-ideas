# SAST Analysis Rule

Analyze code for security vulnerabilities when writing or modifying source code files.

## Trigger

This rule activates when you:
- Create new source code files
- Make significant changes to existing code
- Implement authentication, authorization, or data handling
- Write code that processes user input
- Create API endpoints or database queries

## Vulnerability Categories

### Critical
- **SQL Injection** (CWE-89): Never use string interpolation in SQL queries. Use parameterized queries.
- **Command Injection** (CWE-78): Never pass user input to `exec()`, `system()`, or `eval()`. Use safe APIs.

### High
- **XSS** (CWE-79): Use `textContent` not `innerHTML`. Sanitize user input before rendering.
- **Path Traversal** (CWE-22): Validate and normalize file paths. Check they stay within expected directories.
- **Insecure Deserialization** (CWE-502): Never use `pickle.loads()` or `ObjectInputStream` with untrusted data.

### Medium
- **Weak Cryptography** (CWE-327): Use bcrypt/argon2 for passwords, not MD5/SHA1.
- **Information Disclosure** (CWE-200): Never expose stack traces or internal errors to users.
- **CORS Misconfiguration** (CWE-942): Never use `origin: '*'` in production.

## Required Actions

When writing code that handles user input, authentication, database queries, file operations, or external commands:

1. Apply secure coding patterns (parameterized queries, input validation, proper encoding)
2. Use proper error handling without data leakage
3. Use secure defaults for configurations

## Language-Specific Patterns

- **JavaScript/TypeScript**: Use `===`, avoid `eval()`, use `crypto.randomUUID()` not `Math.random()`
- **Python**: Use `secrets` module, `subprocess.run([], shell=False)`, avoid `pickle` with untrusted data
- **Go**: Use `html/template` not `text/template`, `crypto/rand` not `math/rand`, `filepath.Clean()`
- **Java**: Use `PreparedStatement`, `SecureRandom`, avoid `Runtime.exec()` with user input

## Do Not Skip

Even for internal tools or prototypes, apply secure coding practices. Vulnerabilities in "temporary" code often make it to production.
