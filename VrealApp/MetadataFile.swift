//
//  MetadataFile.swift
//  VrealApp
//
//  Created by vinod on 31/5/2025.
//
import CoreData
import UIKit
public class Metadata{
    var sigCount: Int = 0
    
    var fileName :String
    init (fileName :String, publicKey:String) {
        do {
            
            self.fileName = fileName
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                // Create the file if it doesn't exist
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            
            defer { try? fileHandle.close() }
            let headerValue = "{\"metadata_master_record\":{\"public_key\":\"" + publicKey + "\",\"signatures\":{"
            if let data = headerValue.data(using: .utf8) {
                try fileHandle.write(contentsOf: data)
            }
            
        }catch {
            print("Error writing to file: \(error)")
        }
    }
    func byteArrayToHex(_ bytes: Data) -> String {
        if let str = String(data: bytes, encoding: .utf8) {
            return str
        }else{
            return ""
        }
//        return bytes.map { String(format: "%02x", $0) }.joined()
        
    }
    func addSignature(signature:String){
        
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                print("File does not exist!")
                return
            }

            let fileHandle = try FileHandle(forWritingTo: fileURL)
            defer { try? fileHandle.close() }

            // Move to the end of file
            try fileHandle.seekToEnd()

            // Write the string as UTF-8 data
            if let data = signature.data(using: .utf8) {
                var sigId = ""
                sigCount+=1
                if(sigCount == 1){
                    sigId = "\"" + String(sigCount) + "\" : { \"signature\":\""
                }else{
                    sigId = ",\"" + String(sigCount) + "\" : { \"signature\":\""
                    
                }
                if let sigIdData = sigId.data(using: .utf8) {
                    try fileHandle.write(contentsOf: sigIdData)
                }
                
                try fileHandle.write(contentsOf: data)
                sigId = " \" , \"sig_len\" : \"" + String(signature.count) + "\"}"
                if let sigIdData = sigId.data(using: .utf8) {
                    try fileHandle.write(contentsOf: sigIdData)
                }
            }
            
            print("Appended to file at \(fileURL)")
        } catch {
            print("Error writing to file: \(error)")
        }
        
    }
    func getOsVersion() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let osversion = withUnsafeBytes(of: &systemInfo.version) { rawBuffer -> String in
            let buffer = rawBuffer.bindMemory(to: CChar.self)
            return String(cString: buffer.baseAddress!)
        }
        // Attempt to find the first colon and trim up to it
        if let colonIndex = osversion.firstIndex(of: ":") {
            let trimmed = osversion[..<colonIndex]
            return String(trimmed)
        } else {
            // Fall back to full version string if ":" is not found
            return osversion
        }
    }
    func getDeviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        
        return identifier
    }
    func getDeviceModelName() -> String {
        let identifier = getDeviceIdentifier()

        switch identifier {
        case "iPhone13,4": return "iPhone 12 Pro Max"
        case "iPhone14,4":    return "iPhone 13 mini"
        case "iPhone14,5":    return "iPhone 13"
        case "iPhone14,2":    return "iPhone 13 Pro"
        case "iPhone14,3":    return "iPhone 13 Pro Max"
        case "iPhone14,7":    return "iPhone 14"
        case "iPhone14,8":    return "iPhone 14 Plus"
        case "iPhone15,2":    return "iPhone 14 Pro"
        case "iPhone15,3":    return "iPhone 14 Pro Max"
        case "iPhone15,4":    return "iPhone 15"
        case "iPhone15,5":    return "iPhone 15 Plus"
        case "iPhone16,1":    return "iPhone 15 Pro"
        case "iPhone16,2":    return "iPhone 15 Pro Max"
        case "iPhone17,3":    return "iPhone 16"
        case "iPhone17,4":    return "iPhone 16 Plus"
        case "iPhone17,1":    return "iPhone 16 Pro"
        case "iPhone17,2":    return "iPhone 16 Pro Max"
        case "iPhone17,5":    return "iPhone 16e"
        case "iPhone8,4":     return "iPhone SE"
        case "iPhone12,8":    return "iPhone SE (2nd generation)"
        case "iPhone14,6":    return "iPhone SE (3rd generation)"
            // Add more mappings here as needed
        default: return identifier  // Fallback to raw identifier
        }
    }
    func finalizeFileCreation(longitude: Double, lattitude:Double)-> URL{
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            print(getDeviceModelName())
            
            
            let latAndLong = String(format: "Location[fused %.6f,%.6f hAcc=2000.0 et=+3d6h5m39s836ms]", lattitude, longitude)
            let footerValue = "}},\"device_info\":{\"osversion\": \"" + getOsVersion() + "\",\"device\":\"iPhone\",\"location\":\"" + latAndLong + "\",\"model\": \"" + getDeviceModelName() + " \",\"product\": \"" + getDeviceModelName() + "\"}} "
            
            defer { try? fileHandle.close() }
            try fileHandle.seekToEnd()

            // Write the string as UTF-8 data
            if let data = footerValue.data(using: .utf8) {
                try fileHandle.write(contentsOf: data)
            }
            
            
        } catch {
            print("Error writing to file: \(error)")
        }
        return fileURL
    }
}

