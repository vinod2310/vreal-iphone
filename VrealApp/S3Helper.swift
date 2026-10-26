//
//  S3Helper.swift
//  VrealApp
//
//  Created by vinod on 31/5/2025.
//
import AWSS3
import Foundation
struct S3Helper{
    

    static func getPresignedURL(bucket: String, key: String, completion: @escaping (URL?) -> Void) {
        let urlString = "https://vreal-proto.com/api/web/presigned?bucket=\(bucket)&key=\(key)&action=put_object"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL.")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Request failed: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                print("No data received.")
                completion(nil)
                return
            }

            do {
                // Assuming the response is: { "url": "https://..." }
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                   let presignedUrlString = json["url"],
                   let presignedUrl = URL(string: presignedUrlString) {
                    completion(presignedUrl)
                   
                } else {
                    print("Invalid JSON structure.")
                    completion(nil)
                }
            } catch {
                print("Failed to parse JSON: \(error)")
                completion(nil)
            }
        }

        task.resume()
    }

    static func downloadFileToS3(bucketName: String, keyValue: String, fileURL: URL) {
        getPresignedURL(bucket: bucketName, key: keyValue) { presignedURL in
            if let url = presignedURL {
                print("Got presigned URL: \(url)")
                
                // You can now download the file using this URL
                let task = URLSession.shared.downloadTask(with: url) { location, response, error in
                    if let location = location {
                        print("File downloaded to: \(location.path)")
                        // You can move it to a permanent location
                    } else if let error = error {
                        print("Download error: \(error)")
                    }
                }
                task.resume()
            } else {
                print("Failed to get presigned URL.")
            }
        }

    }
    static func uploadFileAsync(fileURL: URL, request: URLRequest) async {
        do {
            let (_, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL)

            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    print("Upload successful")
                } else {
                    print("Upload failed. Status code: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("Upload error: \(error)")
        }
    }
    
    static func uploadFileToS3(bucketName: String, keyValue: String, fileURL: URL) {
        
        getPresignedURL(bucket: bucketName, key: keyValue) { presignedURL in
            if let url = presignedURL {
                print("Got presigned URL: \(url)")
                
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("", forHTTPHeaderField: "Content-Type")
                
                Task {
                    await uploadFileAsync(fileURL: fileURL, request: request)
                    // ✅ Continue here only after upload finishes
                }
                    
                
            } else {
                print("Failed to get presigned URL.")
            }
        }
    }




}
