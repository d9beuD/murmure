import Foundation
import MurmureCore

final class OpenAITranscriptionService: SpeechTranscribing, @unchecked Sendable {
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

        let boundary = "Boundary-\(UUID().uuidString)"
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

        let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request.withHTTPBody(body))
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

enum TranscriptionError: LocalizedError {
    case invalidEndpoint
    case invalidHeader
    case missingAPIKey
    case fileTooLarge
    case invalidResponse
    case emptyResult
    case http(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "L’endpoint STT est invalide."
        case .invalidHeader: "Le nom de l’en-tête d’authentification est invalide."
        case .missingAPIKey: "La clé API STT est manquante."
        case .fileTooLarge: "Le fichier audio dépasse la limite de 25 Mo."
        case .invalidResponse: "La réponse STT est invalide."
        case .emptyResult: "La transcription est vide."
        case .http(let statusCode, let message):
            if let message { "Erreur STT (HTTP \(statusCode)) : \(message)" }
            else { "Erreur STT (HTTP \(statusCode))." }
        }
    }
}
