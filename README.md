# vreal-iphone

iOS client for vreal, built with SwiftUI. Photos and videos are signed on the device with a Secure Enclave key (`SecureEncalveCrypto.swift`) and uploaded together with a signed metadata file. Uploads use presigned URLs from the vreal backend (`S3Helper.swift`), so the app holds no AWS credentials.

## Credentials

This repository does not include any credentials. Each value below has been replaced with a placeholder:

- `VrealApp/ScannedResultView.swift`: `<YOUR_GOOGLE_MAPS_API_KEY>` (Maps Static API)
- `VrealApp/VideoContentViewModel.swift`: `<YOUR_PHOTO_BUCKET>`, `<YOUR_VIDEO_BUCKET>`

The Apple Developer Team is left blank. Choose your own team under *Signing & Capabilities* in Xcode.

## Credits

The camera capture scaffolding (`VideoContentViewModel.swift`, `Preview.swift`, `VideoError.swift`, `AuthorizationChecker.swift`) is based on Young Bin's *VideoRecorder* sample (2023). The original headers are kept in those files.
