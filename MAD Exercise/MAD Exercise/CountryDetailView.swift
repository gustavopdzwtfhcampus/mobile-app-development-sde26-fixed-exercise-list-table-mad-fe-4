//
//  CountryDetailView.swift
//  MAD Exercise
//

import SwiftUI

struct CountryDetailView: View {
    let country: Country

    var body: some View {
        // A List scrolls, so any number of languages (and large text sizes or
        // landscape) fit without fixed sizes.
        List {
            Section("General") {
                LabeledContent("Name", value: country.name)
                LabeledContent("Native name", value: country.native)
                LabeledContent("Capital", value: country.capital)
                LabeledContent("Continent", value: country.continentName)
                LabeledContent("Currency", value: country.currency)
                LabeledContent("Phone prefix", value: country.phonePrefix)
            }

            Section("Languages") {
                let names = country.languageNames()
                if names.isEmpty {
                    Text("No languages listed")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(names, id: \.self) { name in
                        Text(name)
                    }
                }
            }

            Section("Record") {
                LabeledContent("Created",
                               value: country.createTime.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Updated",
                               value: country.updateTime.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("ID", value: country.ID)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(country.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Country {
    /// Full name for the continent codes used by the API; unknown codes are shown as is.
    var continentName: String {
        switch continent {
        case "AF": "Africa"
        case "AN": "Antarctica"
        case "AS": "Asia"
        case "EU": "Europe"
        case "NA": "North America"
        case "OC": "Oceania"
        case "SA": "South America"
        default: continent
        }
    }

    var phonePrefix: String {
        "+\(phone)"
    }

    /// "German (de)" for each language code, in the API's order. Codes the locale
    /// has no name for are shown as the bare code.
    func languageNames(locale: Locale = .current) -> [String] {
        languages.map { code in
            if let name = locale.localizedString(forLanguageCode: code), name != code {
                return "\(name) (\(code))"
            }
            return code
        }
    }
}

#Preview {
    NavigationStack {
        CountryDetailView(country: .preview)
    }
}

extension Country {
    /// Sample for previews.
    static var preview: Country {
        let json = """
        {"name": "projects/mad-fe/databases/(default)/documents/countries/abc123",
         "fields": {"currency": {"stringValue": "ZAR"}, "native": {"stringValue": "South Africa"},
                    "name": {"stringValue": "South Africa"}, "capital": {"stringValue": "Pretoria"},
                    "continent": {"stringValue": "AF"}, "phone": {"stringValue": "27"},
                    "languages": {"arrayValue": {"values": [{"stringValue": "af"}, {"stringValue": "en"},
                                                            {"stringValue": "zu"}]}}},
         "createTime": "2026-08-22T19:40:40.030617Z", "updateTime": "2026-08-22T19:40:40.030617Z"}
        """
        return try! JSONDecoder.firestore().decode(Country.self, from: Data(json.utf8))
    }
}
