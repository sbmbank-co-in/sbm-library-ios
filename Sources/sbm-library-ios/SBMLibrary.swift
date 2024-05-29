//
//  SBMLibrary.swift
//  sbm-library-ios
//
//  Created by Varun on 13/11/23.
//

import UIKit
import SwiftUI

@available(iOS 16.0, *)
public class SBMLibrary {
    
    private var hostName = EnvManager.hostName
    var onMPINSetupSuccess: (() -> Void)?
    
    init(hostName: String, whitelistedUrls: Array<String>) {
        self.hostName = hostName
        EnvManager.hostName = hostName
        EnvManager.whitelistedUrls = whitelistedUrls
    }
    
    public func checkLogin() async throws -> [String: Any] {
        return try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.LOGGED_IN)!, method: "GET")
    }
    
    public func login(token: String) async throws -> [String: Any] {
        let hostName = self.hostName
        return try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.LOGIN)!, method: "POST", jsonPayload: ["token": token])
    }
    
    public func bindDevice(on viewController: UIViewController, bank: String, partner: String, completion: @escaping () -> Void) {
        let isMPINSet = !(SharedPreferenceManager.shared.getValue(forKey: "MPIN") ?? "").isEmpty
        if (isMPINSet) {
            let rootView = AnyView(MPINSetupView(isMPINSet: true, partner: partner, onSuccess: {
                viewController.dismiss(animated: true, completion: completion)
            }, onReset: {
                self.bindDevice(on: viewController, bank: bank, partner: partner, completion: completion)
            }))
            
            let hostingController = UIHostingController(rootView: rootView)
            hostingController.modalPresentationStyle = .fullScreen
            viewController.present(hostingController, animated: true, completion: nil)
        } else {
            Task {
                let hostName = self.hostName
                do {
                    let checkProductsResponse = try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.BANKING_ACCOUNTS_COUNT.dynamicParams(with: ["bank": bank]))!, method: "GET")
                    if ((checkProductsResponse["count"] as! Int) < 1) {
                        await MainActor.run {
                            viewController.dismiss(animated: true, completion: completion)
                        }
                    } else {
                        let rootView = AnyView(BankingDetailsView(bank: bank, partner: partner, onSuccess: {
                            Task {
                                await MainActor.run {
                                    viewController.dismiss(animated: true, completion: completion)
                                }
                            }
                        }))
                        await MainActor.run {
                            let hostingController = UIHostingController(rootView: rootView)
                            hostingController.modalPresentationStyle = .fullScreen
                            viewController.present(hostingController, animated: true, completion: nil)
                        }
                    }
                } catch {
                    print(error)
                }
            }
        }
    }
    
    public func unbindDevice() {
        SharedPreferenceManager.shared.setValue("", forKey: "MPIN")
        SharedPreferenceManager.shared.setValue("", forKey: "MPIN_TIME")
        SharedPreferenceManager.shared.setValue("", forKey: "MPIN_DISABLED_TIME")
    }
    
    public func open(on viewController: UIViewController, withSlug slug: String) {
        let webVC = WebViewController(urlString: "\(EnvManager.hostName)\(slug)")
        let navVC = UINavigationController(rootViewController: webVC)
        navVC.modalPresentationStyle = .fullScreen
        viewController.present(navVC, animated: true, completion: nil)
    }
    
    public func getViewController(withSlug slug: String) -> UINavigationController {
        let webVC = WebViewController(urlString: "\(EnvManager.hostName)\(slug)")
        let navVC = UINavigationController(rootViewController: webVC)
        navVC.modalPresentationStyle = .fullScreen
        return navVC
    }
}

public enum SBMError: Error {
    case hostnameNotSet
}
