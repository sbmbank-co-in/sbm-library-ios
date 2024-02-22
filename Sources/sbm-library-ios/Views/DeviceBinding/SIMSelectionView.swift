//
//  SwiftUIView.swift
//  
//
//  Created by Varun on 27/12/23.
//

import SwiftUI

@available(iOS 16.0, *)
struct SIMSelectionView: View {
    @Binding var selectedSIM: Int?
    @Binding var currentScreen: DeviceBindingWaitingView.Screen

    var body: some View {
        VStack {
            Text("Select a SIM Card")
                .font(.system(size: 16, weight: .semibold))

            Text("Please select the SIM with which you are logged in for successful device verification")
                .font(.system(size: 12))
                .padding(.bottom, 16)

            // SIM List - Replace with actual data
            List(0..<2, id: \.self) { index in
                Text("SIM \(index + 1)")
                    .onTapGesture {
                        selectedSIM = index
                        // Add your SIM selection handling logic here
                        currentScreen = .waiting
                    }
            }
        }
        .padding()
    }
}

//
//#Preview {
//    SIMSelectionView()
//}
