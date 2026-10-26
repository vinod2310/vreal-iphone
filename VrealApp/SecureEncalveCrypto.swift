//
//  VrealCrypto.swift
//  VrealApp
//
//  Created by vinod on 9/6/2025.
//

//
//  Crypto.swift
//  VrealApp
//
//  Created by vinod on 31/5/2025.
//

import Foundation
import LocalAuthentication
import Security

public class SecureEnclaveCrypto {
    private let keyTag = "com.vrealapp.secureenclavekey"
    private var privateKey: SecKey?
    private var publicKey: SecKey?

    init() {
        let tag = keyTag.data(using: .utf8)!

        // Try loading existing key
        let getquery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecReturnRef as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(getquery as CFDictionary, &item)

        if status == errSecSuccess {
            self.privateKey = (item as! SecKey)
            self.publicKey = SecKeyCopyPublicKey(self.privateKey!)
            return
        }

        // Not found: create a new Secure Enclave key
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryAny],
            nil
        )!

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessControl as String: access,
            ],
        ]

        var error: Unmanaged<CFError>?
        guard
            let privKey = SecKeyCreateRandomKey(
                attributes as CFDictionary,
                &error
            )
        else {
            print(
                "Failed to create key: \(error!.takeRetainedValue() as Error)"
            )
            return
        }

        self.privateKey = privKey
        self.publicKey = SecKeyCopyPublicKey(privKey)
    }

    public func getPublicKey() -> Data? {
        guard let pubKey = publicKey else { return nil }
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(pubKey, &error) else {
            print(
                "Failed to get public key data: \(error!.takeRetainedValue() as Error)"
            )
            return nil
        }
        return data as Data
    }
    public func getPrivateKey() -> SecKey? {
        let tag = keyTag.data(using: .utf8)!
        let context = LAContext()
        context.localizedReason = "Authenticate to use private key"
        context.interactionNotAllowed = false // show Face ID / Touch ID UI

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecReturnRef as String: true,
            kSecUseAuthenticationContext as String: context
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        var secKey: SecKey!

        if status == errSecSuccess, let key = item {
            secKey = key as! SecKey
            // Use secKey
        }else{
            if let errorMessage = SecCopyErrorMessageString(status, nil) {
                print("Security error: \(errorMessage)")
            }
            return nil
        }
        return secKey
        
    }

    public func sign(payload: Data, secKey: SecKey) -> String {
        
        
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            secKey,
            .ecdsaSignatureMessageX962SHA256,
            payload as CFData,
            &error
        ) else {
            print("Signing failed: \(error!.takeRetainedValue() as Error)")
            return ""
        }

        let signatureData = signature as Data
        printSignature(signature: signatureData)
        return signatureData.base64EncodedString()
    }



    public func verify(signature: Data, payload: Data) -> Bool {
        guard let publicKey = self.publicKey else { return false }

        var error: Unmanaged<CFError>?
        let result = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            payload as CFData,
            signature as CFData,
            &error
        )

        if let e = error {
            print("Verification error: \(e.takeRetainedValue() as Error)")
        }

        return result
    }
    public func printPublicKey() {
        if let publicKeyData = getPublicKey() {
            let base64Key = publicKeyData.base64EncodedString()
            print("Public Key (Base64): \(base64Key)")
        } else {
            print("Failed to retrieve public key.")
        }
    }
    public func getPublicKeybase64() -> String {
        if let publicKeyData = getPublicKey() {
            return publicKeyData.base64EncodedString()
        }
        return ""

    }

    public func printSignature(signature: Data) {

        let base64Key = signature.base64EncodedString()
        print("Signature(Base64): \(base64Key)")

    }
    public func getSignatureBase64(signature: Data)->String {

        return signature.base64EncodedString()

    }
    public func deleteSecureEnclaveKey() {
        let tag = keyTag.data(using: .utf8)!

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
        ]

        let status = SecItemDelete(deleteQuery as CFDictionary)
        if status == errSecSuccess {
            print("✅ Secure Enclave key deleted successfully.")
        } else if let message = SecCopyErrorMessageString(status, nil) {
            print("❌ Failed to delete key: \(message)")
        } else {
            print("❌ Failed to delete key with status code: \(status)")
        }
    }
}
