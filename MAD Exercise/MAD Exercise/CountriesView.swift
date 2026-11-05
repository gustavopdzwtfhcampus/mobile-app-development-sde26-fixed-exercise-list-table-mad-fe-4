//
//  CountriesView.swift
//  MAD Exercise
//

import SwiftUI

struct CountriesView: View {
    let user: User

    var body: some View {
        Text("Logged in as \(user.email)")
            .navigationTitle("Countries")
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
}
