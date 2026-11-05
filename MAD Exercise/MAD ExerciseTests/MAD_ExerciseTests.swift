//
//  MAD_ExerciseTests.swift
//  MAD ExerciseTests
//
//  Created by Gustavo Podzuweit on 28.09.26.
//

import Foundation
import Testing
@testable import MAD_Exercise

struct CountryDecodingTests {
    private static func document(id: String = "oAgZVEWEOoJKdlNvYTSa",
                                 name: String = "Austria",
                                 languages: String? = #""languages": {"arrayValue": {"values": [{"stringValue": "de"}]}},"#,
                                 createTime: String = "2026-08-22T19:40:40.030617Z",
                                 updateTime: String = "2026-08-23T08:01:02.5Z") -> String {
        """
        {
          "name": "projects/mad-fe/databases/(default)/documents/countries/\(id)",
          "fields": {
            "currency": {"stringValue": "EUR"},
            \(languages ?? "")
            "native": {"stringValue": "Österreich"},
            "name": {"stringValue": "\(name)"},
            "capital": {"stringValue": "Vienna"},
            "continent": {"stringValue": "EU"},
            "phone": {"stringValue": "43"}
          },
          "createTime": "\(createTime)",
          "updateTime": "\(updateTime)"
        }
        """
    }

    private static func decode(_ json: String) throws -> Country {
        try JSONDecoder.firestore().decode(Country.self, from: Data(json.utf8))
    }

    @Test func decodesAllFields() throws {
        let country = try Self.decode(Self.document())

        #expect(country.ID == "oAgZVEWEOoJKdlNvYTSa")
        #expect(country.name == "Austria")
        #expect(country.currency == "EUR")
        #expect(country.capital == "Vienna")
        #expect(country.native == "Österreich")
        #expect(country.continent == "EU")
        #expect(country.phone == "43")
        #expect(country.languages == ["de"])
    }

    @Test func decodesFractionalTimestamps() throws {
        let country = try Self.decode(Self.document())

        var components = DateComponents(calendar: Calendar(identifier: .iso8601),
                                        timeZone: TimeZone(secondsFromGMT: 0),
                                        year: 2026, month: 8, day: 22, hour: 19, minute: 40, second: 40)
        let whole = try #require(components.date)
        #expect(abs(country.createTime.timeIntervalSince(whole) - 0.030617) < 0.001)

        components.day = 23
        components.hour = 8
        components.minute = 1
        components.second = 2
        let other = try #require(components.date)
        #expect(abs(country.updateTime.timeIntervalSince(other) - 0.5) < 0.001)
    }

    @Test(arguments: ["2026-08-22T19:40:40Z", "2026-08-22T19:40:40.1Z", "2026-08-22T19:40:40.123456789Z"])
    func decodesOtherTimestampPrecisions(timestamp: String) throws {
        let country = try Self.decode(Self.document(createTime: timestamp))
        #expect(abs(country.createTime.timeIntervalSince1970 - 1_787_427_640) < 1)
    }

    @Test func decodesManyLanguagesInOrder() throws {
        let values = ["de", "fr", "it", "rm"].map { #"{"stringValue": "\#($0)"}"# }.joined(separator: ",")
        let json = Self.document(languages: #""languages": {"arrayValue": {"values": [\#(values)]}},"#)

        #expect(try Self.decode(json).languages == ["de", "fr", "it", "rm"])
    }

    @Test func emptyLanguageArrayDecodesToEmpty() throws {
        let json = Self.document(languages: #""languages": {"arrayValue": {}},"#)
        #expect(try Self.decode(json).languages.isEmpty)
    }

    @Test func missingLanguagesDecodesToEmpty() throws {
        #expect(try Self.decode(Self.document(languages: nil)).languages.isEmpty)
    }

    @Test func missingRequiredFieldThrows() {
        let json = Self.document().replacingOccurrences(of: #""capital": {"stringValue": "Vienna"},"#, with: "")
        #expect(throws: DecodingError.self) { try Self.decode(json) }
    }

    @Test func invalidDateThrows() {
        #expect(throws: DecodingError.self) { try Self.decode(Self.document(createTime: "yesterday")) }
    }

    @Test func decodesDocumentsContainer() throws {
        let json = #"{"documents": [\#(Self.document()), \#(Self.document(id: "second", name: "Belgium", languages: nil))]}"#
        let container = try JSONDecoder.firestore().decode(DocumentsContainer.self, from: Data(json.utf8))

        #expect(container.documents.map(\.name) == ["Austria", "Belgium"])
        #expect(container.documents.map(\.ID) == ["oAgZVEWEOoJKdlNvYTSa", "second"])
    }
}

struct CountryDisplayTests {
    private func country(continent: String = "EU", phone: String = "43", languages: [String] = ["de"]) throws -> Country {
        let values = languages.map { #"{"stringValue": "\#($0)"}"# }.joined(separator: ",")
        let json = """
        {"name": "projects/x/documents/countries/id1",
         "fields": {"currency": {"stringValue": "EUR"}, "native": {"stringValue": "n"},
                    "name": {"stringValue": "Name"}, "capital": {"stringValue": "Cap"},
                    "continent": {"stringValue": "\(continent)"}, "phone": {"stringValue": "\(phone)"},
                    "languages": {"arrayValue": {"values": [\(values)]}}},
         "createTime": "2026-08-22T19:40:40.030617Z", "updateTime": "2026-08-22T19:40:40.030617Z"}
        """
        return try JSONDecoder.firestore().decode(Country.self, from: Data(json.utf8))
    }

    @Test(arguments: [("AF", "Africa"), ("AN", "Antarctica"), ("AS", "Asia"), ("EU", "Europe"),
                      ("NA", "North America"), ("OC", "Oceania"), ("SA", "South America"), ("XX", "XX")])
    func continentName(code: String, expected: String) throws {
        #expect(try country(continent: code).continentName == expected)
    }

    @Test func phonePrefixAddsPlus() throws {
        #expect(try country(phone: "43").phonePrefix == "+43")
        #expect(try country(phone: "1684").phonePrefix == "+1684")
    }

    @Test func languageNamesUseLocaleAndKeepCode() throws {
        let english = Locale(identifier: "en")
        #expect(try country(languages: ["de", "af"]).languageNames(locale: english) == ["German (de)", "Afrikaans (af)"])
        #expect(try country(languages: ["de"]).languageNames(locale: Locale(identifier: "de")) == ["Deutsch (de)"])
    }

    @Test func unknownLanguageCodeFallsBackToCode() throws {
        #expect(try country(languages: ["zz"]).languageNames(locale: Locale(identifier: "en")) == ["zz"])
    }

    @Test func noLanguagesGivesEmptyList() throws {
        #expect(try country(languages: []).languageNames().isEmpty)
    }

    @Test func manyLanguagesAreAllKeptInOrder() throws {
        let codes = ["af", "en", "nr", "st", "ss", "tn", "ts", "ve", "xh", "zu"]
        let names = try country(languages: codes).languageNames(locale: Locale(identifier: "en"))
        #expect(names.count == 10)
        #expect(names.first == "Afrikaans (af)")
        #expect(names.last == "Zulu (zu)")
    }
}
