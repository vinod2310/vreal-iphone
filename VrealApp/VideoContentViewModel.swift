//
//  VideoContentViewModel.swift
//  VideoRecorder
//
//  Created by Young Bin on 2023/06/11.
//

import AVFoundation
import Foundation
import Photos
import UIKit

class VideoContentViewModel: NSObject, ObservableObject,
    CLLocationManagerDelegate
{
    let session: AVCaptureSession
    let PHOTOBUCKET = "<YOUR_PHOTO_BUCKET>"
    let VIDEOBUCKET = "<YOUR_VIDEO_BUCKET>"
    var locationManager: CLLocationManager!
    var longitude: Double?
    var lattitide: Double?
    @Published var preview: Preview?
    @Published var statusMessage: String = "Video mode selected"
    var crypto: SecureEnclaveCrypto
    var privateKey: SecKey

    override init() {
        self.session = AVCaptureSession()
        
        do {

            self.crypto = try SecureEnclaveCrypto()
            self.privateKey = try self.crypto.getPrivateKey()!

        } catch {
            fatalError("Failed to initialize SecureEnclaveCrypto: \(error)")
            // Alternatively, you can show an error UI or set `statusMessage`
            // self.statusMessage = "Crypto init failed: \(error.localizedDescription)"
            // self.crypto = SecureEnclaveCrypto.mock() // Optional fallback
        }
        super.init()
        Task(priority: .background) {
            switch await AuthorizationChecker.checkCaptureAuthorizationStatus()
            {
            case .permitted:
                try session
                    .addMovieInput()
                    .addMovieFileOutput()
                    .addPhotoFileOutput()
                    .startRunning()

                DispatchQueue.main.async {
                    self.preview = Preview(
                        session: self.session,
                        gravity: .resizeAspectFill
                    )
                }

            case .notPermitted:
                break
            }

        }
        let myQueue = DispatchQueue(label: "myOwnQueue")
        myQueue.async {
            if CLLocationManager.locationServicesEnabled() {
                self.checkLocationServicesEnabled()
                // your code here
            }
        }

    }

    func checkLocationServicesEnabled() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager.requestWhenInUseAuthorization()

        } else {
            print("Location services not enabled")
        }
    }
    private func checkLocationAuthorization() {
        guard let locationManager = locationManager else {
            return
        }
        switch locationManager.authorizationStatus {

        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            print("Your location is restricted")
        case .denied:
            print("You have denied location for this app")
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        @unknown default:
            break
        }

    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()

    }
    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        if let location = locations.last {
            self.lattitide = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            // Stop updating location after receiving the first location update
            //            locationManager.stopUpdatingLocation()
        }
    }

    func startRecording() {
        guard let output = session.movieFileOutput else {
            print("Cannot find movie file output")
            return
        }
        statusMessage = "Recording started"
        guard
            let directoryPath = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first
        else {
            print("Cannot access local file domain")
            return
        }

        let fileName = UUID().uuidString

        let filePath =
            directoryPath
            .appendingPathComponent(fileName)
            .appendingPathExtension("mp4")

        output.startRecording(to: filePath, recordingDelegate: self)
    }

    func stopRecording() {
        guard let output = session.movieFileOutput else {
            print("Cannot find movie file output")
            return
        }
        statusMessage = "Recording stopped"
        output.stopRecording()
    }
    func clickPhoto() {
        guard let output = session.stillImageOutput else {
            print("Photo output not available")
            return
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto  // Optional: set flash mode if supported
        output.capturePhoto(with: settings, delegate: self)

    }

}
extension VideoContentViewModel: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?,
        previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        bracketSettings: AVCaptureBracketedStillImageSettings?,
        error: (any Error)?
    ) {
        if let unwrappedError = error {
            print(
                "Error capturing photo: \(unwrappedError.localizedDescription)"
            )
            return
        }

        if let buffer = photoSampleBuffer,
            let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(
                forJPEGSampleBuffer: buffer,
                previewPhotoSampleBuffer: nil
            ),
            let image = UIImage(data: imageData)
        {
            let formatter = DateFormatter()
            formatter.dateFormat = "ddMMyyyy_HHmmss"  // use "HH" for 24-hour format
            let metadataFileName = formatter.string(from: Date()) + ".metadata"
            let mediaFileName = formatter.string(from: Date()) + ".jpeg"
            let metaData = Metadata(
                fileName: metadataFileName,
                publicKey: crypto.getPublicKeybase64()
            )
            do {
                let documents = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                ).first!
                let fileURL = documents.appendingPathComponent(mediaFileName)
                try imageData.write(to: fileURL)
                print("Saved photo at: \(fileURL.path)")

                // Read first 1000 bytes from the file
                do {
                    let fileHandle = try FileHandle(forReadingFrom: fileURL)
                    defer { try? fileHandle.close() }
                    let chunkSize = 10000

                    appendSignatures(
                        fileHandle: fileHandle,
                        chunkSize: chunkSize,
                        metaData: metaData,
                        secKey: self.privateKey
                    )

                    S3Helper.uploadFileToS3(
                        bucketName: PHOTOBUCKET,
                        keyValue: mediaFileName,
                        fileURL: fileURL
                    )

                } catch {
                    print("Error reading file: \(error)")
                }

                //                   // Optional: Also save to photo album
                //                   if let image = UIImage(data: imageData) {
                //                       UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                //                   }

            } catch {
                print("Error saving photo to file: \(error)")
            }
            let metadatUrl = metaData.finalizeFileCreation(
                longitude: self.longitude ?? 0.0,
                lattitude: self.lattitide ?? 0.0
            )
            S3Helper.uploadFileToS3(
                bucketName: PHOTOBUCKET,
                keyValue: metadataFileName,
                fileURL: metadatUrl
            )
            Task {
                updateStatus("Publshed signed photo.")
                try await Task.sleep(nanoseconds: 2_000_000_000)
                updateStatus("")
            }
        }

    }

}

