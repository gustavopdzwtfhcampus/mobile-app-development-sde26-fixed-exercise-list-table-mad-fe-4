//
//  NetworkingTests.swift
//  MAD ExerciseTests
//

import Foundation
import Testing
@testable import MAD_Exercise

/// Stubs every request of a URLSession, so Networking can be tested without a server.
nonisolated final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse?, Data?, Error?))?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        let (response, data, error) = Self.handler?(request) ?? (nil, nil, nil)
        if let error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
@MainActor
struct NetworkingTests {
    private let user = User(localId: "id", email: "mad-fe@mad.at", displayName: "",
                            idToken: "TOKEN123", registered: true, refreshToken: "refresh")

    private let countryJSON = """
    {"name": "projects/mad-fe/databases/(default)/documents/countries/abc",
     "fields": {"currency": {"stringValue": "EUR"}, "native": {"stringValue": "Österreich"},
                "name": {"stringValue": "Austria"}, "capital": {"stringValue": "Vienna"},
                "continent": {"stringValue": "EU"}, "phone": {"stringValue": "43"},
                "languages": {"arrayValue": {"values": [{"stringValue": "de"}]}}},
     "createTime": "2026-08-22T19:40:40.030617Z", "updateTime": "2026-08-22T19:40:40.030617Z"}
    """

    private func makeNetworking() -> Networking {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.requests = []
        return Networking(session: URLSession(configuration: configuration))
    }

