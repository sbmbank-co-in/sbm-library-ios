//
//  File.swift
//  
//
//  Created by Varun on 30/01/24.
//

import SwiftUI

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
@available(iOS 13.0, *)
extension View {
    func loader(isLoading: Binding<Bool>, bodyText: String = "Processing...") -> some View {
        self.modifier(LoaderModifier(isLoading: isLoading, bodyText: bodyText))
    }
    
   
}
