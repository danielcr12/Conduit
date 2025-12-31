# SwiftAI → Conduit Rename Implementation Plan

**Created**: 2025-12-30
**Target Package Name**: `Conduit`
**Macro Module Name**: `ConduitMacros`
**Cache Path Strategy**: Rename with migration
**Clone Directory**: Add to .gitignore

---

## Executive Summary

This plan renames the SwiftAI package to **Conduit** across all ~680+ occurrences in the codebase. The rename is a **breaking change** requiring a major version bump.

### Key Changes
- Package: `SwiftAI` → `Conduit`
- Macros: `SwiftAIMacros` → `ConduitMacros`
- Tests: `SwiftAITests` → `ConduitTests`
- Cache: `~/Library/Caches/SwiftAI/` → `~/Library/Caches/Conduit/` (with migration)

---

## Phase 1: Pre-Rename Preparation

### 1.1 Git Preparation
```bash
# Create a new branch for the rename
git checkout -b feature/rename-to-conduit

# Ensure clean working state
git status
```

### 1.2 Add clone/ to .gitignore
**File**: `.gitignore`

Add at the end:
```gitignore
# Reference implementations (not part of build)
clone/
```

### 1.3 Backup Current State
```bash
# Tag current state before rename
git tag v1.x.x-pre-conduit-rename
```

---

## Phase 2: Directory Structure Rename

### 2.1 Rename Source Directories
```bash
# Rename main source directory
mv Sources/SwiftAI Sources/Conduit

# Rename macros directory
mv Sources/SwiftAIMacros Sources/ConduitMacros

# Rename test directory
mv Tests/SwiftAITests Tests/ConduitTests
```

### 2.2 Rename Key Files
```bash
# Main module file
mv Sources/Conduit/SwiftAI.swift Sources/Conduit/Conduit.swift

# Macro plugin file
mv Sources/ConduitMacros/SwiftAIMacrosPlugin.swift Sources/ConduitMacros/ConduitMacrosPlugin.swift
```

---

## Phase 3: Package.swift Updates

**File**: `/Package.swift`

### 3.1 Package Name (Line 6)
```swift
// Before
name: "SwiftAI",

// After
name: "Conduit",
```

### 3.2 Library Product (Lines 14-15)
```swift
// Before
.library(
    name: "SwiftAI",
    targets: ["SwiftAI"]
),

// After
.library(
    name: "Conduit",
    targets: ["Conduit"]
),
```

### 3.3 Macro Target (Lines 28-35)
```swift
// Before
.macro(
    name: "SwiftAIMacros",
    dependencies: [...],
    path: "Sources/SwiftAIMacros"
),

// After
.macro(
    name: "ConduitMacros",
    dependencies: [...],
    path: "Sources/ConduitMacros"
),
```

### 3.4 Main Target (Lines 38-40)
```swift
// Before
.target(
    name: "SwiftAI",
    dependencies: [
        "SwiftAIMacros",
        ...
    ]
),

// After
.target(
    name: "Conduit",
    dependencies: [
        "ConduitMacros",
        ...
    ]
),
```

### 3.5 Test Target (Lines 54-55)
```swift
// Before
.testTarget(
    name: "SwiftAITests",
    dependencies: ["SwiftAI"],
),

// After
.testTarget(
    name: "ConduitTests",
    dependencies: ["Conduit"],
),
```

### 3.6 Macro Test Target (Lines 61-66)
```swift
// Before
.testTarget(
    name: "SwiftAIMacrosTests",
    dependencies: [
        "SwiftAIMacros",
    ],
    path: "Tests/SwiftAIMacrosTests"
),

// After
.testTarget(
    name: "ConduitMacrosTests",
    dependencies: [
        "ConduitMacros",
    ],
    path: "Tests/ConduitMacrosTests"
),
```

---

## Phase 4: Macro System Updates

### 4.1 External Macro Declarations
**File**: `Sources/Conduit/Core/Macros/GenerableMacros.swift`

