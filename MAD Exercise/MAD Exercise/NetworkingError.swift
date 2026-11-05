//
//  NetworkingError.swift
//  MAD Exercise
//

import Foundation

enum NetworkingError: Error, Equatable {
    /// JSONSerialization.data(withJSONObject:) threw while building the request body.
    case serializationFailed
    /// API message INVALID_EMAIL — the typed text isn't a valid email address.
    case invalidEmailFormat
    /// API message EMAIL_NOT_FOUND. Unreachable on this Firebase project: email
    /// enumeration protection is enabled, so an unknown email returns the same
    /// INVALID_LOGIN_CREDENTIALS as a wrong password (see .invalidCredentials).
    /// Kept so every case from the exercise's error list has a home.
    case emailNotFound
    /// API message INVALID_PASSWORD. Unreachable for the same reason as
    /// .emailNotFound above — see .invalidCredentials.
    case wrongPassword
    /// API message INVALID_LOGIN_CREDENTIALS — what this project actually returns
    /// for both an unknown email and a wrong password.
    case invalidCredentials
    /// The request couldn't reach the server at all (offline, timed out, ...).
    case networkUnavailable(String)
    /// The response body wasn't decodable as either User or ResponseError.
    case unexpectedResponseFormat
    /// Non-2xx response whose error body didn't decode, or whose message we
    /// don't have a specific case for.
    case serverError(Int)
    /// Firestore rejected the request as unauthenticated (401) or not permitted
    /// (403), e.g. because the ID token is missing, invalid or expired.
    case unauthorized
    /// Anything else we didn't anticipate.
    case unknown(String?)
}

extension NetworkingError {
    /// Message suitable for showing to the user.
    var userMessage: String {
        switch self {
        case .serializationFailed:
            "Something went wrong preparing your request. Please try again."
        case .invalidEmailFormat:
            "Please enter a valid email address."
        case .emailNotFound, .wrongPassword, .invalidCredentials:
            "Email or password is incorrect."
        case .networkUnavailable:
            "You appear to be offline. Please check your connection and try again."
        case .unexpectedResponseFormat:
            "Received an unexpected response from the server. Please try again."
        case .serverError:
            "The server ran into a problem. Please try again later."
        case .unauthorized:
            "You are not authorized to view this. Please log in again."
        case .unknown:
            "An unexpected error occurred. Please try again."
        }
    }
}
