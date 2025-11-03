//
//  ViewController.swift
//  AppWatcher
//
//  Created by D K on 07.10.2025.
//

import SwiftUI

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        showGame()
                
                func showGame() {
                    let mainView = AppRoot()
                    let hostingController = UIHostingController(rootView: mainView)
                    
                    addChild(hostingController)
                    view.addSubview(hostingController.view)
                    hostingController.didMove(toParent: self)
                    
                    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                        hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                        hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
                    ])
                }
    }


}

