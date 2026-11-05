//
//  Country.swift
//  MAD Exercise
//

import Foundation

// The project defaults to MainActor isolation, so these are marked nonisolated
// to be decodable from the URLSession callback's background thread.

nonisolated struct DocumentsContainer: Decodable {
    var documents: [Country]
}

/// One Firestore document from the `countries` collection. Firestore wraps every
/// value in a type tag (`{"stringValue": "..."}`), so decoding is done by hand.
/// Not `Identifiable`: the spec's `ID` property would clash with its `ID` associated
/// type, so lists identify countries with `id: \.ID`.
nonisolated struct Country: Decodable, Hashable {
    var ID: String
    var name: String
    var currency: String
    var capital: String
    var native: String
    var continent: String
    var phone: String
    var createTime: Date
    var updateTime: Date
    var languages: [String]

    private enum RootCodingKeys: String, CodingKey {
        case ID = "name"
        case createTime
        case updateTime
        case fields
    }

    private enum NestedCodingKeys: String, CodingKey {
        case name
        case currency
        case capital
        case native
        case continent
        case phone
        case languages
    }

    private enum StringValueCodingKeys: String, CodingKey {
        case stringValue
    }

    private enum ArrayValueCodingKeys: String, CodingKey {
        case arrayValue
    }

    private enum ArrayValueNestedCodingKeys: String, CodingKey {
        case values
    }

    init(from decoder: Decoder) throws {
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        ID = (try rootContainer.decode(String.self, forKey: .ID) as NSString).lastPathComponent
        createTime = try rootContainer.decode(Date.self, forKey: .createTime)
        updateTime = try rootContainer.decode(Date.self, forKey: .updateTime)

        let fields = try rootContainer.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .fields)

        func stringValue(for key: NestedCodingKeys) throws -> String {
            let container = try fields.nestedContainer(keyedBy: StringValueCodingKeys.self, forKey: key)
            return try container.decode(String.self, forKey: .stringValue)
        }

        name = try stringValue(for: .name)
        currency = try stringValue(for: .currency)
        capital = try stringValue(for: .capital)
        native = try stringValue(for: .native)
        continent = try stringValue(for: .continent)
        phone = try stringValue(for: .phone)

        // Firestore leaves out `languages`, `arrayValue`'s content or `values`
        // entirely for an empty array, so every level is optional.
        var languages: [String] = []
        if fields.contains(.languages) {
            let arrayContainer = try fields.nestedContainer(keyedBy: ArrayValueCodingKeys.self, forKey: .languages)
            if arrayContainer.contains(.arrayValue) {
                let valuesContainer = try arrayContainer.nestedContainer(keyedBy: ArrayValueNestedCodingKeys.self,
                                                                         forKey: .arrayValue)
                if valuesContainer.contains(.values) {
                    var list = try valuesContainer.nestedUnkeyedContainer(forKey: .values)
                    while !list.isAtEnd {
                        let element = try list.nestedContainer(keyedBy: StringValueCodingKeys.self)
                        languages.append(try element.decode(String.self, forKey: .stringValue))
                    }
                }
            }
        }
        self.languages = languages
    }
}

extension DateFormatter {
    /// Firestore timestamps, e.g. "2026-08-22T19:40:40.030617Z". The built-in
    /// `.iso8601` decoding strategy rejects the fractional seconds.
    nonisolated static let firestoreTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        return formatter
    }()
}

extension JSONDecoder {
    /// Decoder for Firestore responses. Tries the fractional-seconds format first
    /// and falls back to plain ISO 8601, since Firestore drops the fraction when
    /// it is zero.
    nonisolated static func firestore() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            if let date = DateFormatter.firestoreTimestamp.date(from: string) {
                return date
            }
            if let date = ISO8601DateFormatter().date(from: string) {
                return date
            }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported date format: \(string)"))
        }
        return decoder
    }
}
