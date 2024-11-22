//
//  SBMLibrary.swift
//  sbm-library-ios
//
//  Created by Varun on 13/11/23.
//

import UIKit
import SwiftUI

@available(iOS 13.0, *)
public class PartnerLibrary {
    
    private var hostName = EnvManager.hostName
    private var deviceBindingEnabled = EnvManager.deviceBindingEnabled
    var onMPINSetupSuccess: (() -> Void)?
    
    init(hostName: String, deviceBindingEnabled: Bool, whitelistedUrls: Array<String>, navigationBarDisabled: Bool) {
        self.hostName = hostName
        self.deviceBindingEnabled = deviceBindingEnabled
        EnvManager.hostName = hostName
        EnvManager.deviceBindingEnabled = deviceBindingEnabled
        EnvManager.whitelistedUrls = whitelistedUrls
        EnvManager.navigationBarDisabled = navigationBarDisabled
    }
    
    private func checkLogin() async throws -> [String: Any] {
        return try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.LOGGED_IN)!, method: "GET")
    }
    
    private func login(token: String) async throws -> [String: Any] {
        return try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.LOGIN)!, method: "POST", jsonPayload: ["token": token])
    }
    
    public func open(token: String, module: String, callback callback: @escaping (WebViewCallback) -> Void) async throws {
        let checkLoginResponse = try await checkLogin()
        if checkLoginResponse["type"] as! String == "success" {
            if checkLoginResponse["is_loggedin"] as! Int == 1 {
                DispatchQueue.main.async {
                    let viewTransitionCoordinator = ViewTransitionCoordinator(viewController: self.findTopMostViewController())
                    viewTransitionCoordinator.startProcess(module: module, completion: callback)
                }
            } else {
                try await login(token: token)
                DispatchQueue.main.async {
                    let viewTransitionCoordinator = ViewTransitionCoordinator(viewController: self.findTopMostViewController())
                    viewTransitionCoordinator.startProcess(module: module, completion: callback)
                }
            }
        }
    }
    
        private func findTopMostViewController() -> UIViewController {
            guard let window = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first else {
                fatalError("No active window found")
            }
    
            var topMostViewController = window.rootViewController
            while let presentedViewController = topMostViewController?.presentedViewController {
                topMostViewController = presentedViewController
            }
            return topMostViewController!
        }
    
    // In PartnerLibrary.swift
//    private func findTopMostViewController() -> UIViewController {
//        guard let window = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first else {
//            fatalError("No active window found")
//        }
//        
//        var topMostViewController = window.rootViewController
//        
//        // First traverse navigation controller stack
//        if let navigationController = topMostViewController as? UINavigationController {
//            topMostViewController = navigationController.visibleViewController ?? navigationController
//        }
//        
//        // Then traverse presented controllers
//        while let presentedViewController = topMostViewController?.presentedViewController {
//            if let navigationController = presentedViewController as? UINavigationController {
//                topMostViewController = navigationController.visibleViewController ?? presentedViewController
//            } else {
//                topMostViewController = presentedViewController
//            }
//        }
//        
//        return topMostViewController!
//    }
    
    
    func checkDeviceBinding(bank: String) async throws -> Bool {
        if !deviceBindingEnabled {
            return false
        }
        
        let onboardingNext = try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.BANKING_ONBOARDING_NEXT.dynamicParams(with: ["bank": bank]))!, method: "GET")
        
        if (onboardingNext["path"] != nil && ((onboardingNext["path"] as! String).contains("/onboarding/success")) || ((onboardingNext["path"] as! String).contains("/onboarding/complete"))) {
            return true
        }
        
        return false
    }
    
    func bindDevice(on viewController: UIViewController, bank: String, partner: String, completion: @escaping () -> Void) {
        Task {
            do {
                let toBindDevice = try await self.checkDeviceBinding(bank: bank)
                if (toBindDevice) {
                    let isMPINSet = !(SharedPreferenceManager.shared.getValue(forKey: "MPIN") ?? "").isEmpty
                    if (isMPINSet) {
                        self.presentMPINSetup(on: viewController, partner: partner, completion: completion)
                    } else {
                        self.presentDeviceBinding(on: viewController, bank: bank, partner: partner, completion: completion)
                    }
                } else {
                    let parameters = await ["device_uuid": UIDevice.current.identifierForVendor?.uuidString, "manufacturer": "Apple", "model": UIDevice.modelName, "os": "iOS", "os_version": UIDevice.current.systemVersion, "app_version": PackageInfo.version] as [String : Any]
                    let response = try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.DEVICE_SESSION.dynamicParams(with: ["partner": partner]))!, method: "POST", jsonPayload: parameters)
                    if response["code"] as? String == "DEVICE_BINDED_SESSION_FAILURE" {
                        completion()
                    } else {
                        completion()
                    }
                }
            } catch {
                print(error)
                completion()
            }
        }
    }
    
    private func presentMPINSetup(on viewController: UIViewController, partner: String, completion: @escaping () -> Void) {
        let rootView = AnyView(MPINSetupViewWrapper(isMPINSet: true, partner: partner, onSuccess: {
            completion()
        }, onReset: {
            self.bindDevice(on: viewController, bank: partner, partner: partner, completion: completion)
        }))
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.modalPresentationStyle = .fullScreen
        viewController.present(hostingController, animated: true)
    }
    
    private func presentDeviceBinding(on viewController: UIViewController, bank: String, partner: String, completion: @escaping () -> Void) {
        let viewModel = DeviceBindingViewModel(bank: bank, partner: partner, onSuccess: {
            completion()
        }, onReset: {
            self.bindDevice(on: viewController, bank: bank, partner: partner, completion: completion)
        })
        let rootView = AnyView(DeviceBindingWaitingView(viewModel: viewModel))
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.modalPresentationStyle = .fullScreen
        viewController.present(hostingController, animated: true)
    }
}

