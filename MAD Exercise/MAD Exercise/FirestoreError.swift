//
//  FirestoreError.swift
//  MAD Exercise
//

import Foundation

/// Decodes the error payload of the Firestore REST API, e.g.:
/// {"error":{"code":403,"message":"Missing or insufficient permissions.","status":"PERMISSION_DENIED"}}
///
/// Differs from the Identity Toolkit payload in ResponseError: it has a `status`
/// instead of the `errors` array, and may carry extra `details` we ignore.
nonisolated struct FirestoreError: Decodable {
    let code: Int
    let message: String
    let status: String

    private enum RootKeys: String, CodingKey {
        case error
    }

    private enum ErrorKeys: String, CodingKey {
        case code
        case message
        case status
    }

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        let errorContainer = try root.nestedContainer(keyedBy: ErrorKeys.self, forKey: .error)
        code = try errorContainer.decode(Int.self, forKey: .code)
        message = try errorContainer.decode(String.self, forKey: .message)
        status = try errorContainer.decode(String.self, forKey: .status)
    }
}
