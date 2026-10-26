import SwiftUI

struct MediaCaptureView: View {
    @StateObject var videoContentViewModel = VideoContentViewModel()
    @State var isRecording = false
    @State private var isShowingScanner = false
    @State private var scannedCode: String?
    @State private var showAlert = false
    @State private var elapsedTime = 0
    @State private var timer: Timer? = nil
    enum MEDIA_SELECTION_MODE {
        case photo
        case video
    }
    @State var selectionMode: MEDIA_SELECTION_MODE = .video

    var body: some View {

        GeometryReader { geometry in
            VStack(spacing: 0) {

                // Preview area (80% height)
                ZStack(alignment: .bottom) {
                    videoContentViewModel.preview?
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height * 0.98
                        )
                        .clipped()

                    // Overlay controls on bottom of preview
                    HStack {
                        Image(.logoForCapturePage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)

                        Spacer()

                        Button {
                            if selectionMode == .photo {
                                videoContentViewModel.clickPhoto()
                            } else {
                                if isRecording {
                                    stopRecording()
                                } else {
                                    startRecording()
                                }
                                isRecording.toggle()
                            }
                        } label: {
                            Image(
                                isRecording
                                    ? .mediaRecording : .mediaNotRecording
                            )
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                        }
                        Spacer()

                        Image(.switchCamera)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    if isRecording {
                        Text(timeString(from: elapsedTime))
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundColor(.white)
                    }
                }
                // Timer Label

                // Black bottom control area (20% height)
                VStack(spacing: 12) {
                    // Toggle buttons
                    HStack(spacing: 0) {
                        Button {
                            videoContentViewModel.statusMessage = "Photo mode selected"
                            selectionMode = .photo
                        } label: {
                            Image(
                                (selectionMode == .photo)
                                ? .photoCaptureSelected : .photoCaptureUnselected
                            )
                                .resizable()
                                .scaledToFit()
                                .frame(height: 30)
                        }

                        Button {
                            selectionMode = .video
                            videoContentViewModel.statusMessage = "Video mode selected"

                        } label: {
                            Image(
                                (selectionMode == .video)
                                ? .videoCaptureSelected : .videoCaptureUnselected
                                )
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 30)
                        
                        }
                    }.background(Color.white)
                        .cornerRadius(20)

                    // Status message
                    Text(videoContentViewModel.statusMessage)
                        .foregroundColor(.white)
                        .font(.footnote)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .frame(height: geometry.size.height * 0.2)
                .background(Color.black)
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                videoContentViewModel.checkLocationServicesEnabled()
            }
        }

    }
    func startRecording() {
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
        }
        videoContentViewModel.startRecording()
    }

    func stopRecording() {
        timer?.invalidate()
        timer = nil
        videoContentViewModel.stopRecording()
    }
    func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct VideoContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MediaCaptureView()
        }
    }
}
