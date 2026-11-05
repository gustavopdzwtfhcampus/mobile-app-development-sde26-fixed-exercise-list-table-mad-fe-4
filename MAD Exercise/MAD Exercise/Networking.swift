//
//  Networking.swift
//  MAD Exercise
//

import Foundation

final class Networking {
    private let session = URLSession(configuration: .default)
    private let apiKey = "AIzaSyDeLs8S6Hpy642JUPC3Pft-xVx8Ocs-uXY"

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
                switch error.code {
                case URLError.notConnectedToInternet.rawValue,
                     URLError.networkConnectionLost.rawValue,
                     URLError.timedOut.rawValue:
                    finish(nil, .networkUnavailable(error.localizedDescription))
                default:
                    finish(nil, .unknown(error.localizedDescription))
                }
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
            default:
                finish(nil, .serverError(httpResponse.statusCode))
            }
        }
        task.resume()
    }
}
