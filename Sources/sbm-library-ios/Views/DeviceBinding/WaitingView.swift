//
//  SwiftUIView.swift
//
//
//  Created by Varun on 27/12/23.
//

import SwiftUI

@available(iOS 13.0, *)
struct WaitingView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: DeviceBindingViewModel
    
    private func initiateDeviceBinding() async {
        do {
            let parameters = await ["device_binding_id": viewModel.deviceBindingId, "device_uuid": UIDevice.current.identifierForVendor?.uuidString, "manufacturer": "Apple", "model": UIDevice.modelName, "os": "iOS", "os_version": UIDevice.current.systemVersion, "app_version": PackageInfo.version] as [String : Any]
            let response = try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.DEVICE_BIND.dynamicParams(with: ["partner": viewModel.partner]))!, method: "POST", jsonPayload: parameters)
            viewModel.isLoading = false
            if let authCode = response["device_auth"] as? String {
                DispatchQueue.main.async {
                    self.viewModel.deviceAuthCode = authCode
                    self.viewModel.deviceId = response["device_id"] as! Int
                    self.viewModel.isShowingMessageCompose = true
                }
            } else {
                viewModel.currentScreen = .failure
            }
        } catch {
            print(error)
            viewModel.isLoading = false
            viewModel.currentScreen = .failure
        }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(alignment: .leading) {
                    Image(systemName: "arrow.backward")
                        .padding(.top, 16)
                        .padding(.leading, 12).onTapGesture {
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    Text("Let's secure your app")
                        .font(.system(size: 20, weight: .semibold))
                        .padding(.top, 28)
                        .padding(.leading, 16)
                    Text("You will setup an MPIN for this application. On click of continue, ensure the below mentioned points")
                        .font(.system(size: 12))
                        .padding(.top, 1)
                        .padding(.leading, 16)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "simcard")
                            Text("On click of continue, select the SIM with the registered mobile number")
                                .font(.system(size: 14))
                                .padding(.leading, 10)
                        }.padding(.horizontal, 12)
                            .padding(.top, 10)
                        
                        Rectangle().frame(width: .infinity, height: 0.2).opacity(0.3)
                            .padding(.vertical, 10)
                        
                        HStack {
                            Image(systemName: "iphone.and.arrow.forward")
                            Text("Grant permission for calls and message")
                                .font(.system(size: 14))
                                .padding(.leading, 10)
                            
                        }.padding(.leading, 12)
                            .padding(.bottom, 10)
                    }
                    .background(Color(hex: 0xFFFFFF))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 32)
                    
                    Button(action: {
                        Task {
                            await initiateDeviceBinding()
                        }
                    }) {
                        Text("Continue").font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: 0x037EAB))
                            .cornerRadius(8)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal)
                }
            }.background(Color(hex: 0xF5F5F5))
        }.navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: EmptyView())
            .loader(isLoading: $viewModel.isLoading)
    }
}