```swift
// Line 77 - Before
public macro Generable() = #externalMacro(module: "SwiftAIMacros", type: "GenerableMacro")

// Line 77 - After
public macro Generable() = #externalMacro(module: "ConduitMacros", type: "GenerableMacro")

// Line 145 - Before
public macro Guide(_ description: String?, _ constraints: Any...) = #externalMacro(module: "SwiftAIMacros", type: "GuideMacro")

// Line 145 - After
public macro Guide(_ description: String?, _ constraints: Any...) = #externalMacro(module: "ConduitMacros", type: "GuideMacro")

// Line 149 - Before
public macro Guide(_ description: String) = #externalMacro(module: "SwiftAIMacros", type: "GuideMacro")

// Line 149 - After
public macro Guide(_ description: String) = #externalMacro(module: "ConduitMacros", type: "GuideMacro")
```

### 4.2 Macro Plugin Registration
**File**: `Sources/ConduitMacros/ConduitMacrosPlugin.swift`

```swift
// Before
// SwiftAIMacrosPlugin.swift
// SwiftAI
// Compiler plugin registration for SwiftAI macros.

struct SwiftAIMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        GenerableMacro.self,
        GuideMacro.self,
    ]
}

// After
// ConduitMacrosPlugin.swift
// Conduit
// Compiler plugin registration for Conduit macros.

struct ConduitMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        GenerableMacro.self,
        GuideMacro.self,
    ]
}
```

### 4.3 Diagnostic Domains
**File**: `Sources/ConduitMacros/GenerableMacro.swift` (Line 320)
```swift
// Before
var diagnosticID: MessageID { MessageID(domain: "SwiftAIMacros", id: rawValue) }

// After
var diagnosticID: MessageID { MessageID(domain: "ConduitMacros", id: rawValue) }
```

**File**: `Sources/ConduitMacros/GuideMacro.swift` (Line 47)
```swift
// Before
var diagnosticID: MessageID { MessageID(domain: "SwiftAIMacros", id: rawValue) }

// After
var diagnosticID: MessageID { MessageID(domain: "ConduitMacros", id: rawValue) }
```

### 4.4 Generated Code Patterns (If using qualified names)
**File**: `Sources/ConduitMacros/GenerableMacro.swift`

Search and replace in generated code strings:
- `SwiftAI.Generable` → `Conduit.Generable`
- `SwiftAI.GenerableContentConvertible` → `Conduit.GenerableContentConvertible`

---

## Phase 5: Source File Updates

### 5.1 File Headers (Batch Replace)
Replace in all ~90 source files:
```swift
// Before
// SwiftAI

// After
// Conduit
```

**Command**:
```bash
find Sources/Conduit Sources/ConduitMacros -name "*.swift" -exec sed -i '' 's|// SwiftAI|// Conduit|g' {} \;
```

### 5.2 Main Module File
**File**: `Sources/Conduit/Conduit.swift`

```swift
// Before (Line 1-2)
// SwiftAI.swift
// SwiftAI

// After
// Conduit.swift
// Conduit

// Before (Line 81)
/// The current version of the SwiftAI framework.

// After
/// The current version of the Conduit framework.

// Before (Line 86)
public let swiftAIVersion = "1.2.0"

// After
public let conduitVersion = "2.0.0"  // Major version bump for breaking change
```

### 5.3 Documentation Comments
Search and replace in all source files:
- `SwiftAI's` → `Conduit's`
- `SwiftAI framework` → `Conduit framework`
- `SwiftAI provides` → `Conduit provides`
- `SwiftAI supports` → `Conduit supports`

**Files with significant doc updates**:
- `Sources/Conduit/Core/Protocols/AIProvider.swift`
- `Sources/Conduit/Core/Protocols/Generable.swift`
- `Sources/Conduit/Core/Errors/AIError.swift`
- `Sources/Conduit/Core/Types/Schema.swift`
- `Sources/Conduit/Providers/Anthropic/AnthropicProvider+Helpers.swift`

---

## Phase 6: Test File Updates

