//
//  CountriesView.swift
//  MAD Exercise
//

import SwiftUI

struct CountriesView: View {
    @Environment(Networking.self) private var networking
    let user: User

    @State private var countries: [Country]?
    @State private var error: NetworkingError?
    @State private var isLoading: Bool = false

    var body: some View {
        content
            .navigationTitle("Countries")
            .onAppear {
                // Only download once; coming back from a pushed view re-triggers onAppear.
                if countries == nil && error == nil {
                    loadCountries()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let countries {
            if countries.isEmpty {
                ContentUnavailableView("No countries", systemImage: "globe")
            } else {
                List(countries, id: \.ID) { country in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(country.name)
                            .font(.headline)
                        Text(country.capital)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else if let error {
            ContentUnavailableView {
                Label("Couldn't load countries", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.userMessage)
            } actions: {
                Button("Try Again") {
                    loadCountries()
                }
            }
        } else {
            ProgressView("Loading countries…")
        }
    }

    private func loadCountries() {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        networking.fetchCountries(user: user) { countries, error in
            isLoading = false
            self.countries = countries
            self.error = error
        }
    }
}

#Preview {
    NavigationStack {
        CountriesView(user: User(localId: "id",
                                 email: "mad-fe@mad.at",
                                 displayName: "",
                                 idToken: "token",
                                 registered: true,
                                 refreshToken: "refresh"))
    }
    .environment(Networking())
}
