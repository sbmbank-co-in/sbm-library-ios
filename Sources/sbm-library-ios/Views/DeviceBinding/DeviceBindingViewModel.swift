//
//  File.swift
//  
//
//  Created by Varun on 04/07/24.
//

import SwiftUI
import Combine

@available(iOS 13.0, *)
class DeviceBindingViewModel: ObservableObject {
    @Published var currentScreen: DeviceBindingWaitingView.Screen = .waiting
    @Published var isShowingMessageCompose = false
    @Published var deviceAuthCode = ""
    @Published var deviceId = 0
    @Published var isLoading = false
    
    var timer: Timer? = nil
    var pollingCounter = 0
    var deviceBindingId = UUID().uuidString
    var bank: String
    var partner: String
    var onSuccess: () -> Void
    var onReset: () -> Void
    
    private var deviceAuthCodeCancellable: AnyCancellable?
    
    init(bank: String, partner: String, onSuccess: @escaping () -> Void, onReset: @escaping () -> Void) {
        self.bank = bank
        self.partner = partner
        self.onSuccess = onSuccess
        self.onReset = onReset

        deviceAuthCodeCancellable = $deviceAuthCode
            .sink { [weak self] newValue in
                if !newValue.isEmpty {
                    self?.isShowingMessageCompose = true
                }
            }
    }
    
    func startPolling() {
        isLoading = true
        pollingCounter = 0
        timer?.invalidate() // Invalidate any existing timer
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.pollingCounter < 6 {
                self.pollingCounter += 1
                Task {
                    await self.checkDeviceBindingStatus()
                }
            } else {
                self.timer?.invalidate()
                Task {
                    await self.handleFailure()
                }
            }
        }
    }
    
    func checkDeviceBindingStatus() async {
        do {
            let response = try await NetworkManager.shared.makeRequest(url: URL(string: (ServiceNames.DEVICE_BIND.dynamicParams(with: ["partner": partner])))!, method: "GET")
            if response["status"] as? String == "SUCCESS" {
                timer?.invalidate()
                isLoading = false
                SharedPreferenceManager.shared.setValue(deviceBindingId, forKey: "device_binding_id")
                SharedPreferenceManager.shared.setValue("\(deviceId)", forKey: "device_id")
                DispatchQueue.main.async {
                    self.currentScreen = .mpinsetup // Navigate to success view
                }
            } else if response["status"] as? String == "FAILURE" {
                timer?.invalidate()
                await handleFailure()
            }
        } catch {
            print(error)
            await handleFailure()
        }
    }
    
    func handleFailure() async {
        await failDeviceBinding()
        DispatchQueue.main.async {
            self.currentScreen = .failure
        }
    }
    
    func failDeviceBinding() async {
        do {
            let parameters = ["device_binding_id": deviceBindingId] as [String : Any]
            let response = try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.DEVICE_BIND.dynamicParams(with: ["partner": partner]))!, method: "DELETE", jsonPayload: parameters)
            isLoading = false
        } catch {
            print(error)
            isLoading = false
        }
    }
}