### 6.1 Import Statements (38 files)
Replace in all test files:
```swift
// Before
@testable import SwiftAI

// After
@testable import Conduit
```

**Command**:
```bash
find Tests/ConduitTests -name "*.swift" -exec sed -i '' 's|@testable import SwiftAI|@testable import Conduit|g' {} \;
```

### 6.2 File Headers
Replace in all test files:
```swift
// Before
// SwiftAITests
// or
// SwiftAI Tests
// or
// SwiftAI

// After
// ConduitTests
// or
// Conduit Tests
// or
// Conduit
```

### 6.3 Test Code References
**File**: `Tests/ConduitTests/ModelManagement/ModelManagementTests.swift` (Line 617)
```swift
// Before
.appendingPathComponent("SwiftAITests-\(UUID().uuidString)")

// After
.appendingPathComponent("ConduitTests-\(UUID().uuidString)")
```

---

## Phase 7: Cache Path Migration

### 7.1 Update Cache Directory
**File**: `Sources/Conduit/ModelManagement/ModelCache.swift`

```swift
// Line 54 - Before
/// Default cache directory: ~/Library/Caches/SwiftAI/Models/

// Line 54 - After
/// Default cache directory: ~/Library/Caches/Conduit/Models/

// Line 61 - Before
return caches.appendingPathComponent("SwiftAI/Models", isDirectory: true)

// Line 61 - After
return caches.appendingPathComponent("Conduit/Models", isDirectory: true)
```

### 7.2 Add Migration Logic
**File**: `Sources/Conduit/ModelManagement/ModelCache.swift`

Add migration method (insert after line ~70):
```swift
/// Migrates cache from legacy SwiftAI location to new Conduit location.
/// Call this during app initialization.
public func migrateFromLegacyCache() async throws {
    let fileManager = FileManager.default
    guard let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
        return
    }

    let legacyPath = caches.appendingPathComponent("SwiftAI/Models", isDirectory: true)
    let newPath = caches.appendingPathComponent("Conduit/Models", isDirectory: true)

    // Check if legacy cache exists and new cache doesn't
    guard fileManager.fileExists(atPath: legacyPath.path),
          !fileManager.fileExists(atPath: newPath.path) else {
        return
    }

    // Create parent directory for new path
    try fileManager.createDirectory(
        at: newPath.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    // Move legacy cache to new location
    try fileManager.moveItem(at: legacyPath, to: newPath)

    // Clean up empty legacy directory
    let legacyParent = legacyPath.deletingLastPathComponent()
    if try fileManager.contentsOfDirectory(atPath: legacyParent.path).isEmpty {
        try fileManager.removeItem(at: legacyParent)
    }
}
```

### 7.3 Update VLMDetector
**File**: `Sources/Conduit/Services/VLMDetector.swift`

```swift
// Line 242 - Before
// This assumes models are stored in ~/Library/Application Support/SwiftAI/models/

// Line 242 - After
// This assumes models are stored in ~/Library/Application Support/Conduit/models/

// Line 380-381 - Before
// Construct SwiftAI models directory
let swiftAIDir = appSupport.appendingPathComponent("SwiftAI", isDirectory: true)

// Line 380-381 - After
// Construct Conduit models directory
let conduitDir = appSupport.appendingPathComponent("Conduit", isDirectory: true)
```

### 7.4 Update ModelManager Documentation
**File**: `Sources/Conduit/ModelManagement/ModelManager.swift`

```swift
// Lines 43-44 - Before
/// - MLX models: `~/Library/Caches/SwiftAI/Models/mlx/{repo-name}/`
/// - HuggingFace models: `~/Library/Caches/SwiftAI/Models/huggingface/{repo-name}/`

// Lines 43-44 - After
/// - MLX models: `~/Library/Caches/Conduit/Models/mlx/{repo-name}/`
/// - HuggingFace models: `~/Library/Caches/Conduit/Models/huggingface/{repo-name}/`
```

---

## Phase 8: Runtime Identifiers

