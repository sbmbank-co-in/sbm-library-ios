//
//  File.swift
//
//
//  Created by Varun on 26/12/23.
//

import Foundation

@available(iOS 13.0, *)
public class PartnerLibrarySingleton {
    public static let shared = PartnerLibrarySingleton()
    
    private var library: PartnerLibrary?
    
    public func initialize(withHostName hostName: String, deviceBindingEnabled: Bool = true, whitelistedUrls: Array<String>, navigationBarDisabled: Bool = true, deeplinkScreenMap: [String: String] = [:]) {
        guard library == nil else {
            debugPrint("Error: Library is already initialized. Call reset() to reinitialize.")
            return
        }
        library = PartnerLibrary(hostName: hostName, deviceBindingEnabled: deviceBindingEnabled, whitelistedUrls: whitelistedUrls, navigationBarDisabled: navigationBarDisabled,deeplinkScreenMap:deeplinkScreenMap)
    }
    
    public var instance: PartnerLibrary {
        guard let library = library else {
            fatalError("PartnerLibrarySingleton is not initialized. Call initialize(withHostName:) first.")
        }
        return library
    }
    
    public func reset() {
        library = nil
    }
}
