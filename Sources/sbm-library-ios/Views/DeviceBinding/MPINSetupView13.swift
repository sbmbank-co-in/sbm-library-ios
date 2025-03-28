//
//  MPINSetupView.swift
//  SDKSample
//
//  Created by Varun on 28/12/23.
//

import SwiftUI
import Combine
import LocalAuthentication

@available(iOS 13.0, *)
struct MPINSetupView13: View {
    @State private var pinDigits: [String] = Array(repeating: "", count: 4)
    @State private var focusedField: Int? = 0
    @State var isMPINSet: Bool
    @State private var otpEntered = 0
    @State private var mPIN = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var resetPinFlow = false
    @State private var isPinDisabled = false
    @State private var wrongPinCount = 0
    @State private var isLoading = false
    private let maxWrongAttempts = 3
    private let context = LAContext()
    @Environment(\.presentationMode) var presentationMode
    var partner: String
    var onSuccess: () -> Void
    var onReset: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(alignment: .leading) {
                    headerView
                    HStack {
                        Spacer()
                        ForEach(0..<4, id: \.self) { index in
                            PinDigitView13(digit: $pinDigits[index], onBackspace: {
                                handleBackspace(at: index)
                            }, index: index, focusedField: $focusedField)
                            .disabled(isPinDisabled)
                        }
                        Spacer()
                    }
                    if isMPINSet {
                        if isPinDisabled {
                            HStack {
                                Spacer()
                                Text("You have entered wrong Mpin 3 times. \nPlease try after 30 mins or change Mpin")
                                    .foregroundColor(Color(hex: 0xB3261E))
                                    .font(.system(size: 14))
                                    .multilineTextAlignment(.center)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top)
                        }
                        HStack {
                            Spacer()
                            Text("Forgot Mpin?")
                                .font(.footnote)
                            Button(action:  {
                                SharedPreferenceManager.shared.setValue("", forKey: "MPIN")
                                SharedPreferenceManager.shared.setValue("", forKey: "MPIN_TIME")
                                SharedPreferenceManager.shared.setValue("", forKey: "MPIN_DISABLED_TIME")

                                isPinDisabled = false
                                self.presentationMode.wrappedValue.dismiss()
                                onReset()
                            }) {
                                Text("Change Mpin")
                                    .font(.footnote)
                                    .foregroundColor(Color(hex: 0x037EAB))
                            }
                            Spacer()
                        }.padding(.top, 24)
                    }
                    continueButton
                    if isMPINSet && !resetPinFlow {
                        if isFaceIDAvailable() {
                            HStack {
                                Rectangle().frame(width: .infinity, height: 1)
                                    .opacity(0.3)
                                Text("or")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: 0x9E9E9E))
                                Rectangle().frame(width: .infinity, height: 1)
                                    .opacity(0.3)
                            }.padding(.top, 24)
                            HStack {
                                Spacer()
                                Button(action:  {
                                    authenticateUser()
                                }) {
                                    Text("Use Face ID").font(.footnote)
                                        .foregroundColor(Color(hex: 0x666666))
                                    Image(systemName: "faceid")
                                        .foregroundColor(Color(hex: 0x037EAB))
                                }
                                Spacer()
                            }.padding(.top)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .onAppear {
                    if isPinDisabled {
                        focusedField = nil
                    } else {
                        focusedField = 0
                    }
                    Task {
                        await getServerTime()
                    }
                }
                
                if isLoading {
                    LoaderView()
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading) {
            if (resetPinFlow) {
                if (otpEntered == 0) {
                    Text("Enter old MPIN")
                        .font(.system(size: 22)).bold()
                        .padding(.top)
                    
                    Text("Your MPIN needs to be changed after 90 days")
                        .font(.subheadline)
                        .padding(EdgeInsets(top: 2, leading: 0, bottom: 48, trailing: 0))
                } else if otpEntered == 1 {
                    Text("Enter new MPIN")
                        .font(.system(size: 22)).bold()
                        .padding(.top)
                    
                    Text("Enter a 4 digit pin to setup secure login")
                        .font(.subheadline)
                        .padding(EdgeInsets(top: 2, leading: 0, bottom: 48, trailing: 0))
                } else {
                    Text("Re-enter new MPIN")
                        .font(.system(size: 22)).bold()
                        .padding(.top)
                    
                    Text("Re-enter the 4 digit pin to setup secure login")
                        .font(.subheadline)
                        .padding(EdgeInsets(top: 2, leading: 0, bottom: 48, trailing: 0))
                }
            } else {
                Text(isMPINSet ? "Enter MPIN" : otpEntered == 0 ? "Setup MPIN" : "Re-enter Mpin")
                    .font(.system(size: 22)).bold()
                    .padding(.top)
                
                Text(isMPINSet ? "Enter your 4 digit pin to login securely" : otpEntered == 0 ? "Add a 4 digit pin to setup secure login" : "Re-enter the 4 digit pin to setup secure login")
                    .font(.subheadline)
                    .padding(EdgeInsets(top: 2, leading: 0, bottom: 48, trailing: 0))
            }
        }
    }