### 8.1 User-Agent Strings
**File**: `Sources/Conduit/Providers/OpenAI/OpenAIConfiguration.swift` (Line 498)
```swift
// Before
headers["User-Agent"] = "SwiftAI/\(Self.frameworkVersion)"

// After
headers["User-Agent"] = "Conduit/\(Self.frameworkVersion)"
```

**File**: `Sources/Conduit/Providers/HuggingFace/HFInferenceClient.swift` (Line 685)
```swift
// Before
request.setValue("SwiftAI/1.0", forHTTPHeaderField: "User-Agent")

// After
request.setValue("Conduit/2.0", forHTTPHeaderField: "User-Agent")
```

### 8.2 Logger Subsystems (Optional)
**File**: `Sources/Conduit/ModelManagement/ModelManager.swift` (Lines 78-80)
```swift
// Before
private static let logger = Logger(
    subsystem: "com.swiftai.framework",
    category: "ModelManager"
)

// After
private static let logger = Logger(
    subsystem: "com.conduit.framework",
    category: "ModelManager"
)
```

---

## Phase 9: Documentation Updates

### 9.1 README.md
**File**: `/README.md`

Key changes:
```markdown
// Line 1 - Before
# SwiftAI

// After
# Conduit

// Line 12 - Before
SwiftAI provides a clean, idiomatic Swift interface...

// After
Conduit provides a clean, idiomatic Swift interface...

// Line 37 - Before
.package(url: "https://github.com/christopherkarani/SwiftAI", from: "0.1.0")

// After
.package(url: "https://github.com/christopherkarani/Conduit", from: "2.0.0")

// Line 41 - Before
Then add `"SwiftAI"` to your target's dependencies.

// After
Then add `"Conduit"` to your target's dependencies.

// All code examples - Before
import SwiftAI

// After
import Conduit

// Line 644 - Before
**Storage Location:** `~/Library/Caches/SwiftAI/Models/`

// After
**Storage Location:** `~/Library/Caches/Conduit/Models/`
```

### 9.2 CLAUDE.md
**File**: `/CLAUDE.md`

Update all references:
- `SwiftAI` → `Conduit`
- `Sources/SwiftAI/` → `Sources/Conduit/`
- `Tests/SwiftAITests/` → `Tests/ConduitTests/`
- `import SwiftAI` → `import Conduit`

### 9.3 DocC Documentation
**File**: `Sources/Conduit/Documentation.docc/SwiftAgentsIntegration.md`

Update all references and code examples.

### 9.4 Integration Guides
**File**: `Documentation/SwiftAI-HuggingFace-Integration-Guide.md`

- Rename file to: `Documentation/Conduit-HuggingFace-Integration-Guide.md`
- Update all internal references

### 9.5 Planning Documents
Update these files (search & replace):
- `IMPLEMENTATION_PLAN.md`
- `ANTHROPIC_ENHANCEMENTS_PLAN.md`
- `CODE_REVIEW_REPORT.md`
- `CODE_REVIEW_REMEDIATION.md`
- `ANTHROPIC_PROGRESS.md`

---

## Phase 10: SwiftLint Configuration

**File**: `.swiftlint.yml`

```yaml
# Line 1 - Before
# SwiftLint Configuration for SwiftAI

# After
# SwiftLint Configuration for Conduit

# Line 85 - Before
  - Tests/SwiftAITests/Mocks

# After
  - Tests/ConduitTests/Mocks
```

---

## Phase 11: Verification

### 11.1 Build Verification
```bash
# Clean build folder
swift package clean

# Build the package
swift build

# Run tests
swift test
```

### 11.2 Search for Remaining References
```bash
# Search for any remaining SwiftAI references (excluding clone/)
grep -r "SwiftAI" --include="*.swift" --include="*.md" --include="*.yml" . | grep -v "clone/"

# Should return minimal/zero results
```

### 11.3 Verify Macro Expansion
Create a test file to verify macros work:
```swift
import Conduit

@Generable
struct TestRename {
    let value: String
}

// Verify this compiles and expands correctly
```

---

## Phase 12: Git Commit & Release

### 12.1 Stage All Changes
```bash
git add -A
```

