import SwiftUI

struct HomePageView: View {
    @StateObject var videoContentViewModel = VideoContentViewModel()
    @State private var isShowingScanner = false
    
    @State private var isShowingMediaCapture = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // 1. Black-to-transparent gradient background
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black,
                                                    Color.black.opacity(0.8),
                                                    Color.init(red: 44 / 255, green: 44 / 255, blue: 44 / 255)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        Spacer()
                            .frame(height: geometry.size.height * 0.2) // 20% from top
                        
                        // 2. Logo
                        Image(.vrealLogoBlackOnWhite)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                        
                        // 3. Text
                        Text("REALITY.\nVERIFIED")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .font(.title.bold())
                            .padding(.top, 10)
                        
                        Spacer()
                        
                        // 4. Buttons at ~70% from top
                        VStack(spacing: 16) {
                            Button {
                                isShowingScanner = true
                            } label: {
                                Image(.scanQr)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 60)
                            }.navigationDestination(isPresented: $isShowingScanner) {
                                QRScannerView()
                            }
                            
                            Button {
                                isShowingMediaCapture = true
                                
                                
                            } label: {
                                Image(.captureMedia)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 60)
                            }
                            .navigationDestination(isPresented: $isShowingMediaCapture) {
                                MediaCaptureView()
                            }
                        }
                        Spacer()
                            .frame(height: geometry.size.height * 0.1) // Push away from bottom
                    }
                    .padding(.horizontal, 30)
                }
                .onAppear {
                    videoContentViewModel.checkLocationServicesEnabled()
                }
            }
        }
    }
}
