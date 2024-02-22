//
//  File.swift
//  
//
//  Created by Varun on 26/12/23.
//

import Foundation

@available(iOS 16.0, *)
public class SBMLibrarySingleton {
    public static let shared = SBMLibrarySingleton()

    private var sbmLibrary: SBMLibrary?

    public func initialize(withHostName hostName: String) {
        guard sbmLibrary == nil else {
            print("Error: SBMLibrary is already initialized. Call reset() to reinitialize.")
            return
        }
        sbmLibrary = SBMLibrary(hostName: hostName)
    }

    public var instance: SBMLibrary {
        guard let library = sbmLibrary else {
            fatalError("SBMLibrarySingleton is not initialized. Call initialize(withHostName:) first.")
        }
        return library
    }

    public func reset() {
        sbmLibrary = nil
    }
}
