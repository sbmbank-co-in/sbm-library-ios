//
//  SBMLibrary.swift
//  sbm-library-ios
//
//  Created by Varun on 13/11/23.
//

import SwiftUI
import UIKit
import WebKit

@available(iOS 13.0, *)
public class PartnerLibrary {

    private var hostName = EnvManager.hostName
    private var deviceBindingEnabled = EnvManager.deviceBindingEnabled
    var preloadedWebVC: WebViewController?
    var onMPINSetupSuccess: (() -> Void)?

    private weak var parentNavigationController: UINavigationController?

    public func setParentNavigationController(_ navController: UINavigationController) {
        self.parentNavigationController = navController
    }
    private var deeplinkScreenMap: [String: String] = [:]
    init(
        hostName: String, deviceBindingEnabled: Bool, whitelistedUrls: [String],
        navigationBarDisabled: Bool
            // , deeplinkScreenMap:[String: String]
    ) {
        self.hostName = hostName
        self.deviceBindingEnabled = deviceBindingEnabled
        //self.deeplinkScreenMap = deeplinkScreenMap
        EnvManager.hostName = hostName
        EnvManager.deviceBindingEnabled = deviceBindingEnabled
        EnvManager.whitelistedUrls = whitelistedUrls
        EnvManager.navigationBarDisabled = navigationBarDisabled
        //
        AnalyticsLogger.logEvent(["event": "IOS_SDK_INITIALIZED"])
        Task {
            await preloadWebView()
        }
    }
    public func getDeeplinkScreenMap() -> [String: String] { return deeplinkScreenMap }

    public func getSDKConfig() async -> [String: Any] {
        do {
            print("webview config fn called")
            return try await NetworkManager.shared.makeRequest(
                url: URL(string: ServiceNames.IOS_SDK_CONFIG)!, method: "GET")
        } catch {
            debugPrint("Failed to fetch SDK config: \(error)")
            return [:]
        }
    }

    func extractWebViewConfig(from response: [String: Any]) -> [String: Any]? {
        guard let type = response["type"] as? String, type == "success",
            let data = response["data"] as? [String: Any],
            let info = data["info"] as? [String: Any]
        else {
            return nil
        }
        return info
    }

    private func preloadWebView() async {
        do {
            // Fetch SDK config first
            let sdkConfigResponse = try await getSDKConfig()
            let webViewConfig: [String: Any] = extractWebViewConfig(from: sdkConfigResponse) ?? [:]

            let preloadURL = "\(EnvManager.hostName)"
            let tempVC = UIViewController()
            let webVC = await WebViewController(
                urlString: preloadURL,
                originalViewController: tempVC,
                completion: { _ in
                    debugPrint("here")
                },
                config: webViewConfig
            )

            await clearWebViewCacheAndCookies()
            _ = await webVC.view

            if let url = URL(string: preloadURL),
                let cookies = HTTPCookieStorage.shared.cookies(for: url),
                let wkWebView = webVC as? WKWebView
            {
                let cookieStore: WKHTTPCookieStore = await wkWebView.configuration.websiteDataStore
                    .httpCookieStore
                for cookie in cookies {
                    await cookieStore.setCookie(cookie, completionHandler: nil)
                }
            }

            self.preloadedWebVC = webVC
        } catch {
            debugPrint("Failed to load SDK config: \(error)")
            // Fallback to loading without config
            let preloadURL = "\(EnvManager.hostName)"
            let tempVC = UIViewController()
            let webVC = await WebViewController(
                urlString: preloadURL,
                originalViewController: tempVC,
                completion: { _ in debugPrint("here")
                },
                //                config: webViewConfig
            )

            await clearWebViewCacheAndCookies()
            _ = await webVC.view

            self.preloadedWebVC = webVC
        }
    }

    private func checkLogin() async throws -> [String: Any] {
        return try await NetworkManager.shared.makeRequest(
            url: URL(string: ServiceNames.LOGGED_IN)!, method: "GET")
    }

    private func login(token: String) async throws -> [String: Any] {
        return try await NetworkManager.shared.makeRequest(
            url: URL(string: ServiceNames.LOGIN)!, method: "POST", jsonPayload: ["token": token])
    }

