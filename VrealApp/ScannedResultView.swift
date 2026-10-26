import SwiftUI
import AVKit

struct ScannedResultView: View {
    let scannedText: String
    @State private var showSignature = false
    @State private var signatures: [String] = []
    @State private var locationImage: UIImage = UIImage()
    @State private var captureDevice: String = ""
    @State private var captureDate: String = ""

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Video Player (half screen height)
                    VideoPlayer(player: AVPlayer(url: URL(string: scannedText)!))
                        .frame(height: geometry.size.height * 0.5)
                        .cornerRadius(10)
                        .onAppear {
                            AVPlayer(url: URL(string: scannedText)!).play()
                        }

                    // 2. Row with two icons
                    HStack {
                        Image(.authenticatedBadgeSilver)
                            .font(.title)
                            .foregroundColor(.green)
                            
                        Spacer()
                        Image(.share)
                            .font(.title)
                            .foregroundColor(.red)
                            
                        
                    }.padding(8)

                    // 3. Text block with two sentences
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This video was signed at the source of capture by a V-Real.")
                        Text("Device used capture: \(captureDevice), Time of capture:\(captureDate)")
                    }
                    .font(.body)
                    .padding(.horizontal)

                    // 4. Collapsible list: Signature
                    DisclosureGroup("Signature", isExpanded: $showSignature) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(signatures, id: \.self) { text in // show received results
                                Text(text)
                            }
                        }
                        .padding(.top, 5)
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)

                    // 5. Placeholder for map
                    Image(uiImage: locationImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .shadow(radius: 4)
//                    Rectangle()
//                        .fill(Color.gray.opacity(0.3))
//                        .frame(height: 200)
//                        .overlay(locationImage
//                                    .foregroundColor(.black)
//                                    .font(.headline))
//                        .cornerRadius(10)
//                        .padding(.horizontal)

                    Spacer()
                }
                .padding(.top)
            }
        }
        .navigationTitle("Scan Result")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchMetadata()
        }
    }
    func extractLocation(from locationString: String) -> String? {
        let token = "Location[fused "
        let delimiter: Character = "h"

        guard let tokenRange = locationString.range(of: token) else {
            print("Token not found")
            return nil
        }

        let startIndex = tokenRange.upperBound
        print("Start index: \(locationString.distance(from: locationString.startIndex, to: startIndex))")

        let remaining = locationString[startIndex...]
        print("Remaining: \(remaining)")

        guard let delimiterIndex = remaining.firstIndex(of: delimiter) else {
            return nil
        }

        let locationSubstring = remaining[..<delimiterIndex]
        print("Remaining: \(locationSubstring)")
        return locationSubstring.trimmingCharacters(in: .whitespaces)
    }



    func getStaticMapImage(for location: String, completion: @escaping (UIImage?) -> Void) {
        let apiKey = "<YOUR_GOOGLE_MAPS_API_KEY>"
        let baseUrl = "https://maps.googleapis.com/maps/api/staticmap"
        
        // Build URL string
        let urlString = "\(baseUrl)?center=\(location)&scale=2&zoom=14&size=1000x400&markers=color:red%7C\(location)&key=\(apiKey)"
        
        // Encode the full URL (important for spaces/commas etc.)
        guard let encodedUrlString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedUrlString) else {
            print("Invalid map URL")
            completion(nil)
            return
        }

        // Download the image
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil,
                  let data = data,
                  let image = UIImage(data: data) else {
                print("Error downloading map image: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return 
            }

            completion(image)
        }

        task.resume()
    }
    func getTimeStringFromFileUrl(_ filename: String) -> String? {
            // Step 1: Extract date-time string (first part before dot)
            let nameWithoutExtension = filename.components(separatedBy: ".").first ?? ""
            
            // Step 2: Create formatter to parse the filename format
            let inputFormatter = DateFormatter()
            inputFormatter.dateFormat = "ddMMyyyy_HHmmss"
            inputFormatter.locale = Locale(identifier: "en_US_POSIX") // use fixed locale for parsing

            // Step 3: Convert to Date
            guard let date = inputFormatter.date(from: nameWithoutExtension) else {
                return nil
            }

            // Step 4: Format to localized string
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .medium
            outputFormatter.timeStyle = .medium
            outputFormatter.locale = Locale.current
            outputFormatter.timeZone = TimeZone.current

            return outputFormatter.string(from: date)
        

    }

    func fetchMetadata() async {
        let metadatUrl = scannedText.replacingOccurrences(of: ".mp4", with: ".metadata")
        guard let url = URL(string: metadatUrl) else { return } // Assuming JSON lives next to video
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let dict = try JSONSerialization.jsonObject(with: data, options : []) as? [String: Any]
            if let deviceInfo = dict!["device_info"] as? [String: Any]{
                let location = (deviceInfo["location"] as? String)!
                let model = deviceInfo["model"] as? String
                let product = deviceInfo["product"] as? String

                if model == nil && product == nil {
                    self.captureDevice = "device and model unknown"
                } else {
                    self.captureDevice = [model, product].compactMap { $0 }.joined(separator: " ")
                }

                self.captureDate = getTimeStringFromFileUrl(
                    metadatUrl.components(separatedBy: "/").last ?? "") ?? "data unknown"
                let longlat = extractLocation(from: location) ?? "0.0,0.0"
                getStaticMapImage(for: longlat) { image in
                    if let mapImage = image {
                        DispatchQueue.main.async {
                            locationImage = mapImage
                        }
                    } else {
                        print("Failed to download map image.")
                    }
                }
            }
                
            if let metadataMasterRecord = dict!["metadata_master_record"] as? [String: Any],
               let signatures = metadataMasterRecord["signatures"] as? [String: Any]{
                
                for (_, value) in signatures {
                    // Skip if value is not a dictionary (like "sig_len": "71" at the end)
                    guard let sigEntry = value as? [String: String],
                          let signature = sigEntry["signature"] else {
                        continue
                    }
                    
                    self.signatures.append(signature)
                    
                }
            }
        } catch {
            signatures.append("Failed to decode metadata.")
            signatures.append("Error fetching metadata: \(error.localizedDescription)")
        }
    }
}
