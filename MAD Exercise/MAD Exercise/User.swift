//
//  User.swift
//  MAD Exercise
//

import Foundation

struct User: Codable {
    let localId: String
    let email: String
    let displayName: String
    let idToken: String
    let registered: Bool
    let refreshToken: String
}
