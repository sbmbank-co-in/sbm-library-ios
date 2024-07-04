import SwiftUI

@available(iOS 13.0, *)
struct PinDigitView13: View {
    @Binding var digit: String
    var onBackspace: () -> Void
    let index: Int
    @Binding var focusedField: Int?

    var body: some View {
        CustomTextField13(text: $digit, onBackspace: onBackspace, isFocused: focusedField == index)
            .font(.system(size: 20, weight: .semibold))
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .frame(width: 48, height: 48)
            .background(Color(hex: 0xEBECEF))
            .cornerRadius(8)
            .onTapGesture {
                focusedField = index
            }
    }
}

@available(iOS 13.0, *)
struct CustomTextField13: UIViewRepresentable {
    @Binding var text: String
    var onBackspace: () -> Void
    var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self, onBackspace: onBackspace)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.keyboardType = .numberPad
        textField.textAlignment = .center
        textField.font = .systemFont(ofSize: 20, weight: .semibold)
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.layer.cornerRadius = 8
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if isFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CustomTextField13
        var onBackspace: () -> Void

        init(_ parent: CustomTextField13, onBackspace: @escaping () -> Void) {
            self.parent = parent
            self.onBackspace = onBackspace
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if let char = string.cString(using: String.Encoding.utf8) {
                let isBackSpace = strcmp(char, "\\b")
                if isBackSpace == -92 {
                    onBackspace()
                    return false
                }
            }

            guard string.count <= 1 else {
                return false
            }

            parent.text = string
            return false
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            guard let text = textField.text, text.count == 1 else { return }
            if let nextResponder = textField.superview?.viewWithTag(textField.tag + 1) as? UITextField {
                nextResponder.becomeFirstResponder()
            }
        }
    }
}