    private func clearWebViewCacheAndCookies() async {
        // Clear WKWebsiteDataStore
        AnalyticsLogger.logEvent(["event": "IOS_CLEARING_WEBVIEW_COOKIES"])

        debugPrint("Clearing cookies....")

        //        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        // print("[WebCacheCleaner] All cookies deleted")

        WKWebsiteDataStore.default().fetchDataRecords(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()
        ) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(
                    ofTypes: record.dataTypes, for: [record], completionHandler: {})
                //  print("[WebCacheCleaner] Record \(record) deleted")
            }
        }

        debugPrint("Cleared all WebView cache and cookies")
    }

    public func open(
        on viewController: UIViewController, token: String, module: String,
        callback: @escaping (WebViewCallback) -> Void
    ) async throws {
        //        let checkLoginResponse = try await checkLogin()
        //        print("checkLoginResponse: \(checkLoginResponse)")
        //
        //        if checkLoginResponse["type"] as! String == "success" {
        //            if checkLoginResponse["is_loggedin"] as! Int == 1 {
        //                DispatchQueue.main.async {
        //                    // Pass the original view controller directly
        //                    let viewTransitionCoordinator = ViewTransitionCoordinator(viewController: viewController)
        //                    viewTransitionCoordinator.startProcess(module: module, completion: callback)
        //                }
        //            } else {
        AnalyticsLogger.logEvent(["event": "IOS_OPEN_FN_CALLED", "module": module])

        let loginResponse = try await login(token: token)
        print("loginResponse: \(loginResponse)")
        AnalyticsLogger.logEvent([
            "event": "IOS_LOGIN_API_CALLED", "module": module, "LOGIN_RESPONSE": "\(loginResponse)",
        ])

        DispatchQueue.main.async {
            // Pass the original view controller directly
            let viewTransitionCoordinator = ViewTransitionCoordinator(
                viewController: viewController)
            viewTransitionCoordinator.startProcess(module: module, completion: callback)
        }
        //            }
        //        } else {
        //            _ = try await login(token: token)
        //            DispatchQueue.main.async {
        //                // Pass the original view controller directly
        //                let viewTransitionCoordinator = ViewTransitionCoordinator(viewController: viewController)
        //                viewTransitionCoordinator.startProcess(module: module, completion: callback)
        //            }
        //        }
    }

    private func findTopMostViewController() -> UIViewController {
        guard
            let window = UIApplication.shared.connectedScenes
                .filter({ $0.activationState == .foregroundActive })
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow })
        else {
            fatalError("No active window found")
        }

        var topMostViewController = window.rootViewController
        while let presentedViewController = topMostViewController?.presentedViewController {
            topMostViewController = presentedViewController
        }
        return topMostViewController!
    }

    func checkDeviceBinding(bank: String) async throws -> Bool {
        if !deviceBindingEnabled {
            return false
        }

        let onboardingNext = try await NetworkManager.shared.makeRequest(
            url: URL(
                string: ServiceNames.BANKING_ONBOARDING_NEXT.dynamicParams(with: ["bank": bank]))!,
            method: "GET")

        if onboardingNext["path"] != nil
            && ((onboardingNext["path"] as! String).contains("/onboarding/success"))
            || ((onboardingNext["path"] as! String).contains("/onboarding/complete"))
        {
            return true
        }

        return false
    }

    func bindDevice(
        on viewController: UIViewController, bank: String, partner: String,
        completion: @escaping () -> Void
    ) {
        Task {
            do {
                let toBindDevice = try await self.checkDeviceBinding(bank: bank)
                if toBindDevice {
                    let isMPINSet = !(SharedPreferenceManager.shared.getValue(forKey: "MPIN") ?? "")
                        .isEmpty
                    if isMPINSet {
                        self.presentMPINSetup(
                            on: viewController, partner: partner, completion: completion)
                    } else {
                        self.presentDeviceBinding(
                            on: viewController, bank: bank, partner: partner, completion: completion
                        )
                    }
                } else {
                    let parameters =
                        await [
                            "device_uuid": UIDevice.current.identifierForVendor?.uuidString,
                            "manufacturer": "Apple", "model": UIDevice.modelName, "os": "iOS",
                            "os_version": UIDevice.current.systemVersion,
                            "app_version": PackageInfo.version,
                        ] as [String: Any]
                    debugPrint(parameters)
                    let response = try await NetworkManager.shared.makeRequest(
                        url: URL(
                            string: ServiceNames.DEVICE_SESSION.dynamicParams(with: [
                                "partner": partner
                            ]))!, method: "POST", jsonPayload: parameters)
                    debugPrint("Bind Device to Session response: \(response)")
                    AnalyticsLogger.logEvent([
                        "event": "IOS_DEVICE_BINDING_API_CALLED",
                        "DEVICE_BINDING_API_RESPONSE": "\(response)",
                    ])

                    if response["code"] as? String == "DEVICE_BINDED_SESSION_FAILURE" {
                        completion()
                    } else {
                        completion()
                    }
                }
            } catch {
                debugPrint(error)
                completion()
            }
        }
    }

    private func presentMPINSetup(
        on viewController: UIViewController, partner: String, completion: @escaping () -> Void
    ) {
        let rootView = AnyView(
            MPINSetupViewWrapper(
                isMPINSet: true, partner: partner,
                onSuccess: {
                    completion()
                },
                onReset: {
                    self.bindDevice(
                        on: viewController, bank: partner, partner: partner, completion: completion)
                }))
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.modalPresentationStyle = .fullScreen
        viewController.present(hostingController, animated: true)
    }

    private func presentDeviceBinding(
        on viewController: UIViewController, bank: String, partner: String,
        completion: @escaping () -> Void
    ) {
        let viewModel = DeviceBindingViewModel(
            bank: bank, partner: partner,
            onSuccess: {
                completion()
            },
            onReset: {
                self.bindDevice(
                    on: viewController, bank: bank, partner: partner, completion: completion)
            })
        let rootView = AnyView(DeviceBindingWaitingView(viewModel: viewModel))
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.modalPresentationStyle = .fullScreen
        viewController.present(hostingController, animated: true)
    }
}