extension VideoContentViewModel: AVCaptureFileOutputRecordingDelegate {

    func generateThumnail(outputFileURL: URL, thumbnailName: String) {
        do {

            let asset = AVURLAsset(url: outputFileURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true  // Correct orientation

            // Capture the thumbnail at the 1-second mark (or use CMTime.zero for the beginning)
            let time = CMTime(seconds: 1, preferredTimescale: 600)
            let cgImage = try imageGenerator.copyCGImage(
                at: time,
                actualTime: nil
            )

            let thumbnail = UIImage(cgImage: cgImage)

            // Optional: save thumbnail to file
            if let data = thumbnail.jpegData(compressionQuality: 0.8) {
                let documents = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                ).first!
                let thumbnailURL = documents.appendingPathComponent(
                    thumbnailName
                )
                try data.write(to: thumbnailURL)

                print("Thumbnail saved at: \(thumbnailURL.path)")

                // Optional: upload thumbnail to S3
                S3Helper.uploadFileToS3(
                    bucketName: VIDEOBUCKET,
                    keyValue: thumbnailName,
                    fileURL: thumbnailURL
                )
            }

        } catch {
            print("Failed to generate thumbnail: \(error)")
        }

    }
    func appendSignatures(
        fileHandle: FileHandle,
        chunkSize: Int,
        metaData: Metadata,
        secKey: SecKey
    ) {
        var offset: UInt64 = 0
        do {
            while true {
                try fileHandle.seek(toOffset: offset)
                let chunk = try fileHandle.read(upToCount: chunkSize)

                // End of file
                if chunk == nil || chunk!.isEmpty {
                    break
                }
                let signature = crypto.sign(payload: chunk!, secKey: secKey)
                print("Signature for chunk at offset \(offset): \(signature)")
                metaData.addSignature(signature: signature)

                offset += UInt64(chunk!.count)
                print("Offset is : \(offset)")
            }
        } catch {
            print("Error reading file: \(error)")
        }
    }
    private func updateStatus(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessage = message
        }
    }
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        print("Video record is finished!")

        // ADDED
        Task {
            guard
                case .authorized = await PHPhotoLibrary.requestAuthorization(
                    for: .addOnly
                )
            else {
                print("Cannot gain authorization")
                return
            }

            let library = PHPhotoLibrary.shared()
            let album = try getAlbum(name: "YOUR_ALBUM_NAME", in: library)
            try await add(video: outputFileURL, to: album, library)

            let formatter = DateFormatter()
            formatter.dateFormat = "ddMMyyyy_HHmmss"  // use "HH" for 24-hour format
            let metadataFileName = formatter.string(from: Date()) + ".metadata"
            let thumbNailFilename = formatter.string(from: Date()) + ".jpeg"
            let mediaFileName = formatter.string(from: Date()) + ".mp4"
            let metaData = Metadata(
                fileName: metadataFileName,
                publicKey: crypto.getPublicKeybase64()
            )
            self.updateStatus("Signing..")

            // Read first 1000 bytes from the file
            do {
                let fileHandle = try FileHandle(forReadingFrom: outputFileURL)
                defer { try? fileHandle.close() }
                let chunkSize = 1_000_000
                appendSignatures(
                    fileHandle: fileHandle,
                    chunkSize: chunkSize,
                    metaData: metaData,
                    secKey: self.privateKey
                )

                S3Helper.uploadFileToS3(
                    bucketName: VIDEOBUCKET,
                    keyValue: mediaFileName,
                    fileURL: outputFileURL
                )
                generateThumnail(
                    outputFileURL: outputFileURL,
                    thumbnailName: thumbNailFilename
                )

            } catch {
                print("Error reading file: \(error)")
            }
            self.updateStatus("Publishing..")
            let metadatUrl = metaData.finalizeFileCreation(
                longitude: self.longitude ?? 0.0,
                lattitude: self.lattitide ?? 0.0
            )

            S3Helper.uploadFileToS3(
                bucketName: VIDEOBUCKET,
                keyValue: metadataFileName,
                fileURL: metadatUrl
            )
            self.updateStatus("Published")
            try await Task.sleep(nanoseconds: 2_000_000_000)
            self.updateStatus("")

        }
    }
}

