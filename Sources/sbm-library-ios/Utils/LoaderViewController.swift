//
//  LoaderViewController.swift
//  sbm-smart-ios
//
//  Created by Varun on 31/01/24.
//

import Foundation
import UIKit
import SwiftUI

@available(iOS 16.0, *)
class LoaderViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let loaderView = UIHostingController(rootView: LoaderView())
        addChild(loaderView)
        view.addSubview(loaderView.view)
        loaderView.didMove(toParent: self)
        loaderView.view.frame = view.bounds
    }
}
