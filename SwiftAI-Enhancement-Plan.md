# SwiftAI Enhancement Plan: Osaurus-Inspired Improvements

> **Version:** 1.0  
> **Created:** December 2025  
> **Source Analysis:** Osaurus (dinoki-ai/osaurus) macOS LLM Server  
> **Target:** SwiftAI SDK Framework

---

## Executive Summary

This document outlines five key enhancements to SwiftAI based on patterns discovered in the Osaurus codebase. These improvements focus on robustness, performance, and developer experience—particularly around model management and MLX inference.

| Feature | Priority | Complexity | Impact |
|---------|----------|------------|--------|
| Download Size Estimation | High | Medium | Better UX, storage planning |
| Model Warmup API | High | Low | Faster first-response latency |
| VLM Detection & Routing | Medium | Medium | Automatic multimodal support |
| NSCache Model Lifecycle | Medium | High | Memory efficiency at scale |
| MLX Compatibility Validation | High | Medium | Prevent download failures |

---

## 1. Download Size Estimation

### Problem
SwiftAI's current `DownloadProgress` only tracks bytes as they download. Users cannot know the total download size before starting, making storage planning difficult and UX suboptimal.

### Osaurus Pattern
**Location:** `HuggingFaceService.swift` - `estimateTotalSize(repoId:patterns:)`

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
    
    // Parse TreeNode responses and sum sizes matching glob patterns
    let nodes = try JSONDecoder().decode([TreeNode].self, from: data)
    let total = nodes.reduce(Int64(0)) { acc, node in
        if node.type == "directory" { return acc }
        let filename = (node.path as NSString).lastPathComponent
        let matched = matchers.contains { $0.matches(filename) }
        guard matched else { return acc }
        let sz = node.size ?? node.lfs?.size ?? 0
        return acc + sz
    }
    return total
}
```

Key insights:
- Uses HuggingFace tree API with `recursive=1` parameter
- Handles both regular files and LFS (Large File Storage) sizes
- Applies glob pattern matching for selective size calculation

### SwiftAI Implementation Plan

#### 1.1 Add HuggingFace Metadata Service

**New File:** `Sources/SwiftAI/Services/HFMetadataService.swift`

```swift
/// Service for fetching HuggingFace repository metadata.
public actor HFMetadataService {
    public static let shared = HFMetadataService()
    
    // MARK: - Types
    
    /// File information from HuggingFace tree API.
    public struct RepoFile: Sendable, Decodable {
        public let path: String
        public let type: String?  // "file" or "directory"
        public let size: Int64?
        public let lfs: LFSInfo?
        
        public struct LFSInfo: Sendable, Decodable {
            public let size: Int64?
        }
        
        /// Effective size accounting for LFS.
        public var effectiveSize: Int64 {
            size ?? lfs?.size ?? 0
        }
    }
    
    /// Repository metadata summary.
    public struct RepoMetadata: Sendable {
        public let id: String
        public let files: [RepoFile]
        public let tags: [String]
        public let pipelineTag: String?
        public let modelType: String?
    }
    
    // MARK: - Size Estimation
    
    /// Estimates total download size for a model repository.
    ///
    /// - Parameters:
    ///   - repoId: HuggingFace repository ID (e.g., "mlx-community/Llama-3.2-1B-Instruct-4bit")
    ///   - patterns: Glob patterns for files to include (default: MLX patterns)
    /// - Returns: Estimated size in bytes, or nil if unavailable.
    public func estimateTotalSize(
        repoId: String,
        patterns: [String] = Self.mlxFilePatterns
    ) async -> ByteCount? {
        guard let files = await fetchFileTree(repoId: repoId) else {
            return nil
        }
        
        let matchers = patterns.compactMap { GlobMatcher($0) }
        
        let totalBytes = files
            .filter { $0.type != "directory" }
            .filter { file in
                let filename = (file.path as NSString).lastPathComponent
                return matchers.contains { $0.matches(filename) }
            }
            .reduce(Int64(0)) { $0 + $1.effectiveSize }
        
        return totalBytes > 0 ? ByteCount(totalBytes) : nil
    }
    
    /// Default file patterns for MLX model downloads.
    public static let mlxFilePatterns: [String] = [
        "*.safetensors",
        "*.json",
        "*.txt",
        "*.model",
        "*.tiktoken"
    ]
    
    // MARK: - Private
    
    private func fetchFileTree(repoId: String) async -> [RepoFile]? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "huggingface.co"
        components.path = "/api/models/\(repoId)/tree/main"
        components.queryItems = [URLQueryItem(name: "recursive", value: "1")]
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode([RepoFile].self, from: data)
        } catch {
            return nil
        }
    }
}
```

#### 1.2 Add Glob Matcher Utility

**New File:** `Sources/SwiftAI/Utilities/GlobMatcher.swift`

```swift
/// Simple glob pattern matcher supporting * and ? wildcards.
public struct GlobMatcher: Sendable {
    private let regex: NSRegularExpression
    
    public init?(_ pattern: String) {
        var escaped = ""
        for char in pattern {
            switch char {
            case "*": escaped += ".*"
            case "?": escaped += "."
            case ".", "+", "(", ")", "[", "]", "{", "}", "^", "$", "|", "\\":
                escaped += "\\\(char)"
            default:
                escaped += String(char)
            }
        }
        
        do {
            regex = try NSRegularExpression(pattern: "^\(escaped)$")
        } catch {
            return nil
        }
    }
    
