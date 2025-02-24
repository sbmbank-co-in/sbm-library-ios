//
//  NetworkManager.swift
//  SDKTest
//
//  Created by Varun on 30/10/23.
//

import Foundation
import UIKit

@available(iOS 13.0, *)
public class NetworkManager {
    public static let shared = NetworkManager()
    
    private init() {}
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        return URLSession(configuration: configuration)
    }()
    
    public func makeRequest(url: URL, method: String, headers: [String: String]? = nil, jsonPayload: [String: Any]? = nil) async throws -> [String: Any] {
        let encrypted = true
        var mandatoryHeaders = headers ?? [String: String]()
        mandatoryHeaders["device_uuid"] = await UIDevice.current.identifierForVendor?.uuidString
        mandatoryHeaders["manufacturer"] = "Apple"
        mandatoryHeaders["model"] = await UIDevice.modelName
        mandatoryHeaders["os"] = "iOS"
        mandatoryHeaders["os_version"] = await UIDevice.current.systemVersion
        mandatoryHeaders["app_version"] = PackageInfo.version
        if encrypted {
            return try await makeEncryptedRequest(url: url, method: method, headers: mandatoryHeaders, jsonPayload: jsonPayload)
        }
        return try await makeRawRequest(url: url, method: method, headers: mandatoryHeaders, jsonPayload: jsonPayload)
    }
    
    private func makeRawRequest(url: URL, method: String, headers: [String: String]?, jsonPayload: [String: Any]? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Set headers if provided
        headers?.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Set JSON payload if provided
        if let jsonPayload = jsonPayload {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: jsonPayload)
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                throw error
            }
        }
        
        let (data, _) = try await session.data(for: request)
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
            guard let jsonDictionary = json as? [String: Any] else {
                throw NetworkError.invalidJSONFormat
            }
            return jsonDictionary
        } catch {
            throw error
        }
    }
    
    private func makeEncryptedRequest(url: URL, method: String, headers: [String: String]? = nil, jsonPayload: [String: Any]? = nil) async throws -> [String: Any] {
        
        do {
            let (publicKey, kid) = try await EncryptionManager.getPublicKeyAndKid()
            
            let aesKey = EncryptionManager.generateAESKey()
            let aesKeyData = Data(aesKey.withUnsafeBytes { Array($0) })
            
            guard let encryptedAESKey = EncryptionManager.encryptRSA(dataToEncrypt: aesKeyData.base64EncodedData(), publicKey: publicKey) else {
                throw NetworkError.encryptionFailed
            }
            
            var requestHeaders = headers ?? [String: String]()
            requestHeaders["key"] = encryptedAESKey
            requestHeaders["kid"] = kid
            
            
            var encryptedPayload: [String: Any]? = nil
            if let jsonPayload = jsonPayload {
                guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonPayload),
                      let jsonString = String(data: jsonData, encoding: .utf8) else {
                    throw NetworkError.invalidJSONFormat
                }
                
                guard let encryptedData = EncryptionManager.encryptAES(data: jsonString, key: aesKey) else {
                    throw NetworkError.encryptionFailed
                }
               encryptedPayload = ["encrypted": encryptedData.base64EncodedString()]
            }
             
            let response = try await makeRawRequest(url: url, method: method, headers: requestHeaders, jsonPayload: encryptedPayload)
            if let encryptedResponseString = response["encrypted"] as? String,
               let encryptedResponseData = Data(base64Encoded: encryptedResponseString) {
                guard let decryptedString = EncryptionManager.decryptAES(encryptedData: encryptedResponseData, key: aesKey) else {
                    throw NetworkError.decryptionFailed
                }
                
                guard let jsonData = decryptedString.data(using: .utf8),
                      let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    throw NetworkError.invalidJSONFormat
                }
                return jsonObject
            } else {
                return response
            }
        } catch {
            throw error
        }
    }
}

enum NetworkError: Error, Equatable {
    case noData
    case invalidJSONFormat
    case invalidPublicKey
    case encryptionFailed
    case decryptionFailed
    case invalidPrivateKey
}