### 12.2 Create Commit
```bash
git commit -m "$(cat <<'EOF'
feat!: Rename package from SwiftAI to Conduit

BREAKING CHANGE: Package renamed from SwiftAI to Conduit

This is a major breaking change affecting:
- Package name: SwiftAI → Conduit
- Import statements: import SwiftAI → import Conduit
- Macro module: SwiftAIMacros → ConduitMacros
- Cache location: ~/Library/Caches/SwiftAI/ → ~/Library/Caches/Conduit/

Migration guide:
1. Update Package.swift dependency URL
2. Replace all `import SwiftAI` with `import Conduit`
3. Call `ModelCache.shared.migrateFromLegacyCache()` on app launch
   to migrate existing cached models

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### 12.3 Create Release Tag
```bash
git tag -a v2.0.0 -m "Conduit v2.0.0 - Package rename from SwiftAI"
```

### 12.4 Push Changes
```bash
# If renaming existing repo
git push origin feature/rename-to-conduit
git push origin v2.0.0

# If creating new repo
git remote add conduit https://github.com/christopherkarani/Conduit.git
git push conduit main
git push conduit v2.0.0
```

---

## Execution Checklist

### Pre-Rename
- [ ] Create feature branch
- [ ] Add clone/ to .gitignore
- [ ] Tag current state

### Directory Renames
- [ ] Rename Sources/SwiftAI → Sources/Conduit
- [ ] Rename Sources/SwiftAIMacros → Sources/ConduitMacros
- [ ] Rename Tests/SwiftAITests → Tests/ConduitTests
- [ ] Rename SwiftAI.swift → Conduit.swift
- [ ] Rename SwiftAIMacrosPlugin.swift → ConduitMacrosPlugin.swift

### Package.swift
- [ ] Update package name
- [ ] Update library product
- [ ] Update macro target
- [ ] Update main target
- [ ] Update test targets

### Macro System
- [ ] Update #externalMacro module references (3 locations)
- [ ] Update plugin struct name
- [ ] Update diagnostic domains (2 locations)
- [ ] Update generated code patterns (if applicable)

### Source Files
- [ ] Update file headers (~90 files)
- [ ] Update documentation comments
- [ ] Update version constant

### Test Files
- [ ] Update import statements (38 files)
- [ ] Update file headers
- [ ] Update test code references

### Cache & Runtime
- [ ] Update cache directory path
- [ ] Add migration logic
- [ ] Update VLMDetector paths
- [ ] Update User-Agent strings
- [ ] Update logger subsystems (optional)

### Documentation
- [ ] Update README.md
- [ ] Update CLAUDE.md
- [ ] Update DocC documentation
- [ ] Rename/update integration guides
- [ ] Update planning documents

### Configuration
- [ ] Update .swiftlint.yml

### Verification
- [ ] Clean build succeeds
- [ ] All tests pass
- [ ] No remaining SwiftAI references (excluding clone/)
- [ ] Macro expansion works correctly

### Release
- [ ] Create commit with breaking change notice
- [ ] Tag v2.0.0
- [ ] Push to repository
- [ ] Update GitHub repo name (if applicable)

---

## Estimated Time

| Phase | Estimated Time |
|-------|---------------|
| Preparation | 5 minutes |
| Directory renames | 2 minutes |
| Package.swift | 10 minutes |
| Macro system | 15 minutes |
| Source files (batch) | 10 minutes |
| Test files (batch) | 5 minutes |
| Cache migration | 20 minutes |
| Runtime identifiers | 5 minutes |
| Documentation | 30 minutes |
| Verification | 15 minutes |
| Git & Release | 10 minutes |
| **Total** | **~2 hours** |

---

## Rollback Plan

If issues are discovered after rename:

```bash
# Reset to pre-rename state
git checkout main
git branch -D feature/rename-to-conduit

# Or revert specific commit
git revert <commit-hash>
```

---

**Plan Created**: 2025-12-30
**Author**: Claude Code
**Target Completion**: Manual execution required
