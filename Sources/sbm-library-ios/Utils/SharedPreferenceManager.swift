//
//  SharedPreferenceManager.swift
//  SDKSample
//
//  Created by Varun on 29/12/23.
//

import Foundation

@MainActor
class SharedPreferenceManager {
    static let shared = SharedPreferenceManager()

    private let defaults = UserDefaults.standard

    func setValue(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func getValue(forKey key: String) -> String? {
        return defaults.string(forKey: key)
    }
}
