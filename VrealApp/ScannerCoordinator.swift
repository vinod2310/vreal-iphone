//
//  ScannerCoordinator.swift
//  VrealApp
//
//  Created by vinod on 6/6/2025.
//


import AVFoundation
import UIKit
import SwiftUI

class ScannerCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    private var captureSession: AVCaptureSession?
    private weak var previewView: UIView?
    @Binding private var scannedCode: String?

    init(scannedCode: Binding<String?>) {
        _scannedCode = scannedCode
    }

    func startScanning(in viewController: UIViewController) {
        let view = viewController.view!
        previewView = view
        view.backgroundColor = .black

        let session = AVCaptureSession()
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            return
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else { return }

        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        session.startRunning()
        captureSession = session
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        if let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let value = object.stringValue {
            captureSession?.stopRunning()
            scannedCode = value
        }
    }

    deinit {
        captureSession?.stopRunning()
    }
}
