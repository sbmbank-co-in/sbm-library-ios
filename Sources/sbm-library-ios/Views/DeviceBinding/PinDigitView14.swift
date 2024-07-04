//
//  File.swift
//  
//
//  Created by Varun on 04/07/24.
//

import SwiftUI

@available(iOS 14.0, *)
struct PinDigitView14: View {
    @Binding var digit: String
    var onBackspace: () -> Void
    let index: Int
    @State private var previousDigit = ""
    
    var body: some View {
        TextField("", text: $digit)
            .font(.system(size: 20, weight: .semibold))
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .frame(width: 48, height: 48)
            .background(Color(hex: 0xEBECEF))
            .cornerRadius(8)
            .onChange(of: digit) { newValue in
                if newValue.isEmpty && !previousDigit.isEmpty {
                    onBackspace()
                }
                previousDigit = digit
            }
            .onReceive(digit.publisher.collect()) {
                self.digit = String($0.prefix(1))
            }
    }
}
