//
//  FileProviderExtension.swift
//  FileProviderExt
//
//  Created by Jan Lenczyk on 30.09.23.
//

import Foundation
import FileProvider
import os
import AVFoundation

class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension {
    func invalidate() {
        print("bye")
    }
    
    func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?, request: NSFileProviderRequest, completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
        print("fecth")
        let identifier = itemIdentifier
        
        guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: identifier.rawValue) else {
           completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
            return Progress()
        }
        
        FileProviderUtils.currentDownloads[itemJSON.uuid] = true
        
        defer {
          FileProviderUtils.currentDownloads.removeValue(forKey: itemJSON.uuid)
        }
        
        do {
            print("huh?")
            let prog = Progress(totalUnitCount: Int64(itemJSON.chunks))
            Task {
                do{
                    print("huh?1")
                    let tempFileURL = try FileProviderUtils.shared.getTempPath().appendingPathComponent(UUID().uuidString.lowercased() + "." + identifier.rawValue, isDirectory: false)
                    
                    let (didDown, svdURL) = try await FileProviderUtils.shared.downloadFile(uuid: itemJSON.uuid, url: tempFileURL.path, maxChunks: itemJSON.chunks, progress: prog)
                    print(didDown)
                    print(svdURL)
                    let finURL = URL(filePath: svdURL)
                    print(itemJSON.parent)
                    
                    guard let rootFolderUUID = FileProviderUtils.shared.rootFolderUUID() else {
                        completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
                        throw NSFileProviderError(.noSuchItem)
                    }
                    let parent = rootFolderUUID == itemJSON.parent ? NSFileProviderItemIdentifier.rootContainer : NSFileProviderItemIdentifier(itemJSON.parent)
                    
                    completionHandler(finURL, FileProviderItem(
                        identifier: identifier,
                        parentIdentifier: parent,
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
                        )), nil)
                    prog.completedUnitCount = Int64(itemJSON.chunks)
                }catch{
                    print(error
                    )
                }
            }
            print("done")
            return Progress()
        } catch {
          print("[startProvidingItem] error:", error)
          
            completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
        }
        
        return Progress()
    }
    
    func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?, options: NSFileProviderCreateItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        print("creat")
        return Progress()
    }
    
    func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields, contents newContents: URL?, options: NSFileProviderModifyItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        print("mod")
        return Progress()
    }
    
    func deleteItem(identifier: NSFileProviderItemIdentifier, baseVersion version: NSFileProviderItemVersion, options: NSFileProviderDeleteItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (Error?) -> Void) -> Progress {
        print("del")
        return Progress()
    }
    
  private let thumbnailSemaphore = DispatchSemaphore(value: 1)
    let domain: NSFileProviderDomain

  required init(domain: NSFileProviderDomain) {
    FileProviderUtils.shared.cleanupTempDir()
      self.domain = domain
      FileProviderUtils.shared.managerYet = NSFileProviderManager(for: domain)
      
      NSFileProviderManager.add(domain) { error in
          if let error = error {
              NSLog("Could not add file provider for domain: \(error)")
              return
          }

          guard let newManager = NSFileProviderManager(for: domain) else {
              NSLog("Could not create file provider manager.")
              return
          }

          NSLog("File provider URL: \(newManager.description)")
      }
    
    super.init()
  }
  
