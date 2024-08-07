//
//  LoaderView.swift
//  sbm-smart-ios
//
//  Created by Varun on 30/01/24.
//

import SwiftUI

@available(iOS 13.0, *)
struct LoaderView: View {
    var bodyText: String
    
    init(bodyText: String = "Processing") {
        self.bodyText = bodyText
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)
            VStack {
                if #available(iOS 14.0, *) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        .scaleEffect(1.75)
                        .frame(width: 75, height: 75)
                        .padding(.horizontal, 48)
                } else {
                    ActivityIndicator()
                                        .scaleEffect(1.75)
                                        .frame(width: 75, height: 75)
                                        .padding(.horizontal, 48)
                }
                
                Text("Please wait!")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: 0x212121))
                    .padding(.top)
                
                // Process text
                Text(bodyText)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x212121))
                    .padding(.top, 2)
            }
            .padding(24) // Adjust padding to match your Android layout
            .background(Color.white) // CardView background
            .cornerRadius(12) // Adjust the corner radius as per your Android `cardCornerRadius`
            .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.2) // Adjust width and height as needed
        }
    }
}

@available(iOS 13.0, *)
struct ActivityIndicator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .gray
        activityIndicator.startAnimating()
        return activityIndicator
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {}
}

@available(iOS 13.0, *)
struct LoaderModifier: ViewModifier {
    @Binding var isLoading: Bool
    var bodyText: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
            
            if isLoading {
                LoaderView(bodyText: bodyText)
            }
        }
    }
}
