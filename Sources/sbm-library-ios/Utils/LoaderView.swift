//
//  LoaderView.swift
//  sbm-smart-ios
//
//  Created by Varun on 30/01/24.
//

import SwiftUI

@available(iOS 13.0, *)

struct CoinFlipModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isAnimating ? 3600 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(
                Animation.timingCurve(0.5, 0, 1, 0.5, duration: 5)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}
struct LoaderView: View {
    var bodyText: String
    
    private let svgString = """
    <svg xmlns="http://www.w3.org/2000/svg" width="101" height="100" viewBox="0 0 101 100" fill="none">
    <g clip-path="url(#clip0_7248_55333)">
    <path d="M49.9166 97.6731C76.2465 97.6731 97.591 76.3285 97.591 49.9986C97.591 23.6688 76.2465 2.32422 49.9166 2.32422C23.5868 2.32422 2.24219 23.6688 2.24219 49.9986C2.24219 76.3285 23.5868 97.6731 49.9166 97.6731Z" fill="#D7D7D9"/>
    <g filter="url(#filter0_i_7248_55333)">
    <path d="M49.9221 94.766C74.4859 94.766 94.3988 74.8531 94.3988 50.2892C94.3988 25.7254 74.4859 5.8125 49.9221 5.8125C25.3582 5.8125 5.44531 25.7254 5.44531 50.2892C5.44531 74.8531 25.3582 94.766 49.9221 94.766Z" fill="#D4D4D8"/>
    </g>
    <g filter="url(#filter1_f_7248_55333)">
    <path d="M49.917 89.5332C70.146 89.5332 86.5449 73.1343 86.5449 52.9053C86.5449 32.6762 70.146 16.2773 49.917 16.2773C29.6879 16.2773 13.2891 32.6762 13.2891 52.9053C13.2891 73.1343 29.6879 89.5332 49.917 89.5332Z" fill="#A1A1AA"/>
    </g>
    <path d="M49.917 86.9199C70.146 86.9199 86.5449 70.521 86.5449 50.292C86.5449 30.0629 70.146 13.6641 49.917 13.6641C29.6879 13.6641 13.2891 30.0629 13.2891 50.292C13.2891 70.521 29.6879 86.9199 49.917 86.9199Z" fill="#E4E4E7"/>
    <mask id="mask0_7248_55333" style="mask-type:alpha" maskUnits="userSpaceOnUse" x="27" y="26" width="46" height="47">
    <rect x="27.25" y="26.7422" width="45.3488" height="45.3488" fill="#D9D9D9"/>
    </mask>
    <g mask="url(#mask0_7248_55333)">
    <path d="M36.6999 56.9761V47.5284C36.6999 46.9931 36.8809 46.5443 37.2431 46.1821C37.6053 45.82 38.054 45.6389 38.5894 45.6389C39.1248 45.6389 39.5735 45.82 39.9357 46.1821C40.2978 46.5443 40.4789 46.9931 40.4789 47.5284V56.9761C40.4789 57.5115 40.2978 57.9602 39.9357 58.3224C39.5735 58.6846 39.1248 58.8656 38.5894 58.8656C38.054 58.8656 37.6053 58.6846 37.2431 58.3224C36.8809 57.9602 36.6999 57.5115 36.6999 56.9761ZM48.0371 56.9761V47.5284C48.0371 46.9931 48.2181 46.5443 48.5803 46.1821C48.9425 45.82 49.3912 45.6389 49.9266 45.6389C50.462 45.6389 50.9107 45.82 51.2729 46.1821C51.6351 46.5443 51.8161 46.9931 51.8161 47.5284V56.9761C51.8161 57.5115 51.6351 57.9602 51.2729 58.3224C50.9107 58.6846 50.462 58.8656 49.9266 58.8656C49.3912 58.8656 48.9425 58.6846 48.5803 58.3224C48.2181 57.9602 48.0371 57.5115 48.0371 56.9761ZM32.9208 66.4238C32.3854 66.4238 31.9367 66.2427 31.5745 65.8805C31.2123 65.5184 31.0312 65.0696 31.0312 64.5342C31.0312 63.9989 31.2123 63.5501 31.5745 63.188C31.9367 62.8258 32.3854 62.6447 32.9208 62.6447H66.9324C67.4678 62.6447 67.9165 62.8258 68.2787 63.188C68.6409 63.5501 68.822 63.9989 68.822 64.5342C68.822 65.0696 68.6409 65.5184 68.2787 65.8805C67.9165 66.2427 67.4678 66.4238 66.9324 66.4238H32.9208ZM59.3743 56.9761V47.5284C59.3743 46.9931 59.5554 46.5443 59.9175 46.1821C60.2797 45.82 60.7284 45.6389 61.2638 45.6389C61.7992 45.6389 62.2479 45.82 62.6101 46.1821C62.9723 46.5443 63.1533 46.9931 63.1533 47.5284V56.9761C63.1533 57.5115 62.9723 57.9602 62.6101 58.3224C62.2479 58.6846 61.7992 58.8656 61.2638 58.8656C60.7284 58.8656 60.2797 58.6846 59.9175 58.3224C59.5554 57.9602 59.3743 57.5115 59.3743 56.9761ZM66.9324 41.8598H32.7318C32.2594 41.8598 31.8579 41.6945 31.5273 41.3638C31.1966 41.0332 31.0312 40.6316 31.0312 40.1592V39.12C31.0312 38.7736 31.1179 38.4744 31.2911 38.2225C31.4643 37.9705 31.6926 37.7658 31.976 37.6084L48.226 29.4834C48.7614 29.2314 49.3282 29.1055 49.9266 29.1055C50.525 29.1055 51.0918 29.2314 51.6272 29.4834L67.7827 37.5611C68.1291 37.7186 68.3889 37.9548 68.5621 38.2697C68.7354 38.5846 68.822 38.9153 68.822 39.2617V39.9703C68.822 40.5057 68.6409 40.9544 68.2787 41.3166C67.9165 41.6787 67.4678 41.8598 66.9324 41.8598Z" fill="url(#paint0_linear_7248_55333)"/>
    </g>
    </g>
    <defs>
    <filter id="filter0_i_7248_55333" x="5.44531" y="5.8125" width="92.4415" height="93.6043" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">
    <feFlood flood-opacity="0" result="BackgroundImageFix"/>
    <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape"/>
    <feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/>
    <feOffset dx="3.48837" dy="4.65116"/>
    <feGaussianBlur stdDeviation="2.32558"/>
    <feComposite in2="hardAlpha" operator="arithmetic" k2="-1" k3="1"/>
    <feColorMatrix type="matrix" values="0 0 0 0 0.335254 0 0 0 0 0.316947 0 0 0 0 0.316947 0 0 0 0.25 0"/>
    <feBlend mode="normal" in2="shape" result="effect1_innerShadow_7248_55333"/>
    </filter>
    <filter id="filter1_f_7248_55333" x="0.382085" y="3.37037" width="99.0718" height="99.0679" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">
    <feFlood flood-opacity="0" result="BackgroundImageFix"/>
    <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape"/>
    <feGaussianBlur stdDeviation="6.45349" result="effect1_foregroundBlur_7248_55333"/>
    </filter>
    <linearGradient id="paint0_linear_7248_55333" x1="49.9266" y1="29.1055" x2="49.9266" y2="66.4238" gradientUnits="userSpaceOnUse">
    <stop stop-color="#B6B6BB"/>
    <stop offset="1" stop-color="#9C9CA0"/>
    </linearGradient>
    <clipPath id="clip0_7248_55333">
    <rect width="100" height="100" fill="white" transform="translate(0.5)"/>
    </clipPath>
    </defs>
    </svg>
    """
    
    init(bodyText: String = "Processing") {
        self.bodyText = bodyText
    }
    @available(iOS 13.0, *)

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)
            VStack {
                // Replace the ProgressView with SVG
                Image(uiImage: loadSVGImage())
                    .resizable()
                    .frame(width: 75, height: 75)
                    .modifier(CoinFlipModifier())
                    .padding(.horizontal, 48)
                
                Text("Please wait!")
                                   .font(.system(size: 12, weight: .semibold))
                                   .foregroundColor(Color.black)
                                   .padding(.top)
                               
                               // Process text
                               Text(bodyText)
                                   .font(.system(size: 12))
                                   .foregroundColor(Color.gray)
                                   .padding(.top, 2)
                           }
            .padding(24)
            .background(Color.white)
            .cornerRadius(12)
            .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.2)
        }
    }
    
    private func loadSVGImage() -> UIImage {
        guard let data = svgString.data(using: .utf8),
              let image = UIImage(data: data) else {
            return UIImage()
        }
        return image
    }
}
@available(iOS 13.0, *)
extension View {
    func coinFlipAnimation() -> some View {
        self.modifier(CoinFlipModifier())
    }
}
