//
//  File.swift
//
//
//  Created by Varun on 30/01/24.
//

import CryptoKit
import Foundation
import Security

@available(iOS 13.0, *)
struct EncryptionManager {
    static func generateAESKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    static func encryptAES(data: String, key: SymmetricKey) -> Data? {
        guard let dataToEncrypt = data.data(using: .utf8) else { return nil }
        let iv = AES.GCM.Nonce()
        
        do {
            let sealedBox = try AES.GCM.seal(dataToEncrypt, using: key, nonce: iv)
            // Combine IV, ciphertext, and tag
            return iv + sealedBox.ciphertext + sealedBox.tag
        } catch {
            print("Encryption error: \(error)")
            return nil
        }
    }
    
    static func decryptAES(encryptedData: Data, key: SymmetricKey) -> String? {
        // AES GCM tag is typically 16 bytes (128 bits)
        let tagLength = 16
        
        guard encryptedData.count > 12 + tagLength else {
            print("Decryption error: Data too short")
            return nil
        }
        
        let iv = encryptedData.prefix(12)
        let tagAndCiphertext = encryptedData.dropFirst(12)
        guard let tag = tagAndCiphertext.suffix(tagLength) as? Data,
              let ciphertext = tagAndCiphertext.dropLast(tagLength) as? Data else {
            print("Decryption error: Unable to extract tag and ciphertext")
            return nil
        }
        
        do {
            let nonce = try AES.GCM.Nonce(data: iv)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("Decryption error: \(error)")
            return nil
        }
    }
    
    static func encryptRSA(dataToEncrypt: Data, publicKey: SecKey) -> String? {
        let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
        guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
            print("Algorithm not supported.")
            return nil
        }
        
        var error: Unmanaged<CFError>?
        guard let cipherText = SecKeyCreateEncryptedData(publicKey, algorithm, dataToEncrypt as CFData, &error) else {
            if let error = error?.takeRetainedValue() {
                print("Encryption error: \(error)")
            }
            return nil
        }
        
        return (cipherText as Data).base64EncodedString()
    }
    
    static func decryptRSA(base64EncodedString: String, privateKey: SecKey) -> String? {
        guard let dataToDecrypt = Data(base64Encoded: base64EncodedString) else {
            print("Failed to decode base64 string")
            return nil
        }
        
        let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
        guard SecKeyIsAlgorithmSupported(privateKey, .decrypt, algorithm) else {
            print("Algorithm not supported.")
            return nil
        }
        
        var error: Unmanaged<CFError>?
        guard let clearText = SecKeyCreateDecryptedData(privateKey, algorithm, dataToDecrypt as CFData, &error) else {
            if let error = error?.takeRetainedValue() {
                print("Decryption error: \(error)")
            }
            return nil
        }
        
        return String(data: clearText as Data, encoding: .utf8)
    }
    
    static func getPublicKeyAndKid() async throws -> (SecKey, String) {
        let (publicKeyString, kid) = try await getPublicKeyAndKidString()
        let publicKey = try convertPEMStringToSecKey(publicKeyString)
        return (publicKey, kid)
    }
    
    private static func getPublicKeyAndKidString() async throws -> (String, String) {
        if let keyWeb = SharedPreferenceManager.shared.getValue(forKey: StorageKeys.keyWeb),
           let kid = SharedPreferenceManager.shared.getValue(forKey: StorageKeys.kid),
           let expiryString = SharedPreferenceManager.shared.getValue(forKey: StorageKeys.keyWebExpiry),
           let expiryDate = Double(expiryString) {
            
            let currentTime = Date().timeIntervalSince1970 * 1000
            
            if currentTime < expiryDate {
                return (keyWeb, kid)
            }
        }
        
        let response = try await fetchPublicKeyResponse()
        
        var latestExpiry: Double = 0
        var latestPublicKey: String?
        var latestKid: String?
        
        for (_, keyData) in response {
            guard let publicKey = keyData["public"],
                  let kid = keyData["kid"],
                  let expiryString = keyData["expiry"] else {
                continue
            }
            
            guard let expiryDate = parseExpiryDate(expiryString) else {
                continue
            }
            
            if expiryDate > latestExpiry {
                latestExpiry = expiryDate
                latestPublicKey = publicKey
                latestKid = kid
            }
        }
        
        // Validate before returning
        guard let finalPublicKey = latestPublicKey,
              let finalKid = latestKid,
              !finalPublicKey.isEmpty else {
            throw NetworkError.invalidPublicKey
        }
        
        // Store values
        SharedPreferenceManager.shared.setValue(finalPublicKey, forKey: StorageKeys.keyWeb)
        SharedPreferenceManager.shared.setValue(finalKid, forKey: StorageKeys.kid)
        SharedPreferenceManager.shared.setValue(String(latestExpiry), forKey: StorageKeys.keyWebExpiry)
        
        return (finalPublicKey, finalKid)
    }
    
    private static func fetchPublicKeyResponse() async throws -> [String: [String: String]] {
        let (data, _) = try await URLSession.shared.data(from: URL(string: ServiceNames.NETWORK_KEYS)!)
        
        guard let response = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: [String: String]] else {
            throw NetworkError.invalidPublicKey
        }
        return response
    }
    
    private static func parseExpiryDate(_ dateString: String) -> Double? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        guard let date = dateFormatter.date(from: dateString) else {
            return nil
        }
        
        return date.timeIntervalSince1970 * 1000 // Convert to milliseconds
    }
    
    static func convertPEMStringToSecKey(_ pemString: String) throws -> SecKey {
        let base64String = pemString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
        
        guard let data = Data(base64Encoded: base64String) else {
            throw NetworkError.invalidPublicKey
        }
        
        let options: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic
        ]
        
        guard let secKey = SecKeyCreateWithData(data as CFData, options as CFDictionary, nil) else {
            throw NetworkError.invalidPublicKey
        }
        
        return secKey
    }
    
    enum KeyConversionError: Error {
        case invalidPrivateKey, dataConversionFailed, attributesMissing
    }
    
    static func convertPEMToPrivateKey(pemString: String) throws -> SecKey {
        // Ensure the PEM string format is correctly prepared for base64 decoding
        let base64String = pemString
            .replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\r\n", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "") // Ensure no spaces are included
        
        print("Base64 String Length: \(base64String.count)")
        
        guard let data = Data(base64Encoded: base64String) else {
            print("Failed to convert base64 string to Data")
            throw NetworkError.invalidPrivateKey
        }
        
        print("Data Length: \(data.count) bytes")
        
        let options: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateWithData(data as CFData, options as CFDictionary, &error) else {
            if let error = error {
                print("Error creating private key: \(error.takeRetainedValue())")
            }
            throw NetworkError.invalidPrivateKey
        }
        
        return privateKey
    }
}

private enum StorageKeys {
    static let keyWeb = "key_web"
    static let kid = "kid"
    static let keyWebExpiry = "key_web_expiry"
}
