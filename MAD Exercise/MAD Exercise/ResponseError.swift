//
//  ResponseError.swift
//  MAD Exercise
//

import Foundation

/// Decodes Firebase's error payload shape, e.g.:
/// {"error":{"code":400,"message":"INVALID_EMAIL","errors":[{"message":"INVALID_EMAIL","domain":"global","reason":"invalid"}]}}
///
/// Decodable only (not Codable) since we never need to encode this type, and a
/// custom init(from:) under Codable would force an unused encode(to:) as well.
struct ResponseError: Decodable {
    struct Detail: Decodable {
        let message: String
        let domain: String
        let reason: String
    }

    let code: Int
    let message: String
    let errors: [Detail]

    private enum RootKeys: String, CodingKey {
        case error
    }

    private enum ErrorKeys: String, CodingKey {
        case code
        case message
        case errors
    }

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        let errorContainer = try root.nestedContainer(keyedBy: ErrorKeys.self, forKey: .error)
        code = try errorContainer.decode(Int.self, forKey: .code)
        message = try errorContainer.decode(String.self, forKey: .message)
        errors = try errorContainer.decode([Detail].self, forKey: .errors)
    }
}
