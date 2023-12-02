//
//  FileProviderEnumerator.swift
//  FileProviderExt
//
//  Created by Jan Lenczyk on 30.09.23.
//

import FileProvider
import Alamofire

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
  private let identifier: NSFileProviderItemIdentifier
  private let uploadsRangeData = "\"data\":{\"uploads\":[".data(using: .utf8)!
  private let foldersRangeData = "],\"folders\":[".data(using: .utf8)!
  private let closingRangeData = "}".data(using: .utf8)!
  private let openingRangeData = "{".data(using: .utf8)!
  private let commaData = ",".data(using: .utf8)!
  private let endData = "]}}".data(using: .utf8)!
      
  init (identifier: NSFileProviderItemIdentifier) {
    self.identifier = identifier
    
    super.init()
  }

  func invalidate() {
    // Noop
  }
  
  func processFolder (folder: FetchFolderContentsFolder, masterKeys: [String]) throws -> FileProviderItem {
    try autoreleasepool {
      var decryptedName: FolderMetadata?
      
      if let row = try FileProviderUtils.shared.openDb().run("SELECT name FROM decrypted_folder_metadata WHERE used_metadata = ?", [folder.name]).makeIterator().next() {
        if let name = row[0] as? String {
          decryptedName = FolderMetadata(name: name)
        }
      }
      
      if decryptedName == nil {
        if let decrypted = FilenCrypto.shared.decryptFolderName(metadata: folder.name, masterKeys: masterKeys) {
          decryptedName = FolderMetadata(name: decrypted)
          
          try FileProviderUtils.shared.openDb().run(
            "INSERT OR REPLACE INTO decrypted_folder_metadata (uuid, name, used_metadata) VALUES (?, ?, ?)",
            [
              folder.uuid,
              decrypted,
              folder.name
            ]
          )
        }
      }
      
      if let decryptedName = decryptedName {
        try FileProviderUtils.shared.openDb().run(
          "INSERT OR REPLACE INTO items (uuid, parent, name, type, mime, size, timestamp, lastModified, key, chunks, region, bucket, version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          [
            folder.uuid,
            folder.parent,
            decryptedName.name,
            "folder",
            "",
            0,
            folder.timestamp,
            folder.timestamp,
            "",
            0,
            "",
            "",
            0
          ]
        )
        
        return FileProviderItem(
          identifier: FileProviderUtils.shared.getIdentifierFromUUID(id: folder.uuid),
          parentIdentifier: FileProviderUtils.shared.getIdentifierFromUUID(id: self.identifier.rawValue),
          item: Item(
            uuid: folder.uuid,
            parent: folder.parent,
            name: decryptedName.name,
            type: .folder,
            mime: "",
            size: 0,
            timestamp: folder.timestamp,
            lastModified: folder.timestamp,
            key: "",
            chunks: 0,
            region: "",
            bucket: "",
            version: 0
          )
        )
      }
      
      return FileProviderItem(
        identifier: FileProviderUtils.shared.getIdentifierFromUUID(id: folder.uuid),
        parentIdentifier: FileProviderUtils.shared.getIdentifierFromUUID(id: self.identifier.rawValue),
        item: Item(
          uuid: folder.uuid,
          parent: folder.parent,
          name: "",
          type: .folder,
          mime: "",
          size: 0,
          timestamp: folder.timestamp,
          lastModified: folder.timestamp,
          key: "",
          chunks: 0,
          region: "",
          bucket: "",
          version: 0
        )
      )
    }
  }
  
  func processFile (file: FetchFolderContentsFile, masterKeys: [String]) throws -> FileProviderItem {
    try autoreleasepool {
      var decryptedMetadata: FileMetadata?
      
      if let row = try FileProviderUtils.shared.openDb().run("SELECT name, size, mime, key, lastModified FROM decrypted_file_metadata WHERE used_metadata = ?", [file.metadata]).makeIterator().next() {
        if let name = row[0] as? String, let size = row[1] as? Int64, let mime = row[2] as? String, let key = row[3] as? String, let lastModified = row[4] as? Int64 {
          decryptedMetadata = FileMetadata(
            name: name,
            size: Int(size),
            mime: mime,
            key: key,
            lastModified: Int(lastModified)
          )
        }
      }
      
      if decryptedMetadata == nil {
        if let decrypted = FilenCrypto.shared.decryptFileMetadata(metadata: file.metadata, masterKeys: masterKeys) {
          decryptedMetadata = FileMetadata(
            name: decrypted.name,
            size: decrypted.size ?? 0,
            mime: decrypted.mime ?? "",
            key: decrypted.key,
            lastModified: decrypted.lastModified ?? file.timestamp
          )
          
          try FileProviderUtils.shared.openDb().run(
            "INSERT OR REPLACE INTO decrypted_file_metadata (uuid, name, size, mime, key, lastModified, used_metadata) VALUES (?, ?, ?, ?, ?, ?, ?)",
            [
              file.uuid,
              decrypted.name,
              decrypted.size ?? 0,
              decrypted.mime ?? "",
              decrypted.key,
              decrypted.lastModified ?? file.timestamp,
              file.metadata
            ]
          )
        }
      }
      
      if let decryptedMetadata = decryptedMetadata {
        try FileProviderUtils.shared.openDb().run(
          "INSERT OR REPLACE INTO items (uuid, parent, name, type, mime, size, timestamp, lastModified, key, chunks, region, bucket, version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          [
            file.uuid,
            file.parent,
            decryptedMetadata.name,
            "file",
            decryptedMetadata.mime ?? "",
            decryptedMetadata.size ?? 0,
            file.timestamp,
            decryptedMetadata.lastModified ?? file.timestamp,
            decryptedMetadata.key,
            file.chunks,
            file.region,
            file.bucket,
            file.version
          ]
        )
        
        return FileProviderItem(
          identifier: FileProviderUtils.shared.getIdentifierFromUUID(id: file.uuid),
          parentIdentifier: FileProviderUtils.shared.getIdentifierFromUUID(id: self.identifier.rawValue),
          item: Item(
            uuid: file.uuid,
            parent: file.parent,
            name: decryptedMetadata.name,
            type: .file,
            mime: decryptedMetadata.mime ?? "",
            size: decryptedMetadata.size ?? 0,
            timestamp: FilenUtils.shared.convertUnixTimestampToSec(file.timestamp),
            lastModified: FilenUtils.shared.convertUnixTimestampToSec(decryptedMetadata.lastModified ?? file.timestamp),
            key: decryptedMetadata.key,
            chunks: file.chunks,
            region: file.region,
            bucket: file.bucket,
            version: file.version
          )
        )
      }
      
      return FileProviderItem(
        identifier: FileProviderUtils.shared.getIdentifierFromUUID(id: file.uuid),
        parentIdentifier: FileProviderUtils.shared.getIdentifierFromUUID(id: self.identifier.rawValue),
        item: Item(
          uuid: file.uuid,
          parent: file.parent,
          name: "",
          type: .file,
          mime: "",
          size: 0,
          timestamp: 0,
          lastModified: 0,
          key: "",
          chunks: file.chunks,
          region: file.region,
          bucket: file.bucket,
          version: file.version
        )
      )
    }
  }
    
    var syncAnchor: NSFileProviderSyncAnchor?
    
    func currentSyncAnchor() async -> NSFileProviderSyncAnchor? {
        return syncAnchor
    }
    
