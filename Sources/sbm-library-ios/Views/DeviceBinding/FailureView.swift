//
//  SwiftUIView.swift
//  
//
//  Created by Varun on 27/12/23.
//

import SwiftUI

@available(iOS 13.0, *)
struct FailureView: View {
    @Binding var currentScreen: DeviceBindingWaitingView.Screen

    var body: some View {
        VStack {
            Text("Device Verification Failed\nGo Back")
                .multilineTextAlignment(.center)
                .font(.system(size: 18, weight: .semibold))
            
            Button(action: {
                currentScreen = .waiting
            }) {
                Text("Retry")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color(hex: 0x037EAB))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0xF5F5F5))
    }
}


//#Preview {
//    FailureView()
//}