extension VideoContentViewModel {
    /// Add the video to the app's album roll
    func add(
        video path: URL,
        to album: PHAssetCollection,
        _ photoLibrary: PHPhotoLibrary
    ) async throws {
        return try await photoLibrary.performChanges {
            guard
                let assetChangeRequest =
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(
                        atFileURL: path
                    ),
                let placeholder = assetChangeRequest.placeholderForCreatedAsset,
                let albumChangeRequest = PHAssetCollectionChangeRequest(
                    for: album
                )
            else {
                print("Cannot access to album")
                return
            }

            let enumeration = NSArray(object: placeholder)
            albumChangeRequest.addAssets(enumeration)
        }
    }

    func getAlbum(name: String, in photoLibrary: PHPhotoLibrary) throws
        -> PHAssetCollection
    {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", name)

        let collection = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: fetchOptions
        )

        if let album = collection.firstObject {
            return album
        } else {
            try createAlbum(name: name, in: photoLibrary)
            return try getAlbum(name: name, in: photoLibrary)
        }
    }

    func createAlbum(name: String, in photoLibrary: PHPhotoLibrary) throws {
        try photoLibrary.performChangesAndWait {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
                withTitle: name
            )
        }
    }
}

extension AVCaptureSession {
    var movieFileOutput: AVCaptureMovieFileOutput? {
        return outputs.compactMap { $0 as? AVCaptureMovieFileOutput }.first
    }
    var stillImageOutput: AVCapturePhotoOutput? {
        return outputs.compactMap { $0 as? AVCapturePhotoOutput }.first
    }

    func addMovieInput() throws -> Self {
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
        else {
            throw VideoError.device(reason: .unableToSetInput)
        }

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        guard self.canAddInput(videoInput) else {
            throw VideoError.device(reason: .unableToSetInput)
        }

        self.addInput(videoInput)

        return self
    }

    func addMovieFileOutput() throws -> Self {
        guard self.movieFileOutput == nil else {
            // return itself if output is already set
            return self
        }

        let fileOutput = AVCaptureMovieFileOutput()
        guard self.canAddOutput(fileOutput) else {
            throw VideoError.device(reason: .unableToSetOutput)
        }

        self.addOutput(fileOutput)

        return self
    }

    func addPhotoFileOutput() throws -> Self {
        guard self.stillImageOutput == nil else {
            // return itself if output is already set
            return self
        }
        let fileOutput = AVCapturePhotoOutput()

        guard self.canAddOutput(fileOutput) else {
            throw VideoError.device(reason: .unableToSetOutput)
        }
        self.addOutput(fileOutput)
        return self
    }
}
