import AVFoundation
import SwiftUI

struct QRScannerView: View {
    @State private var scannedCode: String? = nil
    @State private var isPresentingResult = false

    var body: some View {
        NavigationStack {
            ZStack {
                CameraScannerView(scannedCode: $scannedCode)
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    
                    Spacer()
                    Text("Point camera at a QR code")
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 40)
                }
            }
            .navigationDestination(isPresented: $isPresentingResult) {
                if let code = scannedCode {
                    ScannedResultView(scannedText: code)
                        .onDisappear {
                            // Reset state when navigating back
                            scannedCode = nil
                            isPresentingResult = false
                        }
                }
            }
        }
        .onChange(of: scannedCode) { newValue in
            if newValue != nil {
                isPresentingResult = true
            }
        }
    }
}
