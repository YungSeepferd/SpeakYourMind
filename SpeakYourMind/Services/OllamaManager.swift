import Foundation

// MARK: - Ollama Errors

enum OllamaError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case noData
    case decodingError(Error)
    case modelNotFound(String)
    case serverError(Int, String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Ollama base URL. Please check your settings."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noData:
            return "No data received from Ollama server."
        case .decodingError(let error):
            return "Failed to decode Ollama response: \(error.localizedDescription)"
        case .modelNotFound(let model):
            return "Model '\(model)' not found. Please pull it first or select a different model."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .emptyResponse:
            return "Ollama returned an empty response."
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
final class OllamaManager: ObservableObject {

    // MARK: - Properties

    /// Base URL for the Ollama server (e.g. "http://localhost:11434").
    var baseURL: String

    /// The currently selected model name (e.g. "llama3").
    var selectedModel: String

    /// List of available model names fetched from the server.
    @Published var availableModels: [String] = []

    // MARK: - Private

    private var urlSession: URLSession

    // MARK: - Init

    init(baseURL: String = "http://localhost:11434",
         selectedModel: String = "",
         urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.selectedModel = selectedModel
        self.urlSession = urlSession
    }

    // MARK: - Fetch Available Models

    /// Fetches the list of models available on the Ollama server.
    /// Calls `completion` on the main thread.
    func fetchAvailableModels(completion: @escaping (Result<[String], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            DispatchQueue.main.async {
                completion(.failure(OllamaError.invalidURL))
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

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
        request.timeoutInterval = 120 // AI generation can take time

        urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(OllamaError.networkError(error)))
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
