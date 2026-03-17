import Foundation

// MARK: - Ollama Connection Status

/// Represents the current status of the Ollama server connection.
enum OllamaStatus: Equatable {
    case notInstalled      // Ollama app not installed on Mac
    case notRunning        // Ollama installed but server not running
    case running           // Server is running and responsive
    case error(String)     // Specific error message
    
    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

// MARK: - Ollama Errors

enum OllamaError: LocalizedError {
    case invalidURL
    case connectionRefused
    case timeout
    case networkError(Error)
    case noData
    case decodingError(Error)
    case modelNotFound(String)
    case serverError(Int, String)
    case emptyResponse
    case notRunning
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Ollama base URL. Check Settings → Ollama → Base URL (default: http://localhost:11434)"
        case .connectionRefused:
            return """
                Ollama server is not running.
                
                To fix:
                1. Open the Ollama app from Applications
                2. Or run "ollama serve" in Terminal
                3. Check Settings → Ollama status indicator
                """
        case .timeout:
            return "Request timed out. The model may be loading. Try again or select a smaller model."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription). Check if Ollama server is running."
        case .noData:
            return "No data received from Ollama server. Check connection and try again."
        case .decodingError(let error):
            return "Failed to decode Ollama response: \(error.localizedDescription)"
        case .modelNotFound(let model):
            return """
                Model '\(model)' not found.
                
                To fix:
                1. Open Terminal
                2. Run: ollama pull \(model)
                3. Select the model in Settings
                """
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .emptyResponse:
            return "Ollama returned an empty response. Try again or check model status."
        case .notRunning:
            return "Ollama server is not running. Start the Ollama app and try again."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .connectionRefused, .notRunning:
            return "Start Ollama server and verify connection in Settings"
        case .modelNotFound(let model):
            return "Run 'ollama pull \(model)' in Terminal"
        case .timeout:
            return "Wait for model to load or try a smaller model"
        default:
            return nil
        }
    }
}

// MARK: - Ollama Response Models

private struct OllamaTagsResponse: Decodable {
    let models: [OllamaModelInfo]
}

private struct OllamaModelInfo: Decodable {
    let name: String
}

private struct OllamaGenerateRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
}

private struct OllamaGenerateResponse: Decodable {
    let response: String
    let done: Bool?
    let error: String?
}

// MARK: - OllamaManager

/// Manages communication with the Ollama local AI API.
/// Supports connection validation, model caching, and retry logic.
final class OllamaManager: ObservableObject {

    // MARK: - Properties

    /// Base URL for the Ollama server (e.g. "http://localhost:11434").
    @Published var baseURL: String

    /// The currently selected model name (e.g. "llama3").
    @Published var selectedModel: String

    /// List of available model names fetched from the server.
    @Published var availableModels: [String] = []

    /// Current connection status to Ollama server.
    @Published var connectionStatus: OllamaStatus = .notRunning

    /// Whether Ollama server is reachable (computed from status).
    var isServerReachable: Bool {
        connectionStatus.isRunning
    }

    // MARK: - Private

    private var urlSession: URLSession
    
    /// Cached models list to avoid repeated API calls.
    private var cachedModels: [String]?
    
    /// Cache timestamp for model list.
    private var cacheTimestamp: Date?
    
    /// Cache validity duration (60 seconds).
    private let cacheValidDuration: TimeInterval = 60.0
    
    /// Connection status cache.
    private var statusCache: OllamaStatus?
    private var statusCacheTimestamp: Date?
    private let statusCacheDuration: TimeInterval = 30.0

    // MARK: - Init

    init(baseURL: String = "http://localhost:11434",
         selectedModel: String = "",
         urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.selectedModel = selectedModel
        self.urlSession = urlSession
    }

    // MARK: - Connection Validation

    /// Checks if the Ollama server is reachable and running.
    /// Uses /api/version endpoint for lightweight health check.
    /// Caches result for 30 seconds to avoid repeated checks.
    func checkConnection() async -> OllamaStatus {
        // Return cached status if still valid
        if let cached = statusCache,
           let timestamp = statusCacheTimestamp,
           Date().timeIntervalSince(timestamp) < statusCacheDuration {
            return cached
        }
        
        guard let url = URL(string: "\(baseURL)/api/version") else {
            statusCache = .error("Invalid URL")
            statusCacheTimestamp = Date()
            return .error("Invalid base URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0  // Quick timeout for health check
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let status: OllamaStatus = .error("Invalid response")
                statusCache = status
                statusCacheTimestamp = Date()
                return status
            }
            
            if httpResponse.statusCode == 200 {
                let status: OllamaStatus = .running
                statusCache = status
                statusCacheTimestamp = Date()
                return status
            }
            
            let status: OllamaStatus = .error("Server returned \(httpResponse.statusCode)")
            statusCache = status
            statusCacheTimestamp = Date()
            return status
            
        } catch let error as URLError {
            let status: OllamaStatus
            switch error.code {
            case .cannotConnectToHost, .notConnectedToInternet:
                status = .notRunning
            case .timedOut:
                status = .error("Connection timed out")
            default:
                status = .error(error.localizedDescription)
            }
            statusCache = status
            statusCacheTimestamp = Date()
            return status
            
        } catch {
            let status: OllamaStatus = .error(error.localizedDescription)
            statusCache = status
            statusCacheTimestamp = Date()
            return status
        }
    }
    