//  override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
//    let pathComponents = url.pathComponents
//    let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
//    
//    return itemIdentifier
//  }
//      
//  override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
//    guard let item = try? item(for: identifier) else {
//        return nil
//    }
//
//    return NSFileProviderManager.default.documentStorageURL.appendingPathComponent(identifier.rawValue, isDirectory: true).appendingPathComponent(item.filename, isDirectory: false)
//  }

    func item(for identifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress {
        print("meow \(identifier)")
    guard let rootFolderUUID = FileProviderUtils.shared.rootFolderUUID() else {
        completionHandler(nil, NSFileProviderError(.noSuchItem))
        return Progress()
    }
    
    if (identifier.rawValue == "root" || identifier == NSFileProviderItemIdentifier.rootContainer || identifier.rawValue == rootFolderUUID || identifier.rawValue == NSFileProviderItemIdentifier.rootContainer.rawValue) {
//      guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: rootFolderUUID) else {
//          completionHandler(nil, NSFileProviderError(.noSuchItem))
//          print("wtf2")
//          return Progress()
//      }
      
    completionHandler(FileProviderItem(
        identifier: NSFileProviderItemIdentifier.rootContainer,
        parentIdentifier: NSFileProviderItemIdentifier.rootContainer,
        item: Item(
            uuid: rootFolderUUID,
          parent: rootFolderUUID,
          name: "Cloud Drive",
          type: .folder,
          mime: "",
          size: 0,
          timestamp: 0,
          lastModified: 0,
          key: "",
          chunks: 0,
          region: "",
          bucket: "",
          version: 0
        )
    ), nil)
        return Progress()
    }
        print("NOT ROOT")
    
    guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: identifier.rawValue) else {
        print("wtf3")
        completionHandler(nil, NSFileProviderError(.noSuchItem))
        return Progress()
    }
        print("\(itemJSON)")
    
        completionHandler(FileProviderItem(
      identifier: identifier,
      parentIdentifier: NSFileProviderItemIdentifier(rawValue: itemJSON.parent),
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
      )), nil
    )
        return Progress()
  }

//  override func providePlaceholder(at url: URL) async throws {
//    guard let identifier = persistentIdentifierForItem(at: url) else {
//      throw NSFileProviderError(.noSuchItem)
//    }
//
//    let placeholderDirectoryUrl = url.deletingLastPathComponent()
//    let fileProviderItem = try item(for: identifier)
//    let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
//    
//    if !FileManager.default.fileExists(atPath: placeholderDirectoryUrl.path) {
//      try FileManager.default.createDirectory(at: placeholderDirectoryUrl, withIntermediateDirectories: true, attributes: nil)
//    }
//    
//    try NSFileProviderManager.writePlaceholder(at: placeholderURL, withMetadata: fileProviderItem)
//  }

//    func startProvidingItem(for id: NSFileProviderItemIdentifier) async throws {
//    let identifier = id
//    
//    guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: identifier.rawValue) else {
//      throw NSFileProviderError(.noSuchItem)
//    }
//    
//    FileProviderUtils.currentDownloads[itemJSON.uuid] = true
//    
//    defer {
//      FileProviderUtils.currentDownloads.removeValue(forKey: itemJSON.uuid)
//      
//      FileProviderUtils.shared.signalEnumeratorForIdentifier(for: identifier)
//    }
//    
//    do {
//        _ = try await FileProviderUtils.shared.downloadFile(uuid: itemJSON.uuid, url: FileProviderUtils.shared.tempPath?.appendingPathComponent(itemJSON.uuid, isDirectory:false), maxChunks: itemJSON.chunks)
//    } catch {
//      print("[startProvidingItem] error:", error)
//      
//      throw error
//    }
//  }

//  override func itemChanged(at url: URL) {
//    let pathComponents = url.pathComponents
//    let identifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
//    
//    guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: identifier.rawValue), FileManager.default.fileExists(atPath: url.path) else {
//      return
//    }
//    
//    guard let parentJSON = FileProviderUtils.shared.getItemFromUUID(uuid: itemJSON.parent) else {
//      return
//    }
//    
//    Task {
//      FileProviderUtils.currentUploads[itemJSON.uuid] = true
//      
//      var newUUID = ""
//      
//      defer {
//        FileProviderUtils.currentUploads.removeValue(forKey: itemJSON.uuid)
//        
//        FileProviderUtils.shared.signalEnumeratorForIdentifier(for: NSFileProviderItemIdentifier(rawValue: parentJSON.uuid))
//      }
//      
//      do {
//        let result = try await FileProviderUtils.shared.uploadFile(url: url.path, parent: parentJSON.uuid)
//        
//        newUUID = result.uuid
//        
//        try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [itemJSON.uuid])
//        try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [newUUID])
//        try FileProviderUtils.shared.openDb().run(
//          "INSERT OR IGNORE INTO items (uuid, parent, name, type, mime, size, timestamp, lastModified, key, chunks, region, bucket, version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
//          [
//            newUUID,
//            parentJSON.uuid,
//            result.name,
//            result.type,
//            result.mime,
//            result.size,
//            result.timestamp,
//            result.lastModified,
//            result.key,
//            result.chunks,
//            result.region,
//            result.bucket,
//            result.version
//          ]
//        )
//        
//        self.stopProvidingItem(at: url)
//      } catch {
//        print("[itemChanged] error: \(error)")
//      }
//    }
//  }

