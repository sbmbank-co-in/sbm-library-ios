//
//  EnvManager.swift
//
//
//  Created by Varun on 01/02/24.
//

struct EnvManager {
    @MainActor static var hostName = "https://partner.uat.spense.money"
    @MainActor static var whitelistedUrls: Array<String> = []
    @MainActor static var deviceBindingEnabled = true
    @MainActor static var navigationBarDisabled = true
}