@available(iOS 13.0, *)
class ViewTransitionCoordinator {
    public var viewController: UIViewController
    public var loaderViewController: LoaderViewController?
    private let library = PartnerLibrarySingleton.shared.instance

    init(viewController: UIViewController) {
        self.viewController = viewController
    }

    func startProcess(module: String, completion: @escaping (WebViewCallback) -> Void) {
        //        DispatchQueue.main.async {
        //            self.presentLoaderView()
        //        }

        presentLoaderView()

        Task {
            MainActor.self
            await bindDevice(module: module)

            self.dismissLoaderView()

            await self.openLibrary(module: module) { callback in
                //                self.dismissLoaderView()
                completion(callback)
            }
        }

    }

    private func presentLoaderView() {
        loaderViewController = LoaderViewController()
        loaderViewController?.modalPresentationStyle = .overFullScreen
        viewController.present(loaderViewController!, animated: false)
    }

    private func dismissLoaderView() {
        DispatchQueue.main.async {
            self.loaderViewController?.dismiss(animated: false) {
                self.loaderViewController = nil
            }
        }
    }

    private func bindDevice(module: String) async {
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
            debugPrint("bind device complete")
        }
    }

    private func openLibrary(module: String, completion: @escaping (WebViewCallback) -> Void) async
    {

        let sdkConfigResponse = await library.getSDKConfig()
        let webViewConfig = library.extractWebViewConfig(from: sdkConfigResponse)
        DispatchQueue.main.async {
            let webVC: WebViewController
            let newUrl = "\(EnvManager.hostName)\(module)"
            let screenMap = self.library.getDeeplinkScreenMap()

            if let preloaded = self.library.preloadedWebVC {
                preloaded.originalViewController = self.viewController

                webVC = preloaded
                webVC.setCallback { result in
                    completion(result)
                }
                // webVC.setDeeplinkScreenMap(screenMap)
                webVC.updateAndReload(with: newUrl)
            } else {
                webVC = WebViewController(
                    urlString: "\(EnvManager.hostName)\(module)",
                    originalViewController: self.viewController,
                    completion: { result in
                        completion(result)
                    },
                    config: webViewConfig

                )

            }

            if let navController = self.viewController.navigationController {
                debugPrint("Using view controller's navigation controller: \(navController)")
                navController.pushViewController(webVC, animated: false)
                navController.setNavigationBarHidden(
                    EnvManager.navigationBarDisabled, animated: false)
                AnalyticsLogger.logEvent(["event": "IOS_WEBVIEW_OPEN_CALLED"])
                debugPrint("Navigation stack after push: \(navController.viewControllers)")
            } else {
                debugPrint("No navigation controller found, falling back to modal presentation")
                let navVC = UINavigationController(rootViewController: webVC)
                navVC.modalPresentationStyle = .fullScreen
                navVC.setNavigationBarHidden(EnvManager.navigationBarDisabled, animated: false)
                self.viewController.present(navVC, animated: false)
            }
        }
    }
}

public enum LibraryError: Error {
    case hostnameNotSet
}