    private func respond(status: Int, body: String?) {
        StubURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil),
             body.map { Data($0.utf8) }, nil)
        }
    }

    private func fetch(_ networking: Networking) async -> (countries: [Country]?, error: NetworkingError?, onMain: Bool, calls: Int) {
        await withCheckedContinuation { continuation in
            var calls = 0
            networking.fetchCountries(user: user) { countries, error in
                calls += 1
                continuation.resume(returning: (countries, error, Thread.isMainThread, calls))
            }
        }
    }

    @Test func successReturnsCountriesOnMainThread() async {
        let networking = makeNetworking()
        respond(status: 200, body: #"{"documents": [\#(countryJSON)]}"#)

        let result = await fetch(networking)

        #expect(result.countries?.map(\.name) == ["Austria"])
        #expect(result.error == nil)
        #expect(result.onMain)
        #expect(result.calls == 1)
    }

    @Test func sendsAuthorizedGetRequestWithoutBody() async throws {
        let networking = makeNetworking()
        respond(status: 200, body: #"{"documents": []}"#)

        _ = await fetch(networking)

        let request = try #require(StubURLProtocol.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer TOKEN123")
        #expect(request.httpBody == nil)
        #expect(request.url?.absoluteString == "https://firestore.googleapis.com/v1/projects/mad-fe/databases/(default)/documents/countries?pageSize=1000&orderBy=name")
    }

    @Test func emptyCollectionReturnsEmptyArray() async {
        let networking = makeNetworking()
        respond(status: 200, body: "{}")

        let result = await fetch(networking)

        #expect(result.countries?.isEmpty == true)
        #expect(result.error == nil)
    }

    @Test(arguments: [
        (401, #"{"error": {"code": 401, "message": "bad", "status": "UNAUTHENTICATED", "details": [{"reason": "X"}]}}"#),
        (403, #"{"error": {"code": 403, "message": "no", "status": "PERMISSION_DENIED"}}"#),
        (401, "not json"),
        (403, ""),
    ])
    func authFailuresMapToUnauthorized(status: Int, body: String) async {
        let networking = makeNetworking()
        respond(status: status, body: body)

        let result = await fetch(networking)

        #expect(result.countries == nil)
        #expect(result.error == .unauthorized)
        #expect(result.onMain)
    }

    @Test func otherFirestoreErrorMapsToServerErrorWithCode() async {
        let networking = makeNetworking()
        respond(status: 500, body: #"{"error": {"code": 500, "message": "boom", "status": "INTERNAL"}}"#)

        #expect(await fetch(networking).error == .serverError(500))
    }

    @Test func undecodableErrorBodyFallsBackToHTTPStatus() async {
        let networking = makeNetworking()
        respond(status: 503, body: "<html>oops</html>")

        #expect(await fetch(networking).error == .serverError(503))
    }

    @Test func malformedSuccessBodyIsUnexpectedFormat() async {
        let networking = makeNetworking()
        respond(status: 200, body: #"{"documents": [{"name": "x"}]}"#)

        let result = await fetch(networking)

        #expect(result.countries == nil)
        #expect(result.error == .unexpectedResponseFormat)
    }

    @Test(arguments: [URLError.notConnectedToInternet, URLError.networkConnectionLost, URLError.timedOut,
                  URLError.cannotFindHost, URLError.cannotConnectToHost, URLError.dnsLookupFailed, URLError.dataNotAllowed])
    func offlineMapsToNetworkUnavailable(code: URLError.Code) async {
        let networking = makeNetworking()
        StubURLProtocol.handler = { _ in (nil, nil, URLError(code)) }

        let result = await fetch(networking)

        guard case .networkUnavailable = result.error else {
            Issue.record("expected networkUnavailable, got \(String(describing: result.error))")
            return
        }
        #expect(result.countries == nil)
    }

    @Test func otherTransportErrorMapsToUnknown() async {
        let networking = makeNetworking()
        StubURLProtocol.handler = { _ in (nil, nil, URLError(.badServerResponse)) }

        guard case .unknown = await fetch(networking).error else {
            Issue.record("expected unknown")
            return
        }
    }

    // MARK: - login

    private func login(_ networking: Networking, email: String = "mad-fe@mad.at", password: String = "madmad")
        async -> (user: User?, error: NetworkingError?, onMain: Bool, calls: Int) {
        await withCheckedContinuation { continuation in
            var calls = 0
            networking.login(email: email, password: password) { user, error in
                calls += 1
                continuation.resume(returning: (user, error, Thread.isMainThread, calls))
            }
        }
    }

    private func errorBody(_ message: String, code: Int = 400) -> String {
        #"{"error": {"code": \#(code), "message": "\#(message)", "errors": [{"message": "\#(message)", "domain": "global", "reason": "invalid"}]}}"#
    }

    @Test func loginSuccessReturnsUserOnMainThread() async {
        let networking = makeNetworking()
        respond(status: 200, body: #"{"localId": "L1", "email": "mad-fe@mad.at", "displayName": "", "idToken": "T", "registered": true, "refreshToken": "R"}"#)

        let result = await login(networking)

        #expect(result.user?.idToken == "T")
        #expect(result.user?.email == "mad-fe@mad.at")
        #expect(result.error == nil)
        #expect(result.onMain)
        #expect(result.calls == 1)
    }

    @Test func loginSendsPostWithJSONBody() async throws {
        let networking = makeNetworking()
        respond(status: 200, body: "{}")

        _ = await login(networking, email: "a@b.at", password: "pw")

        let request = try #require(StubURLProtocol.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.url?.host() == "identitytoolkit.googleapis.com")
        // URLSession hands the body to the protocol as a stream.
        let stream = try #require(request.httpBodyStream)
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["email"] as? String == "a@b.at")
        #expect(body["password"] as? String == "pw")
        #expect(body["returnSecureToken"] as? Bool == true)
    }

    @Test(arguments: [
        ("INVALID_EMAIL", NetworkingError.invalidEmailFormat),
        ("EMAIL_NOT_FOUND", NetworkingError.emailNotFound),
        ("INVALID_PASSWORD", NetworkingError.wrongPassword),
        ("INVALID_LOGIN_CREDENTIALS", NetworkingError.invalidCredentials),
        ("TOO_MANY_ATTEMPTS_TRY_LATER", NetworkingError.tooManyAttempts),
        ("SOMETHING_NEW", NetworkingError.serverError(400)),
    ])
    func loginMapsFirebaseMessages(message: String, expected: NetworkingError) async {
        let networking = makeNetworking()
        respond(status: 400, body: errorBody(message))

        let result = await login(networking)

        #expect(result.user == nil)
        #expect(result.error == expected)
        #expect(result.onMain)
        #expect(result.calls == 1)
    }

    @Test func loginUndecodableErrorBodyIsServerError() async {
        let networking = makeNetworking()
        respond(status: 500, body: "<html>oops</html>")

        #expect(await login(networking).error == .serverError(500))
    }

    @Test func loginMalformedSuccessBodyIsUnexpectedFormat() async {
        let networking = makeNetworking()
        respond(status: 200, body: #"{"unexpected": true}"#)

        #expect(await login(networking).error == .unexpectedResponseFormat)
    }

    @Test(arguments: [URLError.notConnectedToInternet, URLError.networkConnectionLost, URLError.timedOut,
                  URLError.cannotFindHost, URLError.cannotConnectToHost, URLError.dnsLookupFailed, URLError.dataNotAllowed])
    func loginOfflineMapsToNetworkUnavailable(code: URLError.Code) async {
        let networking = makeNetworking()
        StubURLProtocol.handler = { _ in (nil, nil, URLError(code)) }

        guard case .networkUnavailable = await login(networking).error else {
            Issue.record("expected networkUnavailable")
            return
        }
    }

    @Test func loginOtherTransportErrorMapsToUnknown() async {
        let networking = makeNetworking()
        StubURLProtocol.handler = { _ in (nil, nil, URLError(.badServerResponse)) }

        guard case .unknown = await login(networking).error else {
            Issue.record("expected unknown")
            return
        }
    }
}

struct FirestoreErrorDecodingTests {
    @Test func decodesErrorPayloadIgnoringDetails() throws {
        let json = #"{"error": {"code": 401, "message": "m", "status": "UNAUTHENTICATED", "details": [{"@type": "t"}]}}"#
        let error = try JSONDecoder().decode(FirestoreError.self, from: Data(json.utf8))

        #expect(error.code == 401)
        #expect(error.message == "m")
        #expect(error.status == "UNAUTHENTICATED")
    }
}

struct NetworkingErrorMessageTests {
    @Test(arguments: [
        (NetworkingError.serializationFailed, "Something went wrong preparing your request. Please try again."),
        (.invalidEmailFormat, "Please enter a valid email address."),
        (.emailNotFound, "Email or password is incorrect."),
        (.wrongPassword, "Email or password is incorrect."),
        (.invalidCredentials, "Email or password is incorrect."),
        (.tooManyAttempts, "Too many login attempts. Please wait a few minutes and try again."),
        (.networkUnavailable("x"), "You appear to be offline. Please check your connection and try again."),
        (.unexpectedResponseFormat, "Received an unexpected response from the server. Please try again."),
        (.serverError(500), "The server ran into a problem. Please try again later."),
        (.unauthorized, "You are not authorized to view this. Please log in again."),
        (.unknown(nil), "An unexpected error occurred. Please try again."),
    ])
    func userMessage(error: NetworkingError, expected: String) {
        #expect(error.userMessage == expected)
    }
}
