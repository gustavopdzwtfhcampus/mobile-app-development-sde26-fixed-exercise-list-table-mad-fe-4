//
//  LoginView.swift
//  MAD Exercise
//
//  Created by Gustavo Podzuweit on 28.09.26.
//

import SwiftUI

struct LoginView: View {
    private enum Field {
        case email
        case password
    }

    @Environment(Networking.self) private var networking
    @State private var email: String = "mad-fe@mad.at"
    @State private var password: String = "madmad"
    @State private var showValidationError: Bool = false
    @State private var showLoginResultAlert: Bool = false
    @State private var loginResultMessage: String = ""
    @State private var loggedInUser: User?
    @State private var showCountries: Bool = false
    @State private var isLoggingIn: Bool = false
    @FocusState private var focusedField: Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                    TextField("yourname@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .onSubmit {
                            focusedField = .password
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                    SecureField("Your password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            login()
                        }
                }

                if showValidationError {
                    Text("Please fill in both email and password.")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                HStack {
                    Spacer()
                    Button("Login") {
                        login()
                    }
                    Spacer()
                }
                .padding(.top, 8)

                if isLoggingIn {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .disabled(isLoggingIn)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showCountries) {
            if let loggedInUser {
                CountriesView(user: loggedInUser)
            }
        }
        .alert("Login", isPresented: $showLoginResultAlert) {
            Button("OK", role: .cancel) {
            }
        } message: {
            Text(loginResultMessage)
        }
    }

    private func login() {
        guard !email.isEmpty, !password.isEmpty else {
            showValidationError = true
            return
        }
        showValidationError = false
        isLoggingIn = true

        networking.login(email: email, password: password) { user, error in
            isLoggingIn = false

            if let user {
                loggedInUser = user
                showCountries = true
                return
            }

            if let error {
                loginResultMessage = error.userMessage
            }

            showLoginResultAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .environment(Networking())
}
