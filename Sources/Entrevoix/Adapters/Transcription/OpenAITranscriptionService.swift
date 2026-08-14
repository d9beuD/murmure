import Foundation
import EntrevoixCore

struct OpenAITranscriptionService: SpeechTranscribing {
    private let transport: any HTTPTransporting
    private let makeBoundary: @Sendable () -> String

    init(
        transport: any HTTPTransporting,
        makeBoundary: @escaping @Sendable () -> String = { "Boundary-\(UUID().uuidString)" }
    ) {
        self.transport = transport
        self.makeBoundary = makeBoundary
    }

    func transcribe(
        audioURL: URL,
        configuration: ProviderConfiguration,
        apiKey: String,
        prompt: String?,
        language: String?
    ) async throws -> String {
        guard let endpoint = configuration.endpointURL else { throw TranscriptionError.invalidEndpoint }
        let audioData = try Data(contentsOf: audioURL)
        guard audioData.count <= 25 * 1024 * 1024 else { throw TranscriptionError.fileTooLarge }

        let boundary = makeBoundary()
        var body = Data()
        appendField("model", value: configuration.model, to: &body, boundary: boundary)
        if let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendField("prompt", value: prompt, to: &body, boundary: boundary)
        }
        if let language, !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendField(configuration.model == "gpt-transcribe" ? "languages[]" : "language", value: language, to: &body, boundary: boundary)
        }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8))
        body.append(audioData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        switch configuration.authentication {
        case .bearer:
            guard !apiKey.isEmpty else { throw TranscriptionError.missingAPIKey }
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .apiKey:
            guard !apiKey.isEmpty else { throw TranscriptionError.missingAPIKey }
            let header = configuration.customHeaderName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !header.isEmpty else { throw TranscriptionError.invalidHeader }
            request.setValue(apiKey, forHTTPHeaderField: header)
        case .none:
            break
        }

        let (data, response) = try await transport.data(for: request.withHTTPBody(body))
        guard let httpResponse = response as? HTTPURLResponse else { throw TranscriptionError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TranscriptionError.http(statusCode: httpResponse.statusCode, message: errorMessage(from: data))
        }
        if let result = try? JSONDecoder().decode(TranscriptionResponse.self, from: data), !result.text.isEmpty {
            return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw TranscriptionError.emptyResult }
        return text
    }

    private func appendField(_ name: String, value: String, to body: inout Data, boundary: String) {
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
    }

    private func errorMessage(from data: Data) -> String? {
        guard let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) else { return nil }
        return error.error.message
    }
}

private extension URLRequest {
    func withHTTPBody(_ body: Data) -> URLRequest {
        var request = self
        request.httpBody = body
        return request
    }
}

private struct TranscriptionResponse: Decodable { let text: String }
private struct APIErrorEnvelope: Decodable { let error: APIError }
private struct APIError: Decodable { let message: String }

enum TranscriptionError: LocalizedError, LogSafeError, UserFacingErrorProviding {
    case invalidEndpoint
    case invalidHeader
    case missingAPIKey
    case fileTooLarge
    case invalidResponse
    case emptyResult
    case http(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "The STT endpoint is invalid."
        case .invalidHeader: "The authentication header name is invalid."
        case .missingAPIKey: "The STT API key is missing."
        case .fileTooLarge: "The audio file exceeds the 25 MB limit."
        case .invalidResponse: "The STT response is invalid."
        case .emptyResult: "The transcript is empty."
        case .http(let statusCode, let message):
            if let message { "STT error (HTTP \(statusCode)): \(message)" }
            else { "STT error (HTTP \(statusCode))." }
        }
    }

    var logMessage: String {
        switch self {
        case .http(let statusCode, _): "STT request failed (HTTP \(statusCode))."
        default: "STT transcription failed."
        }
    }

    var userFacingMessage: UserFacingErrorMessage {
        switch self {
        case .invalidEndpoint: .sttInvalidEndpoint
        case .invalidHeader: .sttInvalidHeader
        case .missingAPIKey: .sttMissingAPIKey
        case .fileTooLarge: .sttFileTooLarge
        case .invalidResponse: .sttInvalidResponse
        case .emptyResult: .sttEmptyResult
        case .http(let statusCode, let message): .sttHTTP(statusCode: statusCode, providerMessage: message)
        }
    }
}
