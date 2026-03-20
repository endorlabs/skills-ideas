# Error Knowledge Base

## Table of Contents
1. Cross-Ecosystem Errors
2. NPM
3. Maven/Gradle
4. PyPI/Python
5. Go
6. Cargo/Rust
7. NuGet/.NET
8. RubyGems
9. Packagist/Composer

---

## Cross-Ecosystem Errors

### Private Registry

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `could not be authenticated by the GitHub Packages service` | GitHub Packages auth failure | Yes | Configure Private Package Registry integration |
| `Could not get resource 'https://.*\.pkg\.github\.com/.*'` | GitHub Packages error response | Yes | Configure Private Package Registry integration |
| `Failed to get Google credentials for GCS connection` | GCS auth failure | No | GCS unsupported for private package auth. Use CI pipeline instead |
| `error.*401.*(Unauthorized\|unauthorized)` | Generic 401 unauthorized | Yes | Check credentials/permissions for private registry |
| `(Artifactory\|Registry\|artifactory\|registry)` | Generic registry/artifactory issue | Yes | Configure Private Package Registry integration |

### Other

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `sandbox: unable to checkout commit` | Sandbox checkout failure | No | Contact Endor Labs support |

---

## NPM

### Private Registry

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `npm ERR! 404 Not Found - GET` | Package not found | Yes | Configure Private Package Registry |
| `npm ERR! code E401` / `npm error code E401` | Registry auth failure | Yes | Configure Private Package Registry with valid credentials |
| `npm ERR! code E404` | Package version not found | Yes | Check name/version; configure Private Registry if private |
| `Permission denied (publickey)` (npm) | SSH connection failed | No | Cloud scanning doesn't support SSH. Move to CI runner |
| `npm ERR! code ECONNREFUSED` | Connection refused | Yes | Check registry URL; configure Private Package Registry |
| `npm ERR! code ECONNRESET` | Connection reset | Yes | Check registry URL/network; configure Private Registry |
| `Could not resolve host` (npm) | DNS resolution failed for Git dep | Yes | Configure Private Package Registry or check Git URL |
| `\$\{.*\}` in npm config | Env var substitution failed in .npmrc | Yes | Set required env vars in Scan Profile or CI |
| `npm ERR! code ETIMEDOUT` | Connection timeout | Yes | Check registry availability; configure Private Package Registry |
| `npm ERR! code ETARGET` | Target version not found | Yes | Check version exists; may need Private Registry |
| `dependencies were not downloaded` | Dependencies not downloaded | Yes | Configure Private Package Registry |
| `Incorrect or missing password` / `Unable to authenticate` | Auth error | Yes | Configure Private Package Registry with valid credentials |
| `Unable to create .npmrc` | Cannot create npmrc | Yes | Check file permissions in scan environment |
| `Unable to find` npm deps at relative path | Deps at relative path not found | Yes | Check project structure and dependency paths |

### Toolchain

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `Unsupported engine` / `engine.*not compatible` | Node.js version incompatible | Yes | Update Scan Profile with correct Node.js version |
| `EBADENGINE` | Bad engine version | Yes | Update Scan Profile with compatible Node.js version |
| `unsupported protocol workspace:` | Workspace protocol unsupported | Yes | Update toolchain/package manager version in Scan Profile |
| `pnpm install.*failed` | pnpm installation failure | Yes | Check pnpm version compatibility in Scan Profile |
| `Found:.*node_modules/.*incompatible module` | Incompatible module | Yes | Update Node.js version in Scan Profile |
| Templated identifier `${` in package coords | Unresolved template variable | No | Project uses unrendered template variables |

### Other

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `Invalid package.json` | Malformed package.json | No | Fix syntax errors |
| `Cannot parse package-lock.json` | Corrupt lock file | No | Regenerate with `npm install` |
| `Cannot parse package.json` | Malformed package.json | No | Fix JSON syntax |
| `yarn.*workspace.*not in project` | Workspace outside project | No | Fix workspace config in package.json |
| `lock file.*other package manager` | Wrong package manager's lock file | No | Use consistent package manager; remove conflicting lock files |
| `Unable to find lock file` | No lock file | No | Generate: `npm install`, `yarn install`, or `pnpm install` |
| `package.json.*is a directory` | Path points to directory | No | Fix file path references |