    /// Quick ping to check if server is reachable (no caching).
    func isServerReachable() async -> Bool {
        let status = await checkConnection()
        return status.isRunning
    }

    // MARK: - Fetch Available Models

    /// Fetches the list of models available on the Ollama server.
    /// Uses caching (60 seconds) to avoid repeated API calls.
    /// Calls `completion` on the main thread.
    func fetchAvailableModels(forceRefresh: Bool = false,
                              completion: @escaping (Result<[String], Error>) -> Void) {
        // Return cached models if still valid and not forcing refresh
        if !forceRefresh,
           let cached = cachedModels,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidDuration {
            DispatchQueue.main.async {
                self.availableModels = cached
                completion(.success(cached))
            }
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            DispatchQueue.main.async {
                completion(.failure(OllamaError.invalidURL))
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0  // 10 seconds for model listing

        urlSession.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(OllamaError.networkError(error)))
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                DispatchQueue.main.async {
                    completion(.failure(OllamaError.serverError(httpResponse.statusCode, message)))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(OllamaError.noData))
                }
                return
            }

            do {
                let tagsResponse = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
                let modelNames = tagsResponse.models.map { $0.name }
                
                // Cache the results
                self?.cachedModels = modelNames
                self?.cacheTimestamp = Date()
                
                DispatchQueue.main.async {
                    self?.availableModels = modelNames
                    completion(.success(modelNames))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(OllamaError.decodingError(error)))
                }
            }
        }.resume()
    }

    // MARK: - Process Text

    /// Sends text to Ollama with an instruction and returns the AI-generated result.
    /// The prompt is formatted as: `"\(instruction): \"\(text)\""`
    /// Uses 300 second timeout (5 minutes) for AI generation.
    /// Calls `completion` on the main thread.
    func processText(_ text: String,
                     instruction: String,
                     completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            DispatchQueue.main.async {
                completion(.failure(OllamaError.invalidURL))
            }
            return
        }

        let prompt = "\(instruction): \"\(text)\""

        let requestBody = OllamaGenerateRequest(
            model: selectedModel,
            prompt: prompt,
            stream: false
        )

        guard let bodyData = try? JSONEncoder().encode(requestBody) else {
            DispatchQueue.main.async {
                completion(.failure(OllamaError.networkError(
                    NSError(domain: "OllamaManager", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to encode request body."]))))
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 300.0  // 5 minutes for AI generation (matches Ollama server default)

        urlSession.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    // Map URLError to actionable OllamaError
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .cannotConnectToHost, .notConnectedToInternet:
                            completion(.failure(OllamaError.connectionRefused))
                        case .timedOut:
                            completion(.failure(OllamaError.timeout))
                        default:
                            completion(.failure(OllamaError.networkError(error)))
                        }
                    } else {
                        completion(.failure(OllamaError.networkError(error)))
                    }
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    DispatchQueue.main.async {
                        completion(.failure(OllamaError.modelNotFound(requestBody.model)))
                    }
                    return
                }
                if !(200..<300).contains(httpResponse.statusCode) {
                    let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                    DispatchQueue.main.async {
                        completion(.failure(OllamaError.serverError(httpResponse.statusCode, message)))
                    }
                    return
                }
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(OllamaError.noData))
                }
                return
            }

            do {
                let generateResponse = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)

                if let serverError = generateResponse.error, !serverError.isEmpty {
                    // Check for model-not-found error in response body
                    if serverError.lowercased().contains("model") &&
                       serverError.lowercased().contains("not found") {
                        DispatchQueue.main.async {
                            completion(.failure(OllamaError.modelNotFound(requestBody.model)))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(OllamaError.serverError(0, serverError)))
                        }
                    }
                    return
                }

                let generatedText = generateResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)

                if generatedText.isEmpty {
                    DispatchQueue.main.async {
                        completion(.failure(OllamaError.emptyResponse))
                    }
                    return
                }

                DispatchQueue.main.async {
                    completion(.success(generatedText))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(OllamaError.decodingError(error)))
                }
            }
        }.resume()
    }
}
