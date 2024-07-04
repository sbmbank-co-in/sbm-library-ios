//
//  SwiftUIView.swift
//
//
//  Created by Varun on 27/12/23.
//

import SwiftUI

@available(iOS 13.0, *)
struct DeviceBindingWaitingView: View {
    
    @ObservedObject var viewModel: DeviceBindingViewModel
    
    var body: some View {
        ZStack {
            switch viewModel.currentScreen {
            case .waiting:
                WaitingView(viewModel: viewModel)
            case .failure:
                FailureView(currentScreen: $viewModel.currentScreen)
            case .mpinsetup:
                MPINSetupViewWrapper(isMPINSet: false, partner: viewModel.partner, onSuccess: viewModel.onSuccess, onReset: viewModel.onReset)
            }
            
            if viewModel.isLoading {
                LoaderView()
            }
        }
        .sheet(isPresented: $viewModel.isShowingMessageCompose, onDismiss: viewModel.startPolling) {
            MessageComposeView(recipients: ["9220592205"], body: "CGFWT \(viewModel.deviceAuthCode)")
        }
        .loader(isLoading: $viewModel.isLoading)
    }
    
    enum Screen {
        case waiting, failure, mpinsetup
    }
}



//@available(iOS 16.0, *)
//#Preview {
//    DeviceBindingWaitingView(viewModel: <#DeviceBindingViewModel#>, bank: "spense", partner: "spense", onSuccess: {
//        print("Success DeviceBindingWaitingView")
//    }, onReset: {
//        print("Reset DeviceBindingWaitingView")
//    })
//}