    private var continueButton: some View {
        Button(action: continueButtonAction) {
            Text("Continue").font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: 0x037EAB))
                .cornerRadius(8)
        }
        .padding(.top, 24)
    }

    private func getServerTime() async {
        do {
            let response = try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.TIME)!, method: "GET")
            let serverTime = response["time"] as! NSNumber
            let mpinTime = Int(Double(SharedPreferenceManager.shared.getValue(forKey: "MPIN_TIME") ?? String(describing: serverTime)) ?? Double(truncating: serverTime))
            if (abs(Int(truncating: serverTime) - mpinTime) >= 7776000000) {
                resetPinFlow = true
            }
            
            let mpinDisabledTime = Int(Double(SharedPreferenceManager.shared.getValue(forKey: "MPIN_DISABLED_TIME") ?? String(describing: (Int(truncating: serverTime)*10))) ?? Double(Int(truncating: serverTime)*10))
            if (abs(Int(truncating: serverTime) - mpinDisabledTime) < 1800000) {
                isPinDisabled = true
            } else {
                isPinDisabled = false
                SharedPreferenceManager.shared.setValue("", forKey: "MPIN_DISABLED_TIME")
            }
        } catch {
            print(error)
        }
    }

    private func handleBackspace(at index: Int) {
        if index > 0 && pinDigits[index].isEmpty {
            pinDigits[index - 1] = ""
            focusedField = index - 1
        } else {
            pinDigits[index] = ""
        }
    }

    private func isFaceIDAvailable() -> Bool {
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return true
        }
        return false
    }

    private func authenticateUser() {
        let reason = "We need to unlock your data."
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
            DispatchQueue.main.async {
                if success {
                    Task {
                        await setupDeviceSession()
                    }
                    wrongPinCount = 0
                } else {
                    self.alertMessage = "There was a problem authenticating you."
                    presentAlert(withTitle: "Authentication Error", withMessage: "There was a problem authenticating you.")
                }
            }
        }
    }

    private func continueButtonAction() {
        let enteredPin = pinDigits.joined()
        if (enteredPin == "" || enteredPin.count < 4) {
            presentAlert(withTitle: "Error", withMessage: "Please enter a 4 digit PIN to proceed")
            return
        }
        if resetPinFlow {
            let savedPin = SharedPreferenceManager.shared.getValue(forKey: "MPIN") ?? ""
            if otpEntered == 0 {
                if (enteredPin == savedPin) {
                    otpEntered += 1
                    resetPinFields()
                } else {
                    presentAlert(withTitle: "Incorrect MPIN", withMessage: "Please check the MPIN you entered")
                }
            } else if otpEntered == 1 {
                if enteredPin == savedPin {
                    presentAlert(withTitle: "Same MPIN", withMessage: "New MPIN can't be same as the old pin")
                } else {
                    mPIN = enteredPin
                    otpEntered += 1
                    resetPinFields()
                }
            } else {
                if enteredPin == mPIN {
                    handleConfirmedMPIN(mPIN)
                } else {
                    presentAlert(withTitle: "Incorrect MPIN", withMessage: "Please check the MPIN you entered")
                    resetPinFields()
                }
            }
        } else {
            if otpEntered == 0 {
                mPIN = enteredPin
                if isMPINSet {
                    verifyPin(enteredPin)
                } else {
                    otpEntered += 1
                    resetPinFields()
                }
            } else {
                if enteredPin == mPIN {
                    handleConfirmedMPIN(mPIN)
                } else {
                    presentAlert(withTitle: "Incorrect PIN", withMessage: "Please check the MPIN you entered")
                    resetPinFields()
                }
            }
        }
    }

    private func resetPinFields() {
        pinDigits = Array(repeating: "", count: 4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = 0
        }
    }

    private func verifyPin(_ enteredPin: String) {
        let savedPin = SharedPreferenceManager.shared.getValue(forKey: "MPIN") ?? ""
        if enteredPin == savedPin {
            Task {
                await setupDeviceSession()
            }
            wrongPinCount = 0
        } else {
            resetPinFields()
            wrongPinCount += 1
            if wrongPinCount >= maxWrongAttempts {
                isPinDisabled = true
                SharedPreferenceManager.shared.setValue(String((Date().timeIntervalSince1970)*1000), forKey: "MPIN_DISABLED_TIME")
            } else {
                presentAlert(withTitle: "Incorrect PIN", withMessage: "Please check the MPIN you entered")
            }
        }
    }

    private func handleConfirmedMPIN(_ mPIN: String) {
        SharedPreferenceManager.shared.setValue(mPIN, forKey: "MPIN")
        SharedPreferenceManager.shared.setValue(String((Date().timeIntervalSince1970)*1000), forKey: "MPIN_TIME")
        Task {
            await setupDeviceSession()
        }
    }

    private func presentAlert(withTitle title: String, withMessage message: String) {
        showAlert = true
        alertTitle = title
        alertMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showAlert = false
        }
    }

    private func setupDeviceSession() async {
        isLoading = true
        do {
            let parameters = ["device_uuid": await UIDevice.current.identifierForVendor?.uuidString, "manufacturer": "Apple", "model": await UIDevice.modelName, "os": "iOS", "os_version": await UIDevice.current.systemVersion, "app_version": PackageInfo.version] as [String : Any]
            let response = try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.DEVICE_SESSION.dynamicParams(with: ["partner": partner]))!, method: "POST", jsonPayload: parameters)
            isLoading = false
            if response["code"] as? String == "DEVICE_BINDED_SESSION_FAILURE" {
                print(response)
            } else {
                onSuccess()
            }
        } catch {
            print(error)
            isLoading = false
        }
    }
}


//
//@available(iOS 16.0, *)
//#Preview {
//    MPINSetupView(isMPINSet: true, onSuccess: {
//        print("Success")
//    }, onReset: {
//        print("Reset Success")
//    })
//}