---

## Maven/Gradle

### Private Registry

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `artifacts.*not.*Maven Central` / `not found in Maven Central` | Artifact absent from Central | Yes | Configure Private Package Registry |
| `Could not find artifact` | Artifact not found | Yes | Configure repository with published artifact |
| `Could not resolve.*artifact` / `artifact.*not.*resolved` | Resolution failure | Yes | Configure Private Package Registry if private |
| `Could not resolve.*POM` | POM resolution failure | Yes | Configure Private Package Registry if private |
| `403.*Forbidden` (Artifactory) | Access forbidden | Yes | Configure Private Package Registry with valid credentials |

### Toolchain

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `Java.*version.*required` / `release version.*not supported` | Java version not met | Yes | Set correct Java version in Scan Profile |
| `invalid target release` | Invalid Java target | Yes | Set correct Java version in Scan Profile |
| `source.*target.*6.*no longer supported` | Java 6 unsupported | No | Update to Java 8+ |
| `source.*target.*1\.4.*no longer supported` | Java 1.4 unsupported | No | Update to Java 8+ |
| `default-http-blocker` / `Blocked mirror for repositories` | Maven HTTP blocker (3.8.1+) | Yes | Use Maven 3.6.3 or lower in Scan Profile, or update repos to HTTPS |
| `Cannot find matching java installation` | Gradle can't find Java | Yes | Set correct Java version in Scan Profile |
| `endorGradleKotlinConfiguration` | Kotlin config not found | Yes | Set env var in Scan Profile. See [docs](https://docs.endor.ai/docs/scan-profiles/scan-profiles-for-gradle-projects#kotlin-projects) |
| `endorGradleAndroidConfiguration` | Android config not found | Yes | Set env var in Scan Profile. See [docs](https://docs.endor.ai/docs/scan-profiles/scan-profiles-for-gradle-projects#android-projects) |
| `ANDROID_SDK_ROOT` / `ANDROID_HOME` | Android SDK not found | Yes | Set ANDROID_HOME in Scan Profile |
| `tools.jar` not found | Legacy JDK tools.jar | No | Requires Java 1.6 or older (unsupported) |
| `javax.annotation` not found | Legacy javax.annotation | Yes | Use JDK 8 in Scan Profile |
| `javax.xml.bind` not found | Legacy javax.xml.bind | Yes | Try JDK 8 in Scan Profile |
| `class file has wrong version` / `UnsupportedClassVersionError` | Java version mismatch | Yes | Set correct Java version in Scan Profile |
| `maven-compiler-plugin.*release.*not supported` | Unsupported Java release | Yes | Use JDK supporting the specified release in Scan Profile |
| `maven-toolchains-plugin` not found | Toolchains not configured | Yes | Configure toolchain in Scan Profile |
| `IllegalAccessError` (reflection) | Legacy JDK illegal access | Yes | Try JDK 8 in Scan Profile |
| `API incompatibility` | Maven API incompatibility | Yes | Set correct Java version in Scan Profile |
| `java.*invalid source release` | Invalid source release | Yes | Set Java version in Scan Profile |

### Other

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `Invalid POM` / `Non-parseable POM` | Malformed pom.xml | Yes | Fix syntax (missing tags, unescaped chars) |
| `Maven dependency tree.*blocked` | Dep tree blocked | No | Contact Endor Labs support |
| `Java.*compilation.*failed` / `Fatal error compiling` | Compilation error | No | Fix compile errors and rescan |
| `Kotlin.*compilation error` | Kotlin compile error | No | Fix errors and rescan |
| `Gradle.*non-Java.*not supported` | Non-Java Gradle | No | Language not supported for dependency resolution |
| `PMD.*violations` | PMD blocking build | No | Add `-Dpmd.skip=true` via MAVEN_OPTS |
| `ant.*build.*exception` | Ant build failure | No | Fix Ant build errors |
| `jcenter` | JCenter (deprecated) | No | Remove JCenter as source (deprecated 2021) |
| `localhost:8081` / `localhost.*artifactory` | Localhost artifact repo | No | Fix repository URL or use Maven Central |
| `wagon provider` not configured | Maven wagon missing | No | Add wagon dependency to pom.xml |
| `docker.*not installed` | Docker unavailable | No | Docker not available in scan environment |
| Environment variable not found (Maven) | Missing env var | No | Cloud scan doesn't support custom env vars. Use CLI scan |
| `build failed with an exception` | Generic build failure | No | Fix build issues in repository |
| `internet connection error` | Network issue | No | Check connectivity |

---

## PyPI/Python

### Private Registry

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `No matching distribution found` | Package not found | Yes | Check if Private Package Registry needed |
| `version.*constraints.*not found` | Version constraints unsatisfiable | Yes | Configure Private Registry if private |
| `ModuleNotFoundError` / `No module named` | Module not found | No | May be private or undeclared. Check manifest |
| `password.*not found` in requirements URL | Unresolved variable in dep URL | Yes | Set required env vars in Scan Profile |
| `libraries not found` / `library.*not found` | System libraries missing | No | Not available in scan environment |
| `Private package registry not configured` | Private registry missing | Yes | Add Private Package Registry integration |
| `git clone.*failed` (SSH) | Git clone via SSH failed | No | Cloud scanning doesn't support SSH. Move to CI runner |

### Toolchain

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `python.*version.*required` / `requires Python` | Python version not met | Yes | Update Scan Profile with correct Python version |
| `currently activated Python version is not supported` | Poetry Python mismatch | Yes | Set correct Python version in Scan Profile |
| `Poetry.*solver.*Python version.*incompatible` | Poetry solver constraint failure | Yes | Set Python version satisfying all constraints in Scan Profile |
| `setup.py.*module not found` (distutils etc.) | Missing module in setup.py | Yes | Use Python 3.9+ in Scan Profile |
| `GetEnvFromMakefiles` error | setuptools Makefile parsing | Yes | Ensure setuptools compatible with Python version |
| `Python.h.*not found` / `python3-dev` | Missing Python C headers | No | Requires python3-dev. Move to CI runner |
| `missing header file` | Missing C header | No | Requires dev packages. Move to CI runner |
| `Cython.*not installed` | Cython missing | No | Requires pip install before build |
| `CCompiler.*not defined` | C compiler unavailable | No | Requires build tools on runner |
| `pg_config.*not found` | PostgreSQL dev libs missing | No | Move to CI runner |
| `poetry.*configuration.*invalid` (version) | Old Poetry rejects new config | Yes | Update Poetry to 1.8.0+ in Scan Profile |
| `setup.py.*not found` | Missing setup.py | No | May need pre-build script |
| `AttributeError` in build | Attribute error during build | Yes | Set valid Python version/modules in Scan Profile |
| `NameError` in build | Name error during build | Yes | Set valid Python version/modules in Scan Profile |
| `poetry.*not found` | Poetry missing | Yes | Install Poetry or add to Scan Profile |

### Other

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `ResolutionImpossible` / `resolution impossible` | Incompatible versions | No | Resolve version conflicts in requirements.txt |
| `Invalid distribution name` / `invalid version` | Invalid name/version syntax | No | Fix in manifest |
| `deprecated.*method` / `module uses deprecated` | Deprecated API | No | Upgrade module or downgrade setuptools |
| `package directory does not exist` | Missing package directory | No | Fix project structure |
| `Could not find library` / `OSError.*library` | System library missing | No | Move to CI runner |
| `removed package` | Package removed from registry | No | Find replacement. Move to CI runner |
| `missing build dependencies` | System build deps missing | No | Move to CI runner |
| `rust compiler missing` | Rust needed for Python package | No | Move to CI runner |
| `cmake.*compatibility.*removed` | CMake too old | No | Move to CI runner |
| `multiple top-level.*packages` | Flat-layout packaging error | No | Restructure or specify packages in manifest |
| `poetry.*mandatory fields` missing | Missing required fields | No | Add missing fields to [tool.poetry] |
| `editable mode` | Editable install required | No | Install in editable mode before scan |
| `non-zero exit status` | Command failed | No | Likely missing system module |
| `building package in non-package mode` | Invalid build context | No | Ensure valid manifest exists |
| `file not found` (Python build) | Missing file during build | No | Check file paths |

---

## Go

### Private Registry

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `go: module .* not found` | Module not found | Yes | Configure Private Package Registry if private |
| `private module` / `GOPRIVATE` | Private module access denied | Yes | Configure Private Package Registry or set GOPRIVATE |
| `git.*credential.*denied` / HTTP private dep | Private Git dep access denied | Yes | Configure Private Registry credentials |
| `build failed.*private dependency` | Build failed for private dep | Yes | Configure Private Package Registry |
| `missing go.sum entry.*private` | Missing go.sum for private dep | Yes | Configure Private Package Registry |

### Toolchain

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `go.*version.*required` / `go directive.*requires go` | Go version not met | Yes | Update Scan Profile with correct Go version |
| `go.mod.*version mismatch` | go.mod version conflict | Yes | Update Go version in Scan Profile |
| `unsupported.*-mod flag` | Outdated Go version | Yes | Upgrade Go in Scan Profile |
| `go.sum.*missing.*readonly` | go.sum entry missing (readonly) | Yes | Run `go mod tidy` or update Scan Profile |
| `inconsistent vendoring` | Vendor directory inconsistent | Yes | Run `go mod vendor` |
| `build failed.*windows` specific | Windows-specific package | No | Requires Windows. Move to CI on Windows |

### Other

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `invalid module path` | Invalid module path | No | Fix in go.mod |
| `cannot update go.mod.*readonly` | go.mod readonly | No | Run `go mod tidy` before scanning |
| `cannot find go.mod` | go.mod not found | No | Ensure go.mod exists at project root |
| `unexpected EOF` | Unexpected EOF | No | Check for corrupted source files |
| `compilation terminated` | Compilation failed | No | Fix compilation errors |
| `invalid package name` | Invalid package name | No | Fix package naming |

---

## Cargo/Rust

### Private Registry

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `cargo.*package.*not found` | Package not found | Yes | Configure Private Package Registry |
| `cargo.*version conflict` | Version conflict | Yes | Configure Private Package Registry |

### Toolchain

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `rust.*version.*required` / `requires rustc` | Rust version not met | Yes | Update Scan Profile with correct Rust version |
| `cannot parse Cargo.lock` | Lock file version incompatible | Yes | Upgrade rustc to 1.64+ in Scan Profile |
| `edition2024.*required` | edition2024 required | Yes | Update Rust to 1.85.0+ in Scan Profile |

### Other

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `private.*cargo.*registry` | Private registry access denied | Yes | Configure Private Package Registry |
| `invalid.*dependency.*specification` | Invalid dep spec | Yes | Fix version string in Cargo.toml |

---

## NuGet/.NET

### Private Registry

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `package.*not found.*nuget.org` | Package not found | Yes | Configure Private Package Registry |
| `package version.*not found` | Version not found | Yes | Configure Private Package Registry |
| `registry not found or misconfigured` | Source misconfigured | Yes | Configure Private Package Registry |
| `unable to load service index` | Cannot reach source | Yes | Configure Private Package Registry |
| `multiple package sources` | Conflicting sources | Yes | Use package source mapping or single registry |

### Toolchain

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `.NET SDK.*exact version required` | Exact SDK version needed | Yes | Update Scan Profile |
| `does not support targeting.*newer .NET` | SDK too old | Yes | Update .NET SDK in Scan Profile |
| `Xamarin` target framework | Xamarin EOL | Yes | Migrate to MAUI with .NET 6+ |
| `target framework does not exist` | Missing framework | Yes | Upgrade to .NET 6+ |
| `reference assemblies.*not found` | Reference assemblies missing | No | Doesn't affect dependency resolution |
| `invalid framework identifier` | Invalid framework | No | Requires Visual Studio + full .NET Framework |
| `target framework value not recognized` | Unrecognized TargetFramework | No | Set valid TargetFramework in .csproj/.props |
| `required workload not installed` | Missing workload | Yes | May be fixable via Scan Profile |
| `invalid version string` | Bad version in config | Yes | Fix version string |
| `non-SDK-style` project | Legacy project format | No | Convert to `<Project Sdk="Microsoft.NET.Sdk">` |
| `imported project not found` | Missing imported project | No | Fix path or install missing SDK |
| `.NET Framework 1.1` or `2.0` | Very old framework | No | Unsupported |
| `EnableWindowsTargeting` | Windows targeting required | No | Requires Windows CI machine |
| `incompatible project reference` | Framework incompatible across projects | No | Change target framework via Scan Profile |
| `dotnet.*executable not found` | Missing .NET SDK | Yes | Install via Scan Profile |

### Other

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `end of central directory record` | Corrupt .nupkg | No | Re-download package |
| `local source does not exist` | Local source path missing | No | Fix path in .csproj/NuGet.config |
| `namespace not found` | Missing using/package | No | Add using directive or install package |
| `WiX Toolset not found` | Requires Windows | No | Cannot scan on Linux |
| `output path not set` | Missing OutputPath | No | Set in .csproj |
| `source file not found` | Missing .cs file | No | Restore file or fix path |
| `duplicate class` / `duplicate method` | Duplicate definitions | No | Remove/rename duplicates |
| `preview feature not supported` | C# preview feature | No | Set `<LangVersion>preview</LangVersion>` |
| `unsupported Visual Studio component` | Legacy VS component | No | Requires .NET Core 7+ |
| `architecture not supported` | Unsupported CPU arch | No | Library may only support x64/x86 |

---

## RubyGems

### Private Registry

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `gem.*not found` | Gem not found | Yes | Configure Private Package Registry |
| `unable to resolve dependencies` | Resolution failure | Yes | Configure Private Package Registry |
| `private.*github.*HTTP` | Private GitHub gem via HTTP | No | Cloud scanning doesn't support Git credentials |
| `ruby.*not found` / `ruby executable` | Ruby not installed | Yes | Install Ruby or ensure in $PATH |
| `private gem source` | Private source access denied | Yes | Configure Private Package Registry |
| `unable to resolve host` | DNS/network failure for Git source | Yes | Check connectivity; configure Private Package Registry |
| `git repository.*unreachable` | Can't reach Git repo | No | Cloud scanning can't access private Git repos |

### Toolchain

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `ruby.*version.*required` | Ruby version mismatch | Yes | Update Ruby version in Scan Profile |
| `bundler.*version.*required` | Bundler version mismatch | Yes | Update Bundler version in Scan Profile |

### Other

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `multiple gemspecs` | Multiple .gemspec files | Yes | Delete extras or specify in Gemfile |
| `invalid gem specification` | Corrupted gemspec | No | Run `gem build` to identify issues |
| `invalid.*version` in gem | Invalid version string | No | Fix to Semantic Versioning |
| `could not find compatible.*versions` | Incompatible versions | No | Resolve conflicting requirements manually |

---

## Packagist/Composer

### Private Registry

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `authentication required` / `401` | Auth failure | Yes | Configure Private Package Registry for Packagist |
| `missing custom repository` | Private repo not configured | Yes | Add to composer.json or configure Private Registry |

### Other

| Pattern | Description | Fixable | Resolution |
|---------|-------------|---------|------------|
| `secure-http.*blocked` | HTTP blocked by secure-http | No | Update URL to HTTPS |
| `invalid package version` | Invalid name/version (often template vars) | No | Render templates before scanning. Move to CI |
| `composer.json.*composer.lock.*out of sync` | Lock file out of sync | Yes | Run `composer update` before scanning |
