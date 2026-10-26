//
//  CameraScannerView.swift
//  VrealApp
//
//  Created by vinod on 6/6/2025.
//


import SwiftUI
import AVFoundation

struct CameraScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?

    func makeCoordinator() -> ScannerCoordinator {
        ScannerCoordinator(scannedCode: $scannedCode)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        context.coordinator.startScanning(in: viewController)
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
