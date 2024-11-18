//
//  MMKV.swift
//  FileProviderExt
//
//  Created by Jan Lenczyk on 03.10.23.
//

import Foundation
import CommonCrypto

class MMKVInstance {
    static let shared: MMKVInstance = {
        let instance = MMKVInstance()
        
        return instance
    }()
    
    #if os(iOS)
    private var mmkv: MMKV?
    private var groupDir: String
    
    init() {
      let fileManager = FileManager.default
      let groupDir = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.io.filen.app1")?.path
      
      MMKV.initialize(rootDir: nil, groupDir: groupDir!, logLevel: MMKVLogLevel.debug)
    
      self.mmkv = MMKV.init(mmapID: "filen_shared", cryptKey: nil, mode: MMKVMode.multiProcess)
      self.groupDir = groupDir!
    }
    
    var instance: MMKV? {
      get {
        return self.mmkv
      }
    }
    #else
    private var groupDir: URL
    private var dbURL: URL
    
    public func getFromKey(key: String) -> Any {
        let sha = sha256(data: key.data(using: String.Encoding.utf8)!)
        let str = hexStringFromData(input: sha as NSData)
        do {
            let data = try Data(contentsOf: dbURL.appendingPathComponent(str, isDirectory: false).appendingPathExtension("json"))
            let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
            if let jsonResult = jsonResult as? Dictionary<String, AnyObject>, let val = jsonResult["value"] {
                return val
            }
        } catch {
            print(error)
            return ""
        }
        return ""
    }
    
    public func setKey(key: String, value: Any) {
        let sha = sha256(data: key.data(using: String.Encoding.utf8)!)
        let str = hexStringFromData(input: sha as NSData)
        do {
            let data = try JSONSerialization.data(withJSONObject: ["value": value], options: .prettyPrinted)
            try data.write(to: dbURL.appendingPathComponent(str, isDirectory: false).appendingPathExtension("json"))
        } catch {
            print(error)
        }
    }
    
    func sha256(data : Data) -> Data {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
    
    private  func hexStringFromData(input: NSData) -> String {
        var bytes = [UInt8](repeating: 0, count: input.length)
        input.getBytes(&bytes, length: input.length)
        
        var hexString = ""
        for byte in bytes {
            hexString += String(format:"%02x", UInt8(byte))
        }
        
        return hexString
    }
    
    let groupID = Bundle.main.infoDictionary!["GroupID"] as! String
    
    init() {
        let fileManager = FileManager.default
        let groupDir = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupID)!
        print("group dir \(groupDir.path)")
        dbURL = groupDir.appendingPathComponent("db_v1")
        // create db directory
        do {
            try fileManager.createDirectory(at: dbURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }
        
        self.groupDir = groupDir
    }
    #endif
}
