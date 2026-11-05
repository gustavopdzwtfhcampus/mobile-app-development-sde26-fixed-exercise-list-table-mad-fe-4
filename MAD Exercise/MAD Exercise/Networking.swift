//
//  Networking.swift
//  MAD Exercise
//

import Foundation
import Observation

/// @Observable only so it can be shared via SwiftUI's typed environment
/// (`.environment(_:)` / `@Environment(Networking.self)`); it has no state to observe.
@Observable
final class Networking {
    private let session: URLSession
    private let apiKey = "AIzaSyDeLs8S6Hpy642JUPC3Pft-xVx8Ocs-uXY"

    init(session: URLSession = URLSession(configuration: .default)) {
        self.session = session
    }

    func login(email: String,
               password: String,
               completionHandler: @escaping (User?, NetworkingError?) -> Void) {
        // Funnel every exit path through here so the completion handler is
        // guaranteed to run exactly once, and always on the main thread.
        func finish(_ user: User?, _ error: NetworkingError?) {
            DispatchQueue.main.async {
                completionHandler(user, error)
            }
        }

        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            finish(nil, .serializationFailed)
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            // Transport-level failure: the request never got a response at all.
            if let error = error as NSError? {
                finish(nil, Self.transportError(error))
                return
            }

            guard let data, let httpResponse = response as? HTTPURLResponse else {
                finish(nil, .unexpectedResponseFormat)
                return
            }

            if (200..<300).contains(httpResponse.statusCode) {
                guard let user = try? JSONDecoder().decode(User.self, from: data) else {
                    finish(nil, .unexpectedResponseFormat)
                    return
                }
                finish(user, nil)
                return
            }

            guard let responseError = try? JSONDecoder().decode(ResponseError.self, from: data) else {
                finish(nil, .serverError(httpResponse.statusCode))
                return
            }

            switch responseError.message {
            case "INVALID_EMAIL":
                finish(nil, .invalidEmailFormat)
            case "EMAIL_NOT_FOUND":
                finish(nil, .emailNotFound)
            case "INVALID_PASSWORD":
                finish(nil, .wrongPassword)
            case "INVALID_LOGIN_CREDENTIALS":
                finish(nil, .invalidCredentials)
            case "TOO_MANY_ATTEMPTS_TRY_LATER":
                finish(nil, .tooManyAttempts)
            default:
                finish(nil, .serverError(httpResponse.statusCode))
            }
        }
        task.resume()
    }

    func fetchCountries(user: User,
                        completionHandler: @escaping ([Country]?, NetworkingError?) -> Void) {
        // Funnel every exit path through here so the completion handler is
        // guaranteed to run exactly once, and always on the main thread.
        func finish(_ countries: [Country]?, _ error: NetworkingError?) {
            DispatchQueue.main.async {
                completionHandler(countries, error)
            }
        }

        let url = URL(string: "https://firestore.googleapis.com/v1/projects/mad-fe/databases/(default)/documents/countries?pageSize=1000&orderBy=name")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(user.idToken)", forHTTPHeaderField: "Authorization")

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error as NSError? {
                finish(nil, Self.transportError(error))
                return
            }

            guard let data, let httpResponse = response as? HTTPURLResponse else {
                finish(nil, .unexpectedResponseFormat)
                return
            }

            if (200..<300).contains(httpResponse.statusCode) {
                guard let container = try? JSONDecoder.firestore().decode(DocumentsContainer.self, from: data) else {
                    finish(nil, .unexpectedResponseFormat)
                    return
                }
                finish(container.documents, nil)
                return
            }

            // Prefer Firestore's own status string; fall back to the HTTP code if the
            // body isn't the documented error payload.
            let firestoreError = try? JSONDecoder().decode(FirestoreError.self, from: data)
            switch firestoreError?.status {
            case "UNAUTHENTICATED", "PERMISSION_DENIED":
                finish(nil, .unauthorized)
            case .some:
                finish(nil, .serverError(firestoreError?.code ?? httpResponse.statusCode))
            case .none:
                switch httpResponse.statusCode {
                case 401, 403:
                    finish(nil, .unauthorized)
                default:
                    finish(nil, .serverError(httpResponse.statusCode))
                }
            }
        }
        task.resume()
    }

    /// Transport-level failure: the request never got a response at all.
    private static func transportError(_ error: NSError) -> NetworkingError {
        switch error.code {
        case URLError.notConnectedToInternet.rawValue,
             URLError.networkConnectionLost.rawValue,
             URLError.timedOut.rawValue,
             URLError.cannotFindHost.rawValue,
             URLError.cannotConnectToHost.rawValue,
             URLError.dnsLookupFailed.rawValue,
             URLError.dataNotAllowed.rawValue:
            return .networkUnavailable(error.localizedDescription)
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