//    func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
//        print("changed")
//    }
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        if (self.identifier != .workingSet) {
            observer.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
            return
        }
        Task {
        do {
            print("udpating")
            guard let rootFolderUUID = FileProviderUtils.shared.rootFolderUUID(), let masterKeys = FileProviderUtils.shared.masterKeys(), let apiKey = MMKVInstance.shared.getFromKey(key: "apiKey") as? String, let url = URL(string: "https://gateway.filen.io/v3/dir/content") else {
            observer.finishEnumeratingWithError(NSFileProviderError(.notAuthenticated))
            
            return
          }
          
          let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Accept": "application/json",
            "Content-Type": "application/json"
          ]
          
          if FileProviderUtils.shared.needsFaceID() {
            observer.finishEnumeratingWithError(NSFileProviderError(.notAuthenticated))
            
            return
          }
            
            let parents = try FileProviderUtils.shared.openDb().run("SELECT DISTINCT parent FROM items;").map({ binding in
                binding.first as? String ?? ""
            })
            
            var didEnumerate = false
            for parent in parents {
                var kids = try FileProviderUtils.shared.getListOfItemsWithParent(uuid: parent)
                kids.removeAll(where: { $0.uuid == rootFolderUUID })
                
                let folderUUID = parent
                let tempJSONFileURL = try await AF.download(url, method: .post, parameters: ["uuid": folderUUID], encoding: JSONEncoding.default, headers: headers){ $0.timeoutInterval = 3600 }.validate().serializingDownloadedFileURL().value
                
                defer {
                    do {
                        if FileManager.default.fileExists(atPath: tempJSONFileURL.path) {
                            try FileManager.default.removeItem(atPath: tempJSONFileURL.path)
                        }
                    } catch {
                        print("[enumerateItems] error:", error)
                    }
                }
                
                let dat = try? FileProviderUtils.shared.jsonDecoder.decode(FetchFolderContents.self, from: Data(contentsOf: tempJSONFileURL))
                self.syncAnchor = NSFileProviderSyncAnchor(try Data(contentsOf: tempJSONFileURL))
                
                for file in dat?.data?.uploads ?? [] {
                    if let child = kids.first(where: { $0.uuid == file.uuid }) {
                        kids.removeAll(where: { $0.uuid == file.uuid })
                        
                        print("Found kid \(file.uuid)")
                        if (child.timestamp == file.timestamp) {
                            continue
                        }
                    }
                    let processed = try self.processFile(file: file, masterKeys: masterKeys)
                    print(processed)
                    
                    if (processed.item.name.count > 0) {
                        observer.didUpdate([processed])
                        
                        didEnumerate = true
                    }
                }
                
                for folder in dat?.data?.folders ?? [] {
                    if let child = kids.first(where: { $0.uuid == folder.uuid }) {
                        kids.removeAll(where: { $0.uuid == folder.uuid })
                        
                        print("Found kid \(folder.uuid)")
                        if (child.timestamp != folder.timestamp) {
                            continue
                        }
                    }
                    let processed = try self.processFolder(folder: folder, masterKeys: masterKeys)
                    print(processed)
                    
                    if (processed.item.name.count > 0) {
                        observer.didUpdate([processed])
                        
                        didEnumerate = true
                    }
                }
                
                print("willdelete \(kids)")
                
                for kid in kids {
                    try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [kid.uuid])
                }
                
                observer.didDeleteItems(withIdentifiers: kids.map({ FileProviderUtils.shared.getIdentifierFromUUID(id: $0.uuid) }))
            }
            
          if !didEnumerate {
            observer.didUpdate([])
            observer.didDeleteItems(withIdentifiers: [])
          }
          
          observer.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
        } catch {
          print("[enumerateItems] error:", error)
          
          observer.finishEnumeratingWithError(error)
        }
      }
    }
    
    func enumerateWorkingSet(for observer: NSFileProviderEnumerationObserver) {
        if (self.identifier != .workingSet) {
            observer.finishEnumerating(upTo: nil)
        }
        do {
            guard let rootFolderUUID = FileProviderUtils.shared.rootFolderUUID() else {
                observer.finishEnumeratingWithError(NSFileProviderError(.notAuthenticated))
                
                return
            }
            
            let parents = try FileProviderUtils.shared.openDb().run("SELECT DISTINCT parent FROM items;").map({ binding in
                binding.first as? String ?? ""
            })
            
            for parent in parents {
                var kids = try FileProviderUtils.shared.getListOfItemsWithParent(uuid: parent)
                kids.removeAll(where: { $0.uuid == rootFolderUUID })
                
                observer.didEnumerate(kids.map({ itemJSON in
                    return FileProviderItem(
                        identifier: FileProviderUtils.shared.getIdentifierFromUUID(id: itemJSON.uuid),
                        parentIdentifier: FileProviderUtils.shared.getIdentifierFromUUID(id: itemJSON.parent),
                      item: Item(
                        uuid: itemJSON.uuid,
                        parent: itemJSON.parent,
                        name: itemJSON.name,
                        type: itemJSON.type == "folder" ? .folder : .file,
                        mime: itemJSON.mime,
                        size: itemJSON.size,
                        timestamp: itemJSON.timestamp,
                        lastModified: itemJSON.lastModified,
                        key: itemJSON.key,
                        chunks: itemJSON.chunks,
                        region: itemJSON.region,
                        bucket: itemJSON.bucket,
                        version: itemJSON.version
                      ))
                }))
            }
          
          observer.finishEnumerating(upTo: nil)
        } catch {
          print("[enumerateItems] error:", error)
          
          observer.finishEnumeratingWithError(error)
        }
    }

  func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
    Task {
      do {
          guard let rootFolderUUID = FileProviderUtils.shared.rootFolderUUID(), let masterKeys = FileProviderUtils.shared.masterKeys(), let apiKey = MMKVInstance.shared.getFromKey(key: "apiKey") as? String, let url = URL(string: "https://gateway.filen.io/v3/dir/content") else {
          observer.finishEnumeratingWithError(NSFileProviderError(.notAuthenticated))
          
          return
        }
          
          if identifier == .workingSet {
              enumerateWorkingSet(for: observer)
              return
          }
        
        let headers: HTTPHeaders = [
          "Authorization": "Bearer \(apiKey)",
          "Accept": "application/json",
          "Content-Type": "application/json"
        ]
        
        if FileProviderUtils.shared.needsFaceID() {
          observer.finishEnumeratingWithError(NSFileProviderError(.notAuthenticated))
          
          return
        }
        
        if (self.identifier == NSFileProviderItemIdentifier.rootContainer || self.identifier.rawValue == rootFolderUUID || self.identifier.rawValue == NSFileProviderItemIdentifier.rootContainer.rawValue) {
          try FileProviderUtils.shared.openDb().run(
            "INSERT OR REPLACE INTO items (uuid, parent, name, type, mime, size, timestamp, lastModified, key, chunks, region, bucket, version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
              rootFolderUUID,
              rootFolderUUID,
              "Cloud Drive",
              "folder",
              "",
              0,
              0,
              0,
              "",
              0,
              "",
              "",
              0
            ]
          )
        }
        
        var didEnumerate = false
        
        let folderUUID = self.identifier == NSFileProviderItemIdentifier.rootContainer || self.identifier.rawValue == "root" || self.identifier.rawValue == NSFileProviderItemIdentifier.rootContainer.rawValue ? rootFolderUUID : self.identifier.rawValue
        let tempJSONFileURL = try await AF.download(url, method: .post, parameters: ["uuid": folderUUID], encoding: JSONEncoding.default, headers: headers){ $0.timeoutInterval = 3600 }.validate().serializingDownloadedFileURL().value
        
        defer {
          do {
            if FileManager.default.fileExists(atPath: tempJSONFileURL.path) {
              try FileManager.default.removeItem(atPath: tempJSONFileURL.path)
            }
          } catch {
            print("[enumerateItems] error:", error)
          }
        }
        
        do {
          let dat = try? FileProviderUtils.shared.jsonDecoder.decode(FetchFolderContents.self, from: Data(contentsOf: tempJSONFileURL))
            syncAnchor = NSFileProviderSyncAnchor(try Data(contentsOf: tempJSONFileURL))
          if let files = dat?.data?.uploads {
            for file in files {
              let processed = try self.processFile(file: file, masterKeys: masterKeys)
              print(processed)
              
              if (processed.item.name.count > 0) {
                observer.didEnumerate([processed])
                
                didEnumerate = true
              }
            }
          }
          if let folders = dat?.data?.folders {
            for folder in folders {
              let processed = try self.processFolder(folder: folder, masterKeys: masterKeys)
              
              if (processed.item.name.count > 0) {
                observer.didEnumerate([processed])
                
                
                didEnumerate = true
              }
            }
          }
        } catch {
          print("[enumerateItems] error:", error)
        }
        
        if !didEnumerate {
          observer.didEnumerate([])
        }
        
          observer.finishEnumerating(upTo: nil)
      } catch {
        print("[enumerateItems] error:", error)
        
        observer.finishEnumeratingWithError(error)
      }
    }
  }
}

enum FetchFolderContentJSONParseState {
  case lookingForData
  case parsingData
}