//  override func stopProvidingItem(at url: URL) {
//    let pathComponents = url.pathComponents
//    let uuid = pathComponents[pathComponents.count - 2]
//    
//    do {
//      try FileManager().removeItem(at: url)
//      
//      try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [uuid])
//    } catch let error {
//        print("[stopProvidingItem] error: \(error)")
//    }
//  }

//   func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem {
//    do {
//      guard let parentJSON = FileProviderUtils.shared.getItemFromUUID(uuid: parentItemIdentifier.rawValue) else {
//        throw NSFileProviderError(.noSuchItem)
//      }
//      
//      let uuid = try await FileProviderUtils.shared.createFolder(name: directoryName, parent: parentJSON.uuid)
//      
//      try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [uuid])
//      try FileProviderUtils.shared.openDb().run(
//        "INSERT OR IGNORE INTO items (uuid, parent, name, type, mime, size, timestamp, lastModified, key, chunks, region, bucket, version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
//        [
//          uuid,
//          parentJSON.uuid,
//          directoryName,
//          "folder",
//          "",
//          0,
//          0,
//          0,
//          "",
//          0,
//          "",
//          "",
//          0
//        ]
//      )
//      
//      return FileProviderItem(
//        identifier: NSFileProviderItemIdentifier(rawValue: uuid),
//        parentIdentifier: parentItemIdentifier,
//        item: Item(
//          uuid: uuid,
//          parent: parentJSON.uuid,
//          name: directoryName,
//          type: .folder,
//          mime: "",
//          size: 0,
//          timestamp: 0,
//          lastModified: 0,
//          key: "",
//          chunks: 0,
//          region: "",
//          bucket: "",
//          version: 0
//        )
//      )
//    } catch {
//      print("[createDirectory] error:", error)
//      
//      throw error
//    }
//  }
//
//    func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String) async throws -> NSFileProviderItem {
//    guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: itemIdentifier.rawValue) else {
//      throw NSFileProviderError(.noSuchItem)
//    }
//    
//    if (itemJSON.type == "folder") {
//      try await FileProviderUtils.shared.renameFolder(uuid: itemJSON.uuid, toName: itemName)
//      
//      return FileProviderItem(
//        identifier: NSFileProviderItemIdentifier(rawValue: itemJSON.uuid),
//        parentIdentifier: NSFileProviderItemIdentifier(rawValue: itemJSON.parent),
//        item: Item(
//          uuid: itemJSON.uuid,
//          parent: itemJSON.parent,
//          name: itemName,
//          type: .folder,
//          mime: "",
//          size: 0,
//          timestamp: 0,
//          lastModified: 0,
//          key: "",
//          chunks: 0,
//          region: "",
//          bucket: "",
//          version: 0
//        )
//      )
//    } else {
//      try await FileProviderUtils.shared.renameFile(
//        uuid: itemJSON.uuid,
//        metadata: FileMetadata(
//          name: itemName,
//          size: itemJSON.size,
//          mime: itemJSON.mime,
//          key: itemJSON.key,
//          lastModified: itemJSON.lastModified
//        )
//      )
//      
//      return FileProviderItem(
//        identifier: NSFileProviderItemIdentifier(rawValue: itemJSON.uuid),
//        parentIdentifier: NSFileProviderItemIdentifier(rawValue: itemJSON.parent),
//        item: Item(
//          uuid: itemJSON.uuid,
//          parent: itemJSON.parent,
//          name: itemName,
//          type: .file,
//          mime: itemJSON.mime,
//          size: itemJSON.size,
//          timestamp: itemJSON.timestamp,
//          lastModified: itemJSON.lastModified,
//          key: itemJSON.key,
//          chunks: itemJSON.chunks,
//          region: itemJSON.region,
//          bucket: itemJSON.bucket,
//          version: itemJSON.version
//        )
//      )
//    }
//  }
//
//  override func trashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem {
//    guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: itemIdentifier.rawValue) else {
//      throw NSFileProviderError(.noSuchItem)
//    }
//    
//    try await FileProviderUtils.shared.trashItem(uuid: itemJSON.uuid, type: itemJSON.type == "folder" ? .folder : .file)
//    
//    try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [itemJSON.uuid])
//    
//    return FileProviderItem(
//      identifier: itemIdentifier,
//      parentIdentifier: NSFileProviderItemIdentifier(rawValue: itemJSON.parent),
//      item: Item(
//        uuid: itemJSON.uuid,
//        parent: itemJSON.parent,
//        name: itemJSON.name,
//        type: itemJSON.type == "folder" ? .folder : .file,
//        mime: itemJSON.mime,
//        size: itemJSON.size,
//        timestamp: itemJSON.timestamp,
//        lastModified: itemJSON.lastModified,
//        key: itemJSON.key,
//        chunks: itemJSON.chunks,
//        region: itemJSON.region,
//        bucket: itemJSON.bucket,
//        version: itemJSON.version
//      )
//    )
//  }
//
//  override func untrashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier?) async throws -> NSFileProviderItem {
//    guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: itemIdentifier.rawValue) else {
//      throw NSFileProviderError(.noSuchItem)
//    }
//    
//    try await FileProviderUtils.shared.restoreItem(uuid: itemJSON.uuid, type: itemJSON.type == "folder" ? .folder : .file)
//    
//    try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [itemJSON.uuid])
//    try FileProviderUtils.shared.openDb().run(
//      "INSERT OR IGNORE INTO items (uuid, parent, name, type, mime, size, timestamp, lastModified, key, chunks, region, bucket, version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
//      [
//        itemJSON.uuid,
//        itemJSON.parent,
//        itemJSON.name,
//        itemJSON.type,
//        itemJSON.mime,
//        itemJSON.size,
//        itemJSON.timestamp,
//        itemJSON.lastModified,
//        itemJSON.key,
//        itemJSON.chunks,
//        itemJSON.region,
//        itemJSON.bucket,
//        itemJSON.version
//      ]
//    )
//    
//    return FileProviderItem(
//      identifier: itemIdentifier,
//      parentIdentifier: NSFileProviderItemIdentifier(rawValue: itemJSON.parent),
//      item: Item(
//        uuid: itemJSON.uuid,
//        parent: itemJSON.parent,
//        name: itemJSON.name,
//        type: itemJSON.type == "folder" ? .folder : .file,
//        mime: itemJSON.mime,
//        size: itemJSON.size,
//        timestamp: itemJSON.timestamp,
//        lastModified: itemJSON.lastModified,
//        key: itemJSON.key,
//        chunks: itemJSON.chunks,
//        region: itemJSON.region,
//        bucket: itemJSON.bucket,
//        version: itemJSON.version
//      )
//    )
//  }

   func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws {
    guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: itemIdentifier.rawValue) else {
      throw NSFileProviderError(.noSuchItem)
    }
    
    try await FileProviderUtils.shared.deleteItem(uuid: itemJSON.uuid, type: itemJSON.type == "folder" ? .folder : .file)
    
    try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [itemJSON.uuid])
  }

   func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?) async throws -> NSFileProviderItem {
    guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: itemIdentifier.rawValue), let parentJSON = FileProviderUtils.shared.getItemFromUUID(uuid: parentItemIdentifier.rawValue) else {
      throw NSFileProviderError(.noSuchItem)
    }
    
    try await FileProviderUtils.shared.moveItem(parent: parentJSON.uuid, item: itemJSON)
    
    try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [itemJSON.uuid])
    try FileProviderUtils.shared.openDb().run(
      "INSERT OR IGNORE INTO items (uuid, parent, name, type, mime, size, timestamp, lastModified, key, chunks, region, bucket, version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      [
        itemJSON.uuid,
        parentJSON.uuid,
        itemJSON.name,
        itemJSON.type,
        itemJSON.mime,
        itemJSON.size,
        itemJSON.timestamp,
        itemJSON.lastModified,
        itemJSON.key,
        itemJSON.chunks,
        itemJSON.region,
        itemJSON.bucket,
        itemJSON.version
      ]
    )
    
    return FileProviderItem(
      identifier: itemIdentifier,
      parentIdentifier: parentItemIdentifier,
      item: Item(
        uuid: itemJSON.uuid,
        parent: parentJSON.uuid,
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
      )
    )
  }

   func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem {
    guard let parentJSON = FileProviderUtils.shared.getItemFromUUID(uuid: parentItemIdentifier.rawValue) else {
      throw NSFileProviderError(.noSuchItem)
    }
    
    do {
      let result = try await FileProviderUtils.shared.uploadFile(url: fileURL.path, parent: parentJSON.uuid)
      
      try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [result.uuid])
      try FileProviderUtils.shared.openDb().run(
        "INSERT OR IGNORE INTO items (uuid, parent, name, type, mime, size, timestamp, lastModified, key, chunks, region, bucket, version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
          result.uuid,
          parentJSON.uuid,
          result.name,
          result.type,
          result.mime,
          result.size,
          result.timestamp,
          result.lastModified,
          result.key,
          result.chunks,
          result.region,
          result.bucket,
          result.version
        ]
      )
      
      return FileProviderItem(
        identifier: NSFileProviderItemIdentifier(rawValue: result.uuid),
        parentIdentifier: parentItemIdentifier,
        item: Item(
          uuid: result.uuid,
          parent: parentJSON.uuid,
          name: result.name,
          type: result.type == "folder" ? .folder : .file,
          mime: result.mime,
          size: result.size,
          timestamp: result.timestamp,
          lastModified: result.lastModified,
          key: result.key,
          chunks: result.chunks,
          region: result.region,
          bucket: result.bucket,
          version: result.version
        )
      )
    } catch {
      print("[importDocument] error:", error)
      
      throw error
    }
  }

   func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem {
    guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: itemIdentifier.rawValue) else {
      throw NSFileProviderError(.noSuchItem)
    }
    
    let item = FileProviderItem(
      identifier: itemIdentifier,
      parentIdentifier: NSFileProviderItemIdentifier(rawValue: itemJSON.parent),
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
      )
    )
    