@available(iOS 13.0, *)
class ViewTransitionCoordinator {
    private var viewController: UIViewController
    private var loaderViewController: LoaderViewController?
    private let library = PartnerLibrarySingleton.shared.instance
    
    init(viewController: UIViewController) {
        self.viewController = viewController
    }
    
    func startProcess(module: String, completion: @escaping (WebViewCallback) -> Void) {
        presentLoaderView()
        bindDevice(module: module) {
            self.openLibrary(module: module) { callback in
                self.dismissLoaderView()
                completion(callback)
            }
        }
    }
    
    private func presentLoaderView() {
        loaderViewController = LoaderViewController()
        loaderViewController?.modalPresentationStyle = .overFullScreen
        viewController.present(loaderViewController!, animated: true)
    }
    
    private func dismissLoaderView() {
        DispatchQueue.main.async {
            self.loaderViewController?.dismiss(animated: true) {
                self.loaderViewController = nil
            }
        }
    }
    
    private func bindDevice(module: String, completion: @escaping () -> Void) {
        var partner = ""
        var bank = ""
        if module.contains("banking") {
            if let bankingRange = module.range(of: "banking/") {
                let startIndex = bankingRange.upperBound
                if let endIndex = module[startIndex...].range(of: "/")?.lowerBound {
                    bank = String(module[startIndex..<endIndex])
                    partner = bank
                }
            }
        }
        library.bindDevice(on: viewController, bank: bank, partner: partner) {
            completion()
        }
    }
    
    private func openLibrary(module: String, completion: @escaping (WebViewCallback) -> Void) {
        DispatchQueue.main.async {
            let webVC = WebViewController(urlString: "\(EnvManager.hostName)\(module)") { result in
                completion(result)
            }
            
            if let navigationController = self.viewController.navigationController {
                navigationController.pushViewController(webVC, animated: false)
                navigationController.setNavigationBarHidden(EnvManager.navigationBarDisabled, animated: false)
            } else {
                let navVC = UINavigationController(rootViewController: webVC)
                navVC.modalPresentationStyle = .fullScreen
                navVC.setNavigationBarHidden(EnvManager.navigationBarDisabled, animated: false)
                if let loaderVC = self.loaderViewController {
                    loaderVC.present(navVC, animated: true)
                } else {
                    self.viewController.present(navVC, animated: true)
                }
            }
        }
    }
}

public enum LibraryError: Error {
    case hostnameNotSet
}