    public func matches(_ text: String) -> Bool {
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
```

#### 1.3 Enhance DownloadProgress

**Update:** `Sources/SwiftAI/ModelManagement/DownloadProgress.swift`

```swift
/// Download progress information with ETA calculation.
public struct DownloadProgress: Sendable {
    /// Bytes downloaded so far.
    public var bytesDownloaded: Int64 = 0
    
    /// Total bytes to download (estimated before download, actual during).
    public var totalBytes: Int64?
    
    /// Current file being downloaded.
    public var currentFile: String?
    
    /// Files completed / total files.
    public var filesCompleted: Int = 0
    public var totalFiles: Int = 0
    
    /// Download speed in bytes per second (rolling average).
    public var bytesPerSecond: Double?
    
    /// Estimated time remaining in seconds.
    public var estimatedTimeRemaining: TimeInterval? {
        guard let speed = bytesPerSecond, speed > 0,
              let total = totalBytes else {
            return nil
        }
        let remaining = total - bytesDownloaded
        return TimeInterval(remaining) / speed
    }
    
    /// Fraction completed (0.0 to 1.0).
    public var fractionCompleted: Double {
        guard let total = totalBytes, total > 0 else {
            return totalFiles > 0 ? Double(filesCompleted) / Double(totalFiles) : 0
        }
        return Double(bytesDownloaded) / Double(total)
    }
    
    /// Formatted ETA string (e.g., "2m 30s").
    public var formattedETA: String? {
        guard let eta = estimatedTimeRemaining else { return nil }
        if eta < 60 {
            return "\(Int(eta))s"
        } else if eta < 3600 {
            let minutes = Int(eta) / 60
            let seconds = Int(eta) % 60
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(eta) / 3600
            let minutes = (Int(eta) % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
}
```

#### 1.4 Add Speed Calculator

**New File:** `Sources/SwiftAI/ModelManagement/SpeedCalculator.swift`

```swift
/// Calculates rolling average download speed using sliding window.
actor SpeedCalculator {
    private struct Sample: Sendable {
        let timestamp: Date
        let bytes: Int64
    }
    
    private var samples: [Sample] = []
    private let windowDuration: TimeInterval = 5.0  // 5-second sliding window
    
    func addSample(bytes: Int64) {
        let now = Date()
        samples.append(Sample(timestamp: now, bytes: bytes))
        
        // Remove samples outside window
        let cutoff = now.addingTimeInterval(-windowDuration)
        samples.removeAll { $0.timestamp < cutoff }
    }
    
    func averageSpeed() -> Double? {
        guard samples.count >= 2 else { return nil }
        
        let oldest = samples.first!
        let newest = samples.last!
        
        let duration = newest.timestamp.timeIntervalSince(oldest.timestamp)
        guard duration > 0 else { return nil }
        
        let totalBytes = newest.bytes - oldest.bytes
        return Double(totalBytes) / duration
    }
    
    func reset() {
        samples.removeAll()
    }
}
```

#### 1.5 Update ModelManager

**Update:** `Sources/SwiftAI/ModelManagement/ModelManager.swift`

```swift
extension ModelManager {
    
    /// Estimates download size before starting download.
    ///
    /// - Parameter model: The model to check.
    /// - Returns: Estimated download size, or nil if unavailable.
    public func estimateDownloadSize(_ model: ModelIdentifier) async -> ByteCount? {
        guard case .mlx(let repoId) = model else {
            // HuggingFace cloud and Foundation Models don't need downloads
            return nil
        }
        
        return await HFMetadataService.shared.estimateTotalSize(repoId: repoId)
    }
    
    /// Downloads a model with pre-fetched size estimation.
    ///
    /// - Parameters:
    ///   - model: The model to download.
    ///   - progress: Progress callback with accurate total size.
    /// - Returns: Local URL of the downloaded model.
    public func downloadWithEstimation(
        _ model: ModelIdentifier,
        progress: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        // Pre-fetch estimated size
        let estimatedSize = await estimateDownloadSize(model)
        
        var currentProgress = DownloadProgress()
        currentProgress.totalBytes = estimatedSize?.bytes
        
        // Start download with size-aware progress
        return try await download(model) { downloadProgress in
            var enrichedProgress = downloadProgress
            if enrichedProgress.totalBytes == nil {
                enrichedProgress.totalBytes = estimatedSize?.bytes
            }
            progress?(enrichedProgress)
        }
    }
}
```

#### 1.6 Usage Example

```swift
let manager = ModelManager.shared

// Check size before downloading
if let size = await manager.estimateDownloadSize(.llama3_2_1B) {
    print("Model size: \(size.formatted)")  // "2.4 GB"
    
    // Check available storage
    let availableSpace = try FileManager.default.availableCapacity(forUsage: .opportunistic)
    if availableSpace < size.bytes {
        print("Insufficient storage space")
        return
    }
}

// Download with accurate progress
let url = try await manager.downloadWithEstimation(.llama3_2_1B) { progress in
    print("Progress: \(Int(progress.fractionCompleted * 100))%")
    if let eta = progress.formattedETA {
        print("ETA: \(eta)")
    }
    if let speed = progress.bytesPerSecond {
        print("Speed: \(ByteCount(Int64(speed)).formatted)/s")
    }
}
```

---

## 2. Model Warmup API

### Problem
The first inference request after loading a model has significantly higher latency due to lazy initialization of internal buffers, KV cache allocation, and JIT compilation.

### Osaurus Pattern
**Location:** `ModelRuntime.swift` - `warmUp(modelId:modelName:prefillChars:maxTokens:)`

Osaurus pre-runs a short generation to "warm up" the model, filling internal caches and triggering any lazy initialization.

### SwiftAI Implementation Plan

#### 2.1 Add Warmup Protocol Extension

**Update:** `Sources/SwiftAI/Core/Protocols/AIProvider.swift`

```swift
extension AIProvider where Self: TextGenerator {
    
    /// Warms up the model by running a short prefill generation.
    ///
    /// Call this after loading a model but before user-facing inference
    /// to minimize first-response latency.
    ///
    /// - Parameters:
    ///   - model: The model to warm up.
    ///   - prefillText: Text to use for warmup generation (default: short prompt).
    ///   - maxTokens: Maximum tokens to generate during warmup (default: 1).
    public func warmUp(
        model: ModelID,
        prefillText: String = "Hello",
        maxTokens: Int = 1
    ) async throws {
        let config = GenerateConfig(maxTokens: maxTokens, temperature: 0)
        _ = try await generate(prefillText, model: model, config: config)
    }
}
```

#### 2.2 Add MLX-Specific Warmup

**Update:** `Sources/SwiftAI/Providers/MLX/MLXProvider.swift`

```swift
extension MLXProvider {
    
    /// Warms up an MLX model with configurable prefill.
    ///
    /// This method:
    /// 1. Loads the model if not already loaded
    /// 2. Allocates and pre-fills the KV cache
    /// 3. Triggers JIT compilation of compute graphs
    /// 4. Optionally keeps the model in memory
    ///
    /// - Parameters:
    ///   - model: The model to warm up.
    ///   - prefillChars: Number of characters in warmup prompt (affects cache size).
    ///   - maxTokens: Tokens to generate (more = deeper warmup).
    ///   - keepLoaded: Whether to keep model in memory after warmup.
    public func warmUp(
        model: ModelID,
        prefillChars: Int = 50,
        maxTokens: Int = 5,
        keepLoaded: Bool = true
    ) async throws {
        // Generate a prefill prompt of the specified length
        let prefillText = String(repeating: "The quick brown fox jumps over the lazy dog. ", 
                                  count: max(1, prefillChars / 45))
            .prefix(prefillChars)
        
        let config = GenerateConfig(
            maxTokens: maxTokens,
            temperature: 0  // Deterministic for consistent warmup
        )
        
        // Run warmup generation
        _ = try await generate(String(prefillText), model: model, config: config)
        
        // Model is now warm and loaded
        if !keepLoaded {
            await unloadModel(model)
        }
    }
    
    /// Unloads a model from memory.
    public func unloadModel(_ model: ModelID) async {
        if loadedModel?.modelId == model {
            loadedModel = nil
        }
    }
}
```

#### 2.3 Add Foundation Models Warmup

**Update:** `Sources/SwiftAI/Providers/FoundationModels/FoundationModelsProvider.swift`

```swift
@available(iOS 26.0, macOS 26.0, *)
extension FoundationModelsProvider {
    
    /// Prewarms the Foundation Models session.
    ///
    /// Apple's Foundation Models framework supports native prewarming
    /// for faster first-response latency.
    ///
    /// - Parameter promptPrefix: Optional prompt prefix to optimize for.
    public func warmUp(promptPrefix: String? = nil) async {
        let session = getOrCreateSession()
        await session.prewarm(promptPrefix: promptPrefix)
    }
}
```

#### 2.4 Add ChatSession Auto-Warmup Option

**Update:** `Sources/SwiftAI/Core/Types/ChatSession.swift`

```swift
extension ChatSession {
    
    /// Configuration for automatic model warmup.
    public struct WarmupConfig: Sendable {
        /// Whether to warm up the model on session creation.
        public var warmupOnInit: Bool = false
        
        /// Number of prefill characters for warmup.
        public var prefillChars: Int = 50
        
        /// Tokens to generate during warmup.
        public var warmupTokens: Int = 5
        
        public static let `default` = WarmupConfig()
        public static let eager = WarmupConfig(warmupOnInit: true)
    }
    
    /// Creates a session with optional automatic warmup.
    public convenience init(
        provider: Provider,
        model: Provider.ModelID,
        config: GenerateConfig = .default,
        warmup: WarmupConfig = .default
    ) async throws {
        self.init(provider: provider, model: model, config: config)
        
        if warmup.warmupOnInit {
            try await self.warmUp(
                prefillChars: warmup.prefillChars,
                maxTokens: warmup.warmupTokens
            )
        }
    }
    
    /// Warms up the model for this session.
    public func warmUp(prefillChars: Int = 50, maxTokens: Int = 5) async throws {
        if let mlxProvider = provider as? MLXProvider {
            try await mlxProvider.warmUp(
                model: model as! ModelIdentifier,
                prefillChars: prefillChars,
                maxTokens: maxTokens
            )
        } else {
            try await provider.warmUp(model: model, maxTokens: maxTokens)
        }
    }
}
```

#### 2.5 Usage Example

```swift
let provider = MLXProvider()

// Manual warmup
try await provider.warmUp(
    model: .llama3_2_1B,
    prefillChars: 100,  // Longer warmup for chat use case
    maxTokens: 10
)

// First user request is now fast
let response = try await provider.generate(
    "Hello!",
    model: .llama3_2_1B,
    config: .default
)

// Or use ChatSession with auto-warmup
let session = try await ChatSession(
    provider: provider,
    model: .llama3_2_1B,
    warmup: .eager
)
```

---

## 3. VLM Detection and Routing

### Problem
Vision Language Models (VLMs) require different loading and inference paths than text-only LLMs. SwiftAI currently doesn't distinguish between them, potentially leading to runtime failures.

### Osaurus Pattern
**Location:** `ModelManager.swift` (lines 1091-1201) and `HuggingFaceService.swift`

Osaurus uses multiple detection strategies:
1. **Config-based:** Checks `config.json` for vision-related fields
2. **Metadata-based:** Checks HuggingFace tags and pipeline type
3. **Name-based:** Heuristic for known VLM architectures

```swift
// Config.json fields indicating VLM
let vlmConfigFields = [
    "vision_config", "image_processor", "vision_encoder", 
    "vision_tower", "image_encoder", "patch_size", "num_image_tokens"
]

// Known VLM architectures
let vlmArchitectures = [
    "llava", "llava_next", "qwen2_vl", "pixtral", "paligemma",
    "idefics", "internvl", "cogvlm", "minicpm_v", "phi3_v",
    "mllama", "florence", "blip"
]
```

### SwiftAI Implementation Plan

#### 3.1 Add Model Capabilities Type

**New File:** `Sources/SwiftAI/Core/Types/ModelCapabilities.swift`

```swift
/// Capabilities of a model determined through detection.
public struct ModelCapabilities: Sendable, Hashable {
    /// Whether the model supports vision/image input.
    public let supportsVision: Bool
    
    /// Whether the model supports text generation.
    public let supportsTextGeneration: Bool
    
    /// Whether the model supports embeddings.
    public let supportsEmbeddings: Bool
    
    /// The detected model architecture type.
    public let architectureType: ArchitectureType?
    
    /// Recommended context window size.
    public let contextWindowSize: Int?
    
    /// Standard text-only LLM capabilities.
    public static let textOnly = ModelCapabilities(
        supportsVision: false,
        supportsTextGeneration: true,
        supportsEmbeddings: false,
        architectureType: nil,
        contextWindowSize: nil
    )
    
    /// Vision Language Model capabilities.
    public static let vlm = ModelCapabilities(
        supportsVision: true,
        supportsTextGeneration: true,
        supportsEmbeddings: false,
        architectureType: .vlm,
        contextWindowSize: nil
    )
}

/// Model architecture types.
public enum ArchitectureType: String, Sendable, Codable, CaseIterable {
    // Text-only
    case llama
    case mistral
    case qwen
    case phi
    case gemma
    
    // Vision
    case vlm
    case llava
    case qwen2VL = "qwen2_vl"
    case pixtral
    case paligemma
    case idefics
    case mllama
    
    // Embedding
    case bert
    case bge
    case nomic
    
    /// Whether this architecture supports vision input.
    public var supportsVision: Bool {
        switch self {
        case .vlm, .llava, .qwen2VL, .pixtral, .paligemma, .idefics, .mllama:
            return true
        default:
            return false
        }
    }
}
```

#### 3.2 Add VLM Detector Service

**New File:** `Sources/SwiftAI/Services/VLMDetector.swift`

```swift
/// Service for detecting Vision Language Model capabilities.
public actor VLMDetector {
    public static let shared = VLMDetector()
    
    // MARK: - Detection Fields
    
    /// Config.json fields that indicate VLM capabilities.
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
    
    /// Known VLM architecture types in model_type field.
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
    
    // MARK: - Detection Methods
    
    /// Detects model capabilities from HuggingFace metadata.
    ///
    /// - Parameter model: The model identifier to check.
    /// - Returns: Detected capabilities.
    public func detectCapabilities(_ model: ModelIdentifier) async -> ModelCapabilities {
        guard case .mlx(let repoId) = model else {
            // Non-MLX models have different detection paths
            return .textOnly
        }
        
        // Try metadata-based detection first (faster)
        if let metaCapabilities = await detectFromMetadata(repoId: repoId) {
            return metaCapabilities
        }
        
        // Fall back to config.json inspection
        if let configCapabilities = await detectFromConfig(repoId: repoId) {
            return configCapabilities
        }
        
        // Last resort: name-based heuristics
        return detectFromName(repoId: repoId)
    }
    
    /// Checks if a model is a VLM (convenience method).
    public func isVLM(_ model: ModelIdentifier) async -> Bool {
        await detectCapabilities(model).supportsVision
    }
    
    // MARK: - Private Detection Methods
    
    private func detectFromMetadata(repoId: String) async -> ModelCapabilities? {
        guard let details = await HFMetadataService.shared.fetchModelDetails(repoId: repoId) else {
            return nil
        }
        
        // Check pipeline tag
        if let pipeline = details.pipelineTag?.lowercased() {
            let vlmPipelines = [
                "image-to-text",
                "visual-question-answering", 
                "image-text-to-text",
                "document-question-answering"
            ]
            if vlmPipelines.contains(pipeline) {
                return .vlm
            }
        }
        
        // Check tags
        let lowerTags = details.tags.map { $0.lowercased() }
        let vlmTagIndicators = ["vision", "multimodal", "vlm", "image-text", "llava", "vqa"]
        
        for indicator in vlmTagIndicators {
            if lowerTags.contains(where: { $0.contains(indicator) }) {
                return .vlm
            }
        }
        
        return nil
    }
    
    private func detectFromConfig(repoId: String) async -> ModelCapabilities? {
        // Fetch config.json content
        guard let configData = await fetchConfigJSON(repoId: repoId),
              let config = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] else {
            return nil
        }
        
        // Check for VLM config fields
        for field in Self.vlmConfigFields {
            if config[field] != nil {
                let architecture = detectArchitecture(from: config)
                return ModelCapabilities(
                    supportsVision: true,
                    supportsTextGeneration: true,
                    supportsEmbeddings: false,
                    architectureType: architecture,
                    contextWindowSize: config["max_position_embeddings"] as? Int
                )
            }
        }
        
        // Check model_type for known VLM architectures
        if let modelType = config["model_type"] as? String {
            let normalized = modelType.lowercased().replacingOccurrences(of: "-", with: "_")
            if Self.vlmArchitectures.contains(normalized) {
                return .vlm
            }
        }
        
        return nil
    }
    
    private func detectFromName(repoId: String) -> ModelCapabilities {
        let lower = repoId.lowercased()
        
        // Check for VLM indicators in name
        let vlmNamePatterns = [
            "llava", "vision", "vlm", "vl-", "-vl",
            "pixtral", "paligemma", "idefics", "cogvlm",
            "minicpm-v", "phi-3-vision", "mllama", "florence"
        ]
        
        for pattern in vlmNamePatterns {
            if lower.contains(pattern) {
                return .vlm
            }
        }
        
        return .textOnly
    }
    
    private func detectArchitecture(from config: [String: Any]) -> ArchitectureType? {
        guard let modelType = config["model_type"] as? String else {
            return nil
        }
        
        let normalized = modelType.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
        
        // Map to known architectures
        if normalized.contains("llava") { return .llava }
        if normalized.contains("qwen") && normalized.contains("vl") { return .qwen2VL }
        if normalized.contains("pixtral") { return .pixtral }
        if normalized.contains("paligemma") { return .paligemma }
        if normalized.contains("idefics") { return .idefics }
        if normalized.contains("mllama") { return .mllama }
        
        return nil
    }
    
    private func fetchConfigJSON(repoId: String) async -> Data? {
        let url = URL(string: "https://huggingface.co/\(repoId)/raw/main/config.json")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }
}
```

#### 3.3 Update MLXProvider with Automatic Routing

**Update:** `Sources/SwiftAI/Providers/MLX/MLXProvider.swift`

```swift
extension MLXProvider {
    
    /// Loads the appropriate model container based on detected capabilities.
    private func loadModelContainer(_ model: ModelID) async throws -> ModelContainer {
        // Check if already loaded
        if let loaded = loadedModel, loaded.modelId == model {
            return loaded.container
        }
        
        // Ensure model is downloaded
        guard let localPath = await modelManager.localPath(for: model) else {
            throw AIError.modelNotCached(model)
        }
        
        // Detect model capabilities
        let capabilities = await VLMDetector.shared.detectCapabilities(model)
        
        // Load using appropriate factory
        let configuration = ModelConfiguration(id: model.rawValue)
        let container: ModelContainer
        
        if capabilities.supportsVision {
            // Use VLM factory for vision models
            container = try await VLMModelFactory.shared.loadContainer(
                configuration: configuration
            ) { progress in
                // Loading progress
            }
        } else {
            // Use standard LLM factory
            container = try await LLMModelFactory.shared.loadContainer(
                configuration: configuration
            ) { progress in
                // Loading progress
            }
        }
        
        loadedModel = LoadedModel(
            modelId: model, 
            container: container,
            capabilities: capabilities
        )
        
        return container
    }
}
```

#### 3.4 Usage Example

```swift
let detector = VLMDetector.shared

// Check model capabilities before loading
let capabilities = await detector.detectCapabilities(.mlx("mlx-community/llava-1.5-7b-4bit"))
if capabilities.supportsVision {
    print("This model supports image input!")
}

// Provider automatically routes to correct factory
let provider = MLXProvider()
let response = try await provider.generate(
    messages: [
        .user(content: .parts([
            .text("What's in this image?"),
            .image(ImageContent(base64Data: imageData))
        ]))
    ],
    model: .mlx("mlx-community/llava-1.5-7b-4bit"),
    config: .default
)
```

---

## 4. NSCache Model Lifecycle

### Problem
SwiftAI's current `loadedModel` field holds only one model at a time. Switching between models requires full unload/reload cycles. Under memory pressure, there's no automatic eviction.

### Osaurus Pattern
**Location:** `ModelRuntime.swift` (lines 18-199)

```swift
actor ModelRuntime {
    private let modelCache = NSCache<NSString, SessionHolder>()
    private var cachedModelNames: Set<String> = []
    private var currentModelName: String?
    
    // NSCache automatically evicts under memory pressure
    // Tracks weights size per model for monitoring
}
```

Key benefits:
- Multiple models can be cached simultaneously
- Automatic memory pressure eviction
- LRU-like behavior without manual tracking

### SwiftAI Implementation Plan

#### 4.1 Add ModelCache Actor

**New File:** `Sources/SwiftAI/Providers/MLX/MLXModelCache.swift`

```swift
import Foundation

/// Thread-safe cache for loaded MLX models with automatic memory management.
///
/// Uses NSCache internally for automatic eviction under memory pressure.
/// Tracks model sizes and provides manual eviction controls.
actor MLXModelCache {
    
    // MARK: - Types
    
    /// Wrapper to hold model container in NSCache.
    private final class CachedModel: NSObject {
        let container: ModelContainer
        let capabilities: ModelCapabilities
        let loadedAt: Date
        let weightsSize: ByteCount
        
        init(
            container: ModelContainer,
            capabilities: ModelCapabilities,
            weightsSize: ByteCount
        ) {
            self.container = container
            self.capabilities = capabilities
            self.loadedAt = Date()
            self.weightsSize = weightsSize
            super.init()
        }
    }
    
    /// Cache statistics.
    public struct CacheStats: Sendable {
        public let modelCount: Int
        public let totalWeightsSize: ByteCount
        public let modelNames: [String]
    }
    
    // MARK: - Properties
    
    private let cache: NSCache<NSString, CachedModel>
    private var cachedModelIds: Set<String> = []
    private var modelSizes: [String: ByteCount] = [:]
    private var currentModelId: String?
    
    // MARK: - Initialization
    
    init(countLimit: Int = 3, totalCostLimit: Int = 0) {
        self.cache = NSCache()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }
    
    // MARK: - Public API
    
    /// Retrieves a cached model, or nil if not cached.
    func get(_ modelId: ModelIdentifier) -> (container: ModelContainer, capabilities: ModelCapabilities)? {
        let key = modelId.rawValue as NSString
        guard let cached = cache.object(forKey: key) else {
            return nil
        }
        currentModelId = modelId.rawValue
        return (cached.container, cached.capabilities)
    }
    
    /// Caches a loaded model.
    func set(
        _ modelId: ModelIdentifier,
        container: ModelContainer,
        capabilities: ModelCapabilities,
        weightsSize: ByteCount
    ) {
        let key = modelId.rawValue as NSString
        let cached = CachedModel(
            container: container,
            capabilities: capabilities,
            weightsSize: weightsSize
        )
        
        // Use weights size as cost for NSCache's cost-based eviction
        cache.setObject(cached, forKey: key, cost: Int(weightsSize.bytes))
        
        cachedModelIds.insert(modelId.rawValue)
        modelSizes[modelId.rawValue] = weightsSize
        currentModelId = modelId.rawValue
    }
    
    /// Removes a specific model from cache.
    func remove(_ modelId: ModelIdentifier) {
        let key = modelId.rawValue as NSString
        cache.removeObject(forKey: key)
        cachedModelIds.remove(modelId.rawValue)
        modelSizes.removeValue(forKey: modelId.rawValue)
        
        if currentModelId == modelId.rawValue {
            currentModelId = nil
        }
    }
    
    /// Clears all cached models.
    func removeAll() {
        cache.removeAllObjects()
        cachedModelIds.removeAll()
        modelSizes.removeAll()
        currentModelId = nil
    }
    
    /// Checks if a model is currently cached.
    func contains(_ modelId: ModelIdentifier) -> Bool {
        cachedModelIds.contains(modelId.rawValue)
    }
    
    /// Returns cache statistics.
    func stats() -> CacheStats {
        let totalSize = modelSizes.values.reduce(ByteCount(0)) { 
            ByteCount($0.bytes + $1.bytes) 
        }
        
        return CacheStats(
            modelCount: cachedModelIds.count,
            totalWeightsSize: totalSize,
            modelNames: Array(cachedModelIds)
        )
    }
    
    /// The currently active model ID.
    var currentModel: String? {
        currentModelId
    }
}
```

#### 4.2 Update MLXProvider to Use Cache

**Update:** `Sources/SwiftAI/Providers/MLX/MLXProvider.swift`

```swift
public actor MLXProvider: AIProvider, TextGenerator, EmbeddingGenerator, TokenCounter {
    
    // MARK: - Properties
    
    private let modelManager: ModelManager
    private let modelCache: MLXModelCache  // Replace single loadedModel
    private var loadedEmbedder: LoadedEmbedder?
    private let configuration: MLXConfiguration
    
    // MARK: - Initialization
    
    public init(
        configuration: MLXConfiguration = .default,
        modelManager: ModelManager = .shared
    ) {
        self.configuration = configuration
        self.modelManager = modelManager
        self.modelCache = MLXModelCache(
            countLimit: configuration.maxCachedModels,
            totalCostLimit: Int(configuration.maxCacheSize?.bytes ?? 0)
        )
    }
    
    // MARK: - Model Loading
    
    private func loadModelContainer(_ model: ModelID) async throws -> ModelContainer {
        // Check cache first
        if let cached = modelCache.get(model) {
            return cached.container
        }
        
        // Ensure model is downloaded
        guard let localPath = await modelManager.localPath(for: model) else {
            throw AIError.modelNotCached(model)
        }
        
        // Detect capabilities
        let capabilities = await VLMDetector.shared.detectCapabilities(model)
        
        // Load model
        let configuration = ModelConfiguration(id: model.rawValue)
        let container: ModelContainer
        
        if capabilities.supportsVision {
            container = try await VLMModelFactory.shared.loadContainer(
                configuration: configuration
            ) { _ in }
        } else {
            container = try await LLMModelFactory.shared.loadContainer(
                configuration: configuration
            ) { _ in }
        }
        
        // Estimate weights size for cache cost
        let weightsSize = estimateWeightsSize(at: localPath)
        
        // Cache the loaded model
        modelCache.set(
            model,
            container: container,
            capabilities: capabilities,
            weightsSize: weightsSize
        )
        
        return container
    }
    
    private func estimateWeightsSize(at path: URL) -> ByteCount {
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
        
        return ByteCount(totalSize)
    }
    
    // MARK: - Cache Management
    
    /// Returns cache statistics.
    public var cacheStats: MLXModelCache.CacheStats {
        get async {
            await modelCache.stats()
        }
    }
    
    /// Manually evicts a model from cache.
    public func evictModel(_ model: ModelID) async {
        await modelCache.remove(model)
    }
    
    /// Clears all cached models.
    public func clearCache() async {
        await modelCache.removeAll()
    }
}
```

#### 4.3 Update MLXConfiguration

**Update:** `Sources/SwiftAI/Providers/MLX/MLXConfiguration.swift`

```swift
/// MLX-specific configuration.
public struct MLXConfiguration: Sendable {
    /// Memory limit for model loading.
    public var memoryLimit: ByteCount?
    
    /// Whether to use quantized models.
    public var preferQuantized: Bool
    
    /// Maximum number of models to keep in cache.
    public var maxCachedModels: Int
    
    /// Maximum total cache size (0 = unlimited).
    public var maxCacheSize: ByteCount?
    
    /// Default configuration.
    public static let `default` = MLXConfiguration(
        memoryLimit: nil,
        preferQuantized: true,
        maxCachedModels: 3,
        maxCacheSize: nil
    )
    
    /// Memory-constrained configuration (single model).
    public static let lowMemory = MLXConfiguration(
        memoryLimit: .gigabytes(4),
        preferQuantized: true,
        maxCachedModels: 1,
        maxCacheSize: .gigabytes(4)
    )
}
```

#### 4.4 Usage Example

```swift
// Configure for multi-model caching
let config = MLXConfiguration(
    maxCachedModels: 3,
    maxCacheSize: .gigabytes(16)
)
let provider = MLXProvider(configuration: config)

// First model loads and caches
let response1 = try await provider.generate(
    "Hello!",
    model: .llama3_2_1B,
    config: .default
)

// Second model loads, first stays cached
let response2 = try await provider.generate(
    "Bonjour!",
    model: .phi4,
    config: .default
)

// First model served from cache (fast!)
let response3 = try await provider.generate(
    "How are you?",
    model: .llama3_2_1B,
    config: .default
)

// Check cache stats
let stats = await provider.cacheStats
print("Cached models: \(stats.modelCount)")
print("Total cache size: \(stats.totalWeightsSize.formatted)")

// Manual eviction if needed
await provider.evictModel(.phi4)
```

---

## 5. MLX Compatibility Validation

### Problem
Users can attempt to download any HuggingFace model, but many won't work with MLX. Failed downloads waste bandwidth and storage, and cryptic errors frustrate users.

### Osaurus Pattern
**Location:** `HuggingFaceService.swift` - `isMLXCompatible(repoId:)`

Multi-layered validation:
1. **Tag-based:** Check for "mlx", "apple-mlx", "library:mlx" tags
2. **File-based:** Verify presence of config.json, *.safetensors, tokenizer
3. **Name-based:** Trust mlx-community repositories with required files

```swift
func isMLXCompatible(repoId: String) async -> Bool {
    // Strong signal: tags explicitly indicate MLX
    if let tags = meta.tags?.map({ $0.lowercased() }) {
        if tags.contains("mlx") || tags.contains("apple-mlx") || tags.contains("library:mlx") {
            return true
        }
    }
    
    // Heuristic fallback: naming + required files
    if lower.contains("mlx") && hasRequiredFiles(meta: meta) {
        return true
    }
    
    // Trust curated org with required files
    if lower.hasPrefix("mlx-community/") && hasRequiredFiles(meta: meta) {
        return true
    }
    
    return false
}

private func hasRequiredFiles(meta: ModelMeta) -> Bool {
    var hasConfig = false
    var hasWeights = false
    var hasTokenizer = false
    
    for file in siblings {
        if file == "config.json" { hasConfig = true }
        if file.hasSuffix(".safetensors") { hasWeights = true }
        if file == "tokenizer.json" || file == "tokenizer.model" || 
           file == "spiece.model" || file == "vocab.json" || file == "vocab.txt" {
            hasTokenizer = true
        }
    }
    
    return hasConfig && hasWeights && hasTokenizer
}
```

### SwiftAI Implementation Plan

#### 5.1 Add MLX Compatibility Checker

**New File:** `Sources/SwiftAI/Services/MLXCompatibilityChecker.swift`

```swift
/// Service for validating MLX model compatibility before download.
public actor MLXCompatibilityChecker {
    public static let shared = MLXCompatibilityChecker()
    
    // MARK: - Types
    
    /// Result of compatibility check.
    public enum CompatibilityResult: Sendable {
        /// Model is compatible with MLX.
        case compatible(confidence: Confidence)
        
        /// Model is not compatible.
        case incompatible(reasons: [IncompatibilityReason])
        
        /// Could not determine compatibility (network error, etc.).
        case unknown(Error?)
        
        public enum Confidence: Sendable {
            case high    // Explicit MLX tags
            case medium  // Naming + files suggest MLX
            case low     // Only basic requirements met
        }
    }
    
    /// Reasons why a model may be incompatible.
    public enum IncompatibilityReason: Sendable, CustomStringConvertible {
        case missingConfigJSON
        case missingWeights
        case missingTokenizer
        case unsupportedArchitecture(String)
        case notMLXOptimized
        case unknownFormat
        
        public var description: String {
            switch self {
            case .missingConfigJSON:
                return "Missing config.json file"
            case .missingWeights:
                return "Missing .safetensors weight files"
            case .missingTokenizer:
                return "Missing tokenizer files (tokenizer.json, tokenizer.model, vocab.json, etc.)"
            case .unsupportedArchitecture(let arch):
                return "Unsupported architecture: \(arch)"
            case .notMLXOptimized:
                return "Model not optimized for MLX (consider using mlx-community version)"
            case .unknownFormat:
                return "Unknown model format"
            }
        }
    }
    
    // MARK: - Required Files
    
    /// Valid tokenizer file names.
    private static let tokenizerFiles: Set<String> = [
        "tokenizer.json",      // HuggingFace consolidated
        "tokenizer.model",     // SentencePiece
        "spiece.model",        // SentencePiece alternate
        "vocab.json",          // BPE vocab
        "vocab.txt",           // WordPiece vocab
        "merges.txt"           // BPE merges (with vocab.json)
    ]
    
    /// Architectures known to work with MLX.
    private static let supportedArchitectures: Set<String> = [
        "llama", "mistral", "mixtral", "qwen", "qwen2",
        "phi", "phi3", "gemma", "gemma2", "starcoder",
        "codellama", "deepseek", "yi", "internlm",
        "baichuan", "chatglm", "falcon", "mpt",
        // VLM architectures
        "llava", "llava_next", "qwen2_vl", "pixtral", "paligemma"
    ]
    
    // MARK: - Public API
    
    /// Checks if a model is compatible with MLX.
    ///
    /// - Parameter model: The model identifier to check.
    /// - Returns: Compatibility result with confidence or reasons for incompatibility.
    public func checkCompatibility(_ model: ModelIdentifier) async -> CompatibilityResult {
        guard case .mlx(let repoId) = model else {
            return .incompatible(reasons: [.notMLXOptimized])
        }
        
        return await checkCompatibility(repoId: repoId)
    }
    
    /// Checks compatibility by repository ID.
    public func checkCompatibility(repoId: String) async -> CompatibilityResult {
        let trimmed = repoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .incompatible(reasons: [.unknownFormat])
        }
        
        let lower = trimmed.lowercased()
        
        // Fetch metadata
        guard let metadata = await HFMetadataService.shared.fetchRepoMetadata(repoId: trimmed) else {
            // Network failure: use heuristics
            if lower.hasPrefix("mlx-community/") {
                return .compatible(confidence: .medium)
            }
            return .unknown(nil)
        }
        
        // Check explicit MLX tags (high confidence)
        let lowerTags = metadata.tags.map { $0.lowercased() }
        if lowerTags.contains("mlx") || 
           lowerTags.contains("apple-mlx") || 
           lowerTags.contains("library:mlx") {
            return .compatible(confidence: .high)
        }
        
        // Validate required files
        let fileValidation = validateRequiredFiles(metadata.files)
        if !fileValidation.reasons.isEmpty {
            return .incompatible(reasons: fileValidation.reasons)
        }
        
        // Check architecture compatibility
        if let modelType = metadata.modelType {
            let normalized = modelType.lowercased()
                .replacingOccurrences(of: "-", with: "_")
            
            if !Self.supportedArchitectures.contains(where: { normalized.contains($0) }) {
                return .incompatible(reasons: [.unsupportedArchitecture(modelType)])
            }
        }
        
        // MLX naming or mlx-community with required files (medium confidence)
        if lower.contains("mlx") || lower.hasPrefix("mlx-community/") {
            return .compatible(confidence: .medium)
        }
        
        // Has required files but no explicit MLX indicator (low confidence)
        return .compatible(confidence: .low)
    }
    
    /// Convenience method for boolean compatibility check.
    public func isCompatible(_ model: ModelIdentifier) async -> Bool {
        let result = await checkCompatibility(model)
        switch result {
        case .compatible: return true
        case .incompatible, .unknown: return false
        }
    }
    
    // MARK: - Private
    
    private struct FileValidationResult {
        var hasConfig: Bool = false
        var hasWeights: Bool = false
        var hasTokenizer: Bool = false
        
        var reasons: [IncompatibilityReason] {
            var result: [IncompatibilityReason] = []
            if !hasConfig { result.append(.missingConfigJSON) }
            if !hasWeights { result.append(.missingWeights) }
            if !hasTokenizer { result.append(.missingTokenizer) }
            return result
        }
    }
    
    private func validateRequiredFiles(_ files: [HFMetadataService.RepoFile]) -> FileValidationResult {
        var result = FileValidationResult()
        
        for file in files {
            let filename = (file.path as NSString).lastPathComponent.lowercased()
            
            if filename == "config.json" {
                result.hasConfig = true
            }
            
            if filename.hasSuffix(".safetensors") {
                result.hasWeights = true
            }
            
            if Self.tokenizerFiles.contains(filename) {
                result.hasTokenizer = true
            }
        }
        
        return result
    }
}
```

#### 5.2 Integrate with ModelManager

**Update:** `Sources/SwiftAI/ModelManagement/ModelManager.swift`

```swift
extension ModelManager {
    
    /// Downloads a model after validating MLX compatibility.
    ///
    /// - Parameters:
    ///   - model: The model to download.
    ///   - skipValidation: If true, skips compatibility check.
    ///   - progress: Progress callback.
    /// - Returns: Local URL of the downloaded model.
    /// - Throws: `AIError.incompatibleModel` if validation fails.
    public func downloadValidated(
        _ model: ModelIdentifier,
        skipValidation: Bool = false,
        progress: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        // Skip validation for non-MLX models
        guard case .mlx = model else {
            return try await download(model, progress: progress)
        }
        
        if !skipValidation {
            let result = await MLXCompatibilityChecker.shared.checkCompatibility(model)
            
            switch result {
            case .compatible:
                break  // Proceed with download
                
            case .incompatible(let reasons):
                throw AIError.incompatibleModel(
                    model: model,
                    reasons: reasons.map { $0.description }
                )
                
            case .unknown(let error):
                // Log warning but allow download attempt
                print("Warning: Could not validate compatibility for \(model.rawValue): \(error?.localizedDescription ?? "unknown")")
            }
        }
        
        return try await downloadWithEstimation(model, progress: progress)
    }
}
```

#### 5.3 Add Error Type

**Update:** `Sources/SwiftAI/Core/Errors/AIError.swift`

```swift
extension AIError {
    /// Model is not compatible with the target provider.
    case incompatibleModel(model: ModelIdentifier, reasons: [String])
}

extension AIError {
    public var errorDescription: String? {
        switch self {
        // ... existing cases ...
        
        case .incompatibleModel(let model, let reasons):
            let reasonList = reasons.joined(separator: ", ")
            return "Model '\(model.rawValue)' is not compatible: \(reasonList)"
        }
    }
}
```

#### 5.4 Usage Example

```swift
let checker = MLXCompatibilityChecker.shared

// Check before downloading
let result = await checker.checkCompatibility(.mlx("meta-llama/Llama-3.1-70B"))

switch result {
case .compatible(let confidence):
    print("Model is compatible (confidence: \(confidence))")
    
case .incompatible(let reasons):
    print("Model is NOT compatible:")
    for reason in reasons {
        print("  - \(reason)")
    }
    
case .unknown(let error):
    print("Could not determine compatibility: \(error?.localizedDescription ?? "unknown")")
}

// Download with automatic validation
let manager = ModelManager.shared

do {
    let url = try await manager.downloadValidated(.llama3_2_1B)
    print("Downloaded to: \(url)")
} catch AIError.incompatibleModel(let model, let reasons) {
    print("Cannot download \(model.displayName):")
    for reason in reasons {
        print("  - \(reason)")
    }
}

// Skip validation for known-good models
let url = try await manager.downloadValidated(
    .mlx("mlx-community/custom-model"),
    skipValidation: true
)
```

---

## Implementation Timeline

### Phase 1: Foundation (Week 1-2)
- [ ] Implement `HFMetadataService` with file tree and model details
- [ ] Implement `GlobMatcher` utility
- [ ] Implement `SpeedCalculator` for download metrics
- [ ] Update `DownloadProgress` with ETA calculation

### Phase 2: Validation (Week 2-3)
- [ ] Implement `MLXCompatibilityChecker`
- [ ] Add `incompatibleModel` error case
- [ ] Integrate validation with `ModelManager.downloadValidated()`
- [ ] Add tokenizer format validation

### Phase 3: Detection (Week 3-4)
- [ ] Implement `VLMDetector` service
- [ ] Add `ModelCapabilities` type
- [ ] Update `MLXProvider` to auto-route VLM vs LLM
- [ ] Test with known VLM models (LLaVA, Qwen2-VL, etc.)

### Phase 4: Caching (Week 4-5)
- [ ] Implement `MLXModelCache` with NSCache
- [ ] Update `MLXProvider` to use multi-model cache
- [ ] Add cache statistics and manual eviction
- [ ] Test memory pressure eviction behavior

### Phase 5: Warmup & Polish (Week 5-6)
- [ ] Add warmup protocol extension
- [ ] Implement MLX-specific warmup with prefill
- [ ] Add Foundation Models prewarm integration
- [ ] Update `ChatSession` with warmup config
- [ ] Documentation and examples

---

## File Summary

### New Files

| File | Description |
|------|-------------|
| `Services/HFMetadataService.swift` | HuggingFace API integration for metadata |
| `Services/VLMDetector.swift` | Vision Language Model detection |
| `Services/MLXCompatibilityChecker.swift` | MLX compatibility validation |
| `Utilities/GlobMatcher.swift` | Glob pattern matching utility |
| `ModelManagement/SpeedCalculator.swift` | Rolling average speed calculation |
| `Providers/MLX/MLXModelCache.swift` | NSCache-based model caching |
| `Core/Types/ModelCapabilities.swift` | Model capability detection types |

### Updated Files

| File | Changes |
|------|---------|
| `Core/Protocols/AIProvider.swift` | Add warmup extension |
| `Core/Errors/AIError.swift` | Add `incompatibleModel` case |
| `ModelManagement/DownloadProgress.swift` | Add ETA, speed, formatting |
| `ModelManagement/ModelManager.swift` | Add size estimation, validated download |
| `Providers/MLX/MLXProvider.swift` | Use cache, VLM routing, warmup |
| `Providers/MLX/MLXConfiguration.swift` | Add cache configuration |
| `Providers/FoundationModels/FoundationModelsProvider.swift` | Add prewarm |

---

## Testing Strategy

### Unit Tests
- `GlobMatcher` pattern matching
- `SpeedCalculator` rolling average
- `DownloadProgress` ETA calculation
- `VLMDetector` architecture detection
- `MLXCompatibilityChecker` file validation

### Integration Tests
- HuggingFace API calls (mock responses)
- Download size estimation accuracy
- VLM detection on known models
- Cache eviction under memory pressure

### End-to-End Tests
- Full download with progress tracking
- Model warmup latency improvement
- Multi-model cache switching
- VLM inference with image input

---

## References

- **Osaurus Repository:** https://github.com/dinoki-ai/osaurus
- **HuggingFace API:** https://huggingface.co/docs/hub/api
- **MLX Swift:** https://github.com/ml-explore/mlx-swift
- **SwiftAI Specification:** SwiftAI-API-Specification.md

---

*End of Enhancement Plan*
