//
//  NetworkingCountriesTests.swift
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
struct NetworkingCountriesTests {
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

    @Test(arguments: [URLError.notConnectedToInternet, URLError.networkConnectionLost, URLError.timedOut])
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
