//
//  Crypto.swift
//  VrealApp
//
//  Created by vinod on 31/5/2025.
//
import CryptoKit
import CoreData
public class VrealCrypto {
    private var privateKey: Curve25519.Signing.PrivateKey
    private var publicKey: Curve25519.Signing.PublicKey
    init(){
        privateKey = Curve25519.Signing.PrivateKey()
        publicKey = privateKey.publicKey
        
    }
    public var getPublicKey: Data {
        return Data(publicKey.rawRepresentation)
    }
    
     public func sign(payload: Data) -> Data? {
         
         // TODO: add parameter saftey check

         // To sign content, use the private key
         if let signature = try? privateKey.signature(for: payload) {
             // Check if the digital signature is valid or no
             return signature
         }
         return nil
     }
    
    public func verify(signature: Data) -> Bool {
        // Generate a public and a private key
       
        // Check if the digital signature is valid or no
        return publicKey.isValidSignature(signature, for: signature)
        
        
    }
}
