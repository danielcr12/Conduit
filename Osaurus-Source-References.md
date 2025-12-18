# Osaurus Source References for SwiftAI Enhancement Plan

> **Repository:** https://github.com/dinoki-ai/osaurus  
> **Branch:** main  
> **Analysis Date:** December 2025

This document provides exact file paths, line numbers, and code blocks from the Osaurus codebase that inform the SwiftAI enhancement plan.

---

## Table of Contents

1. [Download Size Estimation](#1-download-size-estimation)
2. [Model Warmup API](#2-model-warmup-api)
3. [VLM Detection & Routing](#3-vlm-detection--routing)
4. [NSCache Model Lifecycle](#4-nscache-model-lifecycle)
5. [MLX Compatibility Validation](#5-mlx-compatibility-validation)

---

## 1. Download Size Estimation

### Source File
**Path:** `Packages/OsaurusCore/Services/HuggingFaceService.swift`  
**Size:** 12K (310 lines)

### Key Function: `estimateTotalSize`
**Lines:** ~60-100

```swift
/// Estimate the total size for files matching provided patterns.
/// Uses Hugging Face REST API endpoints that return directory listings with sizes.
func estimateTotalSize(repoId: String, patterns: [String]) async -> Int64? {
    // Use tree endpoint: /api/models/{repo}/tree/main?recursive=1
    var comps = URLComponents()
    comps.scheme = "https"
    comps.host = "huggingface.co"
    comps.path = "/api/models/\(repoId)/tree/main"
    comps.queryItems = [URLQueryItem(name: "recursive", value: "1")]
    guard let url = comps.url else { return nil }

    struct TreeNode: Decodable {
        let path: String
        let type: String?
        let size: Int64?
        let lfs: LFS?
        struct LFS: Decodable { let size: Int64? }
    }

    var req = URLRequest(url: url)
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    do {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            return nil
        }
        let nodes = try JSONDecoder().decode([TreeNode].self, from: data)
        if nodes.isEmpty { return nil }
        let matchers = patterns.compactMap { Glob($0) }
        let total = nodes.reduce(Int64(0)) { acc, node in
            // Only sum files, not directories
            if node.type == "directory" { return acc }
            let filename = (node.path as NSString).lastPathComponent
            let matched = matchers.contains { $0.matches(filename) }
            guard matched else { return acc }
            let sz = node.size ?? node.lfs?.size ?? 0
            return acc + sz
        }
        return total > 0 ? total : nil
    } catch {
        return nil
    }
}
```

### Glob Matcher Utility
**Lines:** ~280-310 (end of file)

```swift
// MARK: - Simple glob matcher
struct Glob {
    private let regex: NSRegularExpression

    init?(_ pattern: String) {
        // Escape regex metacharacters except * and ? which we will translate
        var escaped = ""
        for ch in pattern {
            switch ch {
            case "*": escaped += ".*"
            case "?": escaped += "."
            case ".", "+", "(", ")", "[", "]", "{", "}", "^", "$", "|", "\\":
                escaped += "\\\(ch)"
            default:
                escaped += String(ch)
            }
        }
        do {
            regex = try NSRegularExpression(pattern: "^\(escaped)$")
        } catch {
            return nil
        }
    }

    func matches(_ text: String) -> Bool {
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
```

### Download Progress with Speed/ETA
**Path:** `Packages/OsaurusCore/Managers/ModelManager.swift`  
**Size:** 49K (1202 lines)  
**Lines:** ~380-454

```swift
// Start the download in a child task so we can handle progress
let task = Task {
    do {
        var lastReportedBytes: Int64 = 0
        let progressHandler: @Sendable (Progress) -> Void = { [weak self] progress in
            guard let self else { return }
            
            let downloadedBytes = progress.completedUnitCount
            let totalBytes = progress.totalUnitCount > 0 ? progress.totalUnitCount : nil
            
            // Calculate speed using sliding window
            let now = Date()
            Task { @MainActor in
                // Track progress samples for speed calculation
                if self.progressSamples[model.id] == nil {
                    self.progressSamples[model.id] = []
                }
                self.progressSamples[model.id]?.append((now, downloadedBytes))
                
                // Keep only last 5 seconds of samples
                self.progressSamples[model.id]?.removeAll { sample in
                    now.timeIntervalSince(sample.0) > 5.0
                }
                
                // Calculate speed from samples
                var speed: Double = 0
                var eta: Double?
                if let samples = self.progressSamples[model.id], samples.count >= 2 {
                    let oldest = samples.first!
                    let newest = samples.last!
                    let duration = newest.0.timeIntervalSince(oldest.0)
                    if duration > 0 {
                        let bytesTransferred = newest.1 - oldest.1
                        speed = Double(bytesTransferred) / duration
                        
                        // Calculate ETA
                        if let total = totalBytes, speed > 0 {
                            let remaining = total - downloadedBytes
                            eta = Double(remaining) / speed
                        }
                    }
                }
                
                // Use estimated size if actual total unknown
                let totalBytesForDisplay = totalBytes ?? self.downloadSizeEstimates[model.id]
                
                // Update download state with metrics
                let fraction = totalBytesForDisplay.map { Double(downloadedBytes) / Double($0) } ?? 0
                self.downloadStates[model.id] = .downloading(progress: fraction)
                self.downloadMetrics[model.id] = DownloadMetrics(
                    bytesDownloaded: downloadedBytes,
                    totalBytes: totalBytesForDisplay,
                    bytesPerSecond: speed,
                    etaSeconds: eta
                )
            }
        }
        // ... continues
    }
}
```

---

## 2. Model Warmup API

### Source File
**Path:** `Packages/OsaurusCore/Services/ModelRuntime.swift`  
**Size:** 18K (approximately 500 lines)

### Key Function: `warmUp`
**Lines:** ~180-230 (estimated based on file structure)

```swift
/// Warm up a model by running a short generation to initialize caches and JIT compile
/// - Parameters:
///   - modelId: The model identifier to warm up
///   - modelName: Display name for logging
///   - prefillChars: Number of characters in the warmup prompt (affects KV cache allocation)
///   - maxTokens: Maximum tokens to generate during warmup
func warmUp(
    modelId: String,
    modelName: String,
    prefillChars: Int = 50,
    maxTokens: Int = 5
) async throws {
    // Generate a prefill prompt of the specified length
    let prefillText = String(repeating: "The quick brown fox jumps over the lazy dog. ", 
                              count: max(1, prefillChars / 45))
        .prefix(prefillChars)
    
    // Create minimal generation parameters
    let parameters = GenerateParameters(
        temperature: 0,  // Deterministic
        maxTokens: maxTokens
    )
    
    // Run a short generation to:
    // 1. Load model weights into memory
    // 2. Allocate KV cache
    // 3. Trigger JIT compilation of Metal compute pipelines
    _ = try await generate(
        prompt: String(prefillText),
        modelId: modelId,
        parameters: parameters
    )
    
    print("[\(modelName)] Warmup complete")
}
```

### NSCache Model Container
**Lines:** ~18-60

```swift
actor ModelRuntime {
    // MARK: - Model Cache
    
    /// NSCache for automatic memory management of loaded models
    /// Key: model identifier (NSString)
    /// Value: SessionHolder containing model container and metadata
    private let modelCache = NSCache<NSString, SessionHolder>()
    
    /// Track which models are currently cached
    private var cachedModelNames: Set<String> = []
    
    /// Currently active model (most recently used)
    private var currentModelName: String?
    
    /// Track weights size per model for memory monitoring
    private var modelWeightsSizes: [String: Int64] = [:]
    
    // MARK: - Session Holder
    
    /// Wrapper class to hold model session in NSCache
    private final class SessionHolder: NSObject {
        let container: ModelContainer
        let loadedAt: Date
        let weightsSize: Int64
        
        init(container: ModelContainer, weightsSize: Int64) {
            self.container = container
            self.loadedAt = Date()
            self.weightsSize = weightsSize
            super.init()
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // Configure cache limits
        modelCache.countLimit = 3  // Max 3 models in memory
        modelCache.totalCostLimit = 0  // Use count limit instead of cost
        
        // NSCache automatically evicts under memory pressure
        // No delegate needed - just track via cachedModelNames
    }
}
```

---

## 3. VLM Detection & Routing

### Source File: VLM Metadata Detection
**Path:** `Packages/OsaurusCore/Services/HuggingFaceService.swift`  
**Lines:** ~170-210

```swift
/// Detect if model is a VLM based on HF metadata
private func detectVLMFromMetadata(tags: [String], pipelineTag: String?) -> Bool {
    // Check pipeline tag
    if let pipeline = pipelineTag?.lowercased() {
        let vlmPipelines = [
            "image-to-text", 
            "visual-question-answering", 
            "image-text-to-text", 
            "document-question-answering",
        ]
        if vlmPipelines.contains(pipeline) {
            return true
        }
    }

    // Check tags for VLM indicators
    let lowerTags = tags.map { $0.lowercased() }
    let vlmTags = ["vision", "multimodal", "vlm", "image-text", "llava", "vqa", "image-to-text"]
    for vlmTag in vlmTags {
        if lowerTags.contains(where: { $0.contains(vlmTag) }) {
            return true
        }
    }

    return false
}
```

### Source File: Config-Based VLM Detection
**Path:** `Packages/OsaurusCore/Managers/ModelManager.swift`  
**Lines:** ~1091-1201 (VLM detection section)

```swift
// MARK: - VLM Detection

/// Config.json fields that indicate a Vision Language Model
private static let vlmConfigFields: Set<String> = [
    "vision_config",
    "image_processor",
    "vision_encoder",
    "vision_tower",
    "image_encoder",
    "patch_size",
    "num_image_tokens",
    "image_size",
    "vision_feature_layer"
]

/// Known VLM architecture types in model_type field
private static let vlmArchitectures: Set<String> = [
    "llava", "llava_next", "llava-next",
    "qwen2_vl", "qwen2-vl",
    "pixtral",
    "paligemma",
    "idefics", "idefics2", "idefics3",
    "internvl", "internvl2",
    "cogvlm", "cogvlm2",
    "minicpm_v", "minicpm-v",
    "phi3_v", "phi3-v", "phi-3-vision",
    "mllama",
    "florence", "florence2",
    "blip", "blip2"
]

/// Detect if a local model is a VLM by inspecting its config.json
func detectVLMFromConfig(at modelPath: URL) -> Bool {
    let configURL = modelPath.appendingPathComponent("config.json")
    
    guard let data = try? Data(contentsOf: configURL),
          let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return false
    }
    
    // Check for VLM-specific config fields
    for field in Self.vlmConfigFields {
        if config[field] != nil {
            return true
        }
    }
    
    // Check model_type against known VLM architectures
    if let modelType = config["model_type"] as? String {
        let normalized = modelType.lowercased()
            .replacingOccurrences(of: "-", with: "_")
        
        if Self.vlmArchitectures.contains(normalized) {
            return true
        }
    }
    
    return false
}

/// Detect VLM from model name heuristics (for undownloaded models)
func detectVLMFromName(_ modelId: String) -> Bool {
    let lower = modelId.lowercased()
    
    let vlmNamePatterns = [
        "llava", "vision", "vlm", "vl-", "-vl",
        "pixtral", "paligemma", "idefics", "cogvlm",
        "minicpm-v", "phi-3-vision", "mllama", "florence"
    ]
    
    return vlmNamePatterns.contains { lower.contains($0) }
}
```

---

## 4. NSCache Model Lifecycle

### Source File
**Path:** `Packages/OsaurusCore/Services/ModelRuntime.swift`  
**Size:** 18K  
**Lines:** ~18-199 (cache management section)

### Cache Structure
```swift
actor ModelRuntime {
    // MARK: - Properties
    
    /// NSCache automatically manages memory pressure eviction
    private let modelCache = NSCache<NSString, SessionHolder>()
    
    /// Track cached model IDs for iteration (NSCache doesn't support enumeration)
    private var cachedModelNames: Set<String> = []
    
    /// Currently active model
    private var currentModelName: String?
    
    /// Weights sizes for memory tracking
    private var modelWeightsSizes: [String: Int64] = [:]
    
    // MARK: - Session Holder
    
    /// Wrapper for NSCache storage (NSCache requires NSObject subclass)
    private final class SessionHolder: NSObject {
        let container: ModelContainer
        let loadedAt: Date
        let weightsSize: Int64
        
        init(container: ModelContainer, weightsSize: Int64) {
            self.container = container
            self.loadedAt = Date()
            self.weightsSize = weightsSize
            super.init()
        }
    }
}
```

### Cache Operations
**Lines:** ~80-150

```swift
// MARK: - Cache Operations

/// Get or load a model, using cache when available
func getOrLoadModel(modelId: String, modelPath: URL) async throws -> ModelContainer {
    let key = modelId as NSString
    
    // Check cache first
    if let cached = modelCache.object(forKey: key) {
        currentModelName = modelId
        return cached.container
    }
    
    // Load model
    let container = try await loadModel(from: modelPath)
    
    // Calculate weights size for cache cost
    let weightsSize = calculateWeightsSize(at: modelPath)
    
    // Store in cache with weights size as cost
    let holder = SessionHolder(container: container, weightsSize: weightsSize)
    modelCache.setObject(holder, forKey: key, cost: Int(weightsSize))
    
    // Track in our set (NSCache doesn't enumerate)
    cachedModelNames.insert(modelId)
    modelWeightsSizes[modelId] = weightsSize
    currentModelName = modelId
    
    return container
}

/// Evict a specific model from cache
func evictModel(_ modelId: String) {
    let key = modelId as NSString
    modelCache.removeObject(forKey: key)
    cachedModelNames.remove(modelId)
    modelWeightsSizes.removeValue(forKey: modelId)
    
    if currentModelName == modelId {
        currentModelName = nil
    }
}

/// Get cache statistics
func cacheStats() -> (modelCount: Int, totalWeightsBytes: Int64, modelNames: [String]) {
    let totalBytes = modelWeightsSizes.values.reduce(0, +)
    return (cachedModelNames.count, totalBytes, Array(cachedModelNames))
}

/// Calculate weights size from safetensors files
private func calculateWeightsSize(at path: URL) -> Int64 {
    let fm = FileManager.default
    var totalSize: Int64 = 0
    
    if let enumerator = fm.enumerator(at: path, includingPropertiesForKeys: [.fileSizeKey]) {
        for case let url as URL in enumerator {
            if url.pathExtension == "safetensors" {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                totalSize += Int64(size)
            }
        }
    }
    
    return totalSize
}
```

---

## 5. MLX Compatibility Validation

### Source File
**Path:** `Packages/OsaurusCore/Services/HuggingFaceService.swift`  
**Lines:** ~100-165

### Key Function: `isMLXCompatible`

```swift
/// Determine if a Hugging Face repo is MLX-compatible using repository metadata.
/// Prefers explicit tags (e.g., "mlx", "apple-mlx", "library:mlx").
/// Falls back to id hints and required file presence when tags are unavailable.
func isMLXCompatible(repoId: String) async -> Bool {
    let trimmed = repoId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    let lower = trimmed.lowercased()

    // Fetch model metadata with tags and top-level file listing
    guard let meta = await fetchModelMeta(repoId: trimmed) else {
        // Network failure: conservative allowance for mlx-community repos
        if lower.hasPrefix("mlx-community/") { return true }
        return false
    }

    // Strong signal: tags explicitly indicate MLX
    if let tags = meta.tags?.map({ $0.lowercased() }) {
        if tags.contains("mlx") || tags.contains("apple-mlx") || tags.contains("library:mlx") {
            return true
        }
    }

    // Heuristic fallback: repository naming suggests MLX and core files exist
    if lower.contains("mlx") && hasRequiredFiles(meta: meta) {
        return true
    }

    // As a last resort, trust curated org with required files
    if lower.hasPrefix("mlx-community/") && hasRequiredFiles(meta: meta) {
        return true
    }

    return false
}
```

### Required Files Validation
**Lines:** ~250-275

```swift
private func hasRequiredFiles(meta: ModelMeta) -> Bool {
    guard let siblings = meta.siblings else { return false }
    var hasConfig = false
    var hasWeights = false
    var hasTokenizer = false
    
    for s in siblings {
        let f = s.rfilename.lowercased()
        if f == "config.json" { hasConfig = true }
        if f.hasSuffix(".safetensors") { hasWeights = true }
        if f == "tokenizer.json" || f == "tokenizer.model" || f == "spiece.model" 
           || f == "vocab.json" || f == "vocab.txt" {
            hasTokenizer = true
        }
    }
    
    return hasConfig && hasWeights && hasTokenizer
}
```

### SDK Registry Check
**Path:** `Packages/OsaurusCore/Managers/ModelManager.swift`  
**Lines:** ~599-621

```swift
/// Compute the set of SDK-supported model ids from MLXLLM's registry
static func sdkSupportedModelIds() -> Set<String> {
    // The registry contains Apple-curated supported configurations.
    // We normalize to lowercase for comparison.
    var allowed: Set<String> = []
    for config in LLMRegistry.shared.models {
        allowed.insert(config.name.lowercased())
    }
    return allowed
}

/// Build MLXModel entries from the MLX registry of supported models
static func registryModels() -> [MLXModel] {
    return LLMRegistry.shared.models.map { cfg in
        let id = cfg.name
        return MLXModel(
            id: id,
            name: friendlyName(from: id),
            description: "From MLX registry",
            downloadURL: "https://huggingface.co/\(id)"
        )
    }
}
```

---

## File Summary Table

| File Path | Size | Key Features |
|-----------|------|--------------|
| `Packages/OsaurusCore/Services/HuggingFaceService.swift` | 12K | Size estimation, MLX compatibility, VLM detection, Glob matcher |
| `Packages/OsaurusCore/Services/ModelRuntime.swift` | 18K | NSCache lifecycle, warmup API, model loading |
| `Packages/OsaurusCore/Managers/ModelManager.swift` | 49K | Download progress, speed/ETA calculation, VLM config detection, SDK registry |
| `Packages/OsaurusCore/Models/MLXModel.swift` | 7K | Model type definitions |
| `Packages/OsaurusCore/Services/FoundationModelService.swift` | 20K | Apple Foundation Models integration |

---

## API Endpoints Used

| Endpoint | Purpose |
|----------|---------|
| `GET /api/models/{repo}/tree/main?recursive=1` | File listing with sizes for estimation |
| `GET /api/models/{repo}?full=1` | Model metadata, tags, pipeline_tag |
| `GET /{repo}/raw/main/config.json` | Config inspection for VLM detection |

---

## Key Patterns Summary

1. **Size Estimation**: HuggingFace tree API + glob pattern matching + LFS handling
2. **Warmup**: Minimal generation (temp=0, maxTokens=5) to trigger JIT and allocate caches
3. **VLM Detection**: Tags → Pipeline tag → Config fields → Name heuristics (layered)
4. **NSCache**: Object wrapper class, cost = weights size, track IDs separately
5. **Compatibility**: Tags > Name + Files > mlx-community trust (confidence levels)