//    item.favoriteRank = favoriteRank
    
    return item
  }

   func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem {
    guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: itemIdentifier.rawValue) else {
      throw NSFileProviderError(.noSuchItem)
    }
    
    let item = FileProviderItem(
      identifier: itemIdentifier,
      parentIdentifier: NSFileProviderItemIdentifier(rawValue: itemJSON.parent),
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
      )
    )
    
    item.tagData = tagData
    
    return item
  }

//   func fetchThumbnails(for itemIdentifiers: [NSFileProviderItemIdentifier], requestedSize size: CGSize, perThumbnailCompletionHandler: @escaping (NSFileProviderItemIdentifier, Data?, Error?) -> Void, completionHandler: @escaping (Error?) -> Void) -> Progress {
//    autoreleasepool {
//      let progress = Progress(totalUnitCount: Int64(itemIdentifiers.count))
//      
//      return progress
//      
//      let supportedImageFormats = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp"]
//      let supportedVideoFormats = ["mp4", "mov"]
//      let tempURL = NSFileProviderManager.default.documentStorageURL.appendingPathComponent("temp", isDirectory: true)
//      
//      do {
//        if !FileManager.default.fileExists(atPath: tempURL.path) {
//          try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
//        }
//      } catch {
//        print("[fetchThumbnails] error: \(error)")
//        
//        progress.cancel()
//        
//        return progress
//      }
//      
//      for identifier in itemIdentifiers {
//        guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: identifier.rawValue), var ext = FileProviderUtils.shared.fileExtension(from: itemJSON.name) else {
//          perThumbnailCompletionHandler(identifier, nil, nil)
//          
//          continue
//        }
//        
//        ext = ext.lowercased()
//        
//        if (!supportedImageFormats.contains(ext) && !supportedVideoFormats.contains(ext)) {
//          perThumbnailCompletionHandler(identifier, nil, nil)
//          
//          continue
//        }
//        
//        let pathForItem = self.urlForItem(withPersistentIdentifier: identifier)
//        
//        do {
//          if let pathForItem = pathForItem {
//            if FileManager.default.fileExists(atPath: pathForItem.path) {
//              progress.completedUnitCount += 1
//              
//              perThumbnailCompletionHandler(identifier, try Data(contentsOf: pathForItem, options: [.alwaysMapped]), nil)
//              
//              if (progress.isFinished) {
//                completionHandler(nil)
//              }
//              
//              continue
//            }
//          }
//        } catch {
//          print("[fetchThumbnails] error: \(error)")
//        }
//        
//        let isImage = supportedImageFormats.contains(ext)
//        let tempFileURL = tempURL.appendingPathComponent("thumbnail_" + UUID().uuidString.lowercased() + "." + itemJSON.uuid + "." + ext, isDirectory: false)
//        
//        Task {
//          self.thumbnailSemaphore.wait()
//          
//          defer {
//            self.thumbnailSemaphore.signal()
//            
//            do {
//              if FileManager.default.fileExists(atPath: tempFileURL.path) {
//                try FileManager.default.removeItem(atPath: tempFileURL.path)
//              }
//            } catch {
//              print(error)
//            }
//          }
//          
//          var error: Error?
//          var data: Data?
//          
//          do {
//            guard progress.isCancelled != true else { return }
//            
//            let downloadResult = try await FileProviderUtils.shared.downloadFile(uuid: itemJSON.uuid, url: tempFileURL.path, maxChunks: isImage ? itemJSON.chunks : 16)
//            
//            if (downloadResult.didDownload) {
//              if (isImage) {
//                if let pathForItem = pathForItem {
//                  if !FileManager.default.fileExists(atPath: pathForItem.path) && FileManager.default.fileExists(atPath: tempFileURL.path) {
//                    do {
//                      try FileManager.default.copyItem(at: tempFileURL, to: pathForItem)
//                    } catch {
//                      print("[fetchThumbnails] error: \(error)")
//                    }
//                  }
//                }
//                
//                guard progress.isCancelled != true else { return }
//                
//                data = try Data(contentsOf: tempFileURL, options: [.alwaysMapped])
//              }
//            }
//          } catch let err {
//            print("[fetchThumbnails] error: \(err)")
//            
//            error = err
//          }
//          
//          progress.completedUnitCount += 1
//          
//          perThumbnailCompletionHandler(identifier, data, error)
//          
//          if (progress.isFinished) {
//            completionHandler(error)
//          }
//        }
//      }
//      
//      return progress
//    }
//  }
  
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network")
func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest) throws -> NSFileProviderEnumerator {
    logger.error("mmm \(containerItemIdentifier.rawValue)")
    if (!FileProviderUtils.shared.isLoggedIn() || FileProviderUtils.shared.needsFaceID()) {
        print("fail")

      throw NSFileProviderError(.notAuthenticated)
    }
    
        print("starting")
    return FileProviderEnumerator(identifier: containerItemIdentifier)
  }
    
//    func signalEnumerator(completionHandler: @escaping(_ error: Error?) -> Void) {
//            guard let fpManager = NSFileProviderManager(for: self.domain) else {
//                return
//            }
//
//        fpManager.signalEnumerator(for: .rootContainer, completionHandler: completionHandler)
//        }
}
