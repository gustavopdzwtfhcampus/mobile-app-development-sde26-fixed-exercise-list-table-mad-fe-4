//
//  ContentView.swift
//  MAD Exercise
//
//  Created by Gustavo Podzuweit on 28.09.26.
//

import SwiftUI

struct ContentView: View {
    private enum Field {
        case email
        case password
    }

    @State private var networking = Networking()
    @State private var email: String = "mad-fe@mad.at"
    @State private var password: String = "madmad"
    @State private var showValidationError: Bool = false
    @State private var showLoginResultAlert: Bool = false
    @State private var loginResultMessage: String = ""
    @State private var isLoggingIn: Bool = false
    @FocusState private var focusedField: Field?

    var body: some View {
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

            Spacer()
        }
        .padding()
        .disabled(isLoggingIn)
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
                loginResultMessage = "You are now logged in as \(user.email)."
            } else if let error {
                switch error {
                case .serializationFailed:
                    loginResultMessage = "Something went wrong preparing your request. Please try again."
                case .invalidEmailFormat:
                    loginResultMessage = "Please enter a valid email address."
                case .emailNotFound, .wrongPassword, .invalidCredentials:
                    loginResultMessage = "Email or password is incorrect."
                case .networkUnavailable:
                    loginResultMessage = "You appear to be offline. Please check your connection and try again."
                case .unexpectedResponseFormat:
                    loginResultMessage = "Received an unexpected response from the server. Please try again."
                case .serverError:
                    loginResultMessage = "The server ran into a problem. Please try again later."
                case .unknown:
                    loginResultMessage = "An unexpected error occurred. Please try again."
                }
            }

            showLoginResultAlert = true
        }
    }
}

#Preview {
    ContentView()
}
