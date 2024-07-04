import SwiftUI

@available(iOS 13.0, *)
struct MPINSetupViewWrapper: View {
    var isMPINSet: Bool
    var partner: String
    var onSuccess: () -> Void
    var onReset: () -> Void
    
    var body: some View {
            if #available(iOS 15.0, *) {
                MPINSetupView15(isMPINSet: isMPINSet, partner: partner, onSuccess: onSuccess, onReset: onReset)
            } else {
                MPINSetupView13(isMPINSet: isMPINSet, partner: partner, onSuccess: onSuccess, onReset: onReset)
            }
        }
    
}
