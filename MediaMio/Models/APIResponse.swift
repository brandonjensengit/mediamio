//
//  APIResponse.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    case authenticationFailed
    case serverUnreachable
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return Constants.ErrorMessages.invalidURL
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError:
            return Constants.ErrorMessages.networkError
        case .authenticationFailed:
            return Constants.ErrorMessages.authenticationFailed
        case .serverUnreachable:
            return Constants.ErrorMessages.connectionFailed
        case .unknown:
            return Constants.ErrorMessages.unknownError
        }
    }
}

struct EmptyResponse: Codable {}
