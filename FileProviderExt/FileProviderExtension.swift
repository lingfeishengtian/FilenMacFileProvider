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
import Alamofire

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
        
        do {
            let prog = Progress(totalUnitCount: Int64(itemJSON.chunks))
            Task {
                do{
                    FileProviderUtils.currentDownloads[itemJSON.uuid] = true
                    
                    defer {
                        FileProviderUtils.currentDownloads.removeValue(forKey: itemJSON.uuid)
                    }
                    
                    if itemJSON.type == "file" {
                        let tempFileURL = try FileProviderUtils.shared.getTempPath().appendingPathComponent(UUID().uuidString.lowercased() + "." + identifier.rawValue, isDirectory: false)
                        
                        let (_, svdURL) = try await FileProviderUtils.shared.downloadFile(uuid: itemJSON.uuid, url: tempFileURL.path, maxChunks: itemJSON.chunks, progress: prog)
                        
                        let finURL = URL(filePath: svdURL)
                        
                        completionHandler(finURL, FileProviderItem(
                            identifier: identifier,
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
                            )), nil)
                        FileProviderUtils.shared.signalEnumerator()
                    } else {
                        guard let masterKeys = FileProviderUtils.shared.masterKeys(), let apiKey = FileProviderUtils.shared.apiKey(), let url = URL(string: "https://gateway.filen.io/v3/dir/content") else {
                            completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
                            return
                        }
                        let headers: HTTPHeaders = [
                            "Authorization": "Bearer \(apiKey)",
                            "Accept": "application/json",
                            "Content-Type": "application/json"
                        ]
                        let tempFileURL = try FileProviderUtils.shared.getTempPath().appendingPathComponent(UUID().uuidString.lowercased() + "." + identifier.rawValue, isDirectory: true)
                        if !FileManager.default.fileExists(atPath: tempFileURL.path) {
                            try FileManager.default.createDirectory(at: tempFileURL, withIntermediateDirectories: true)
                        }
                        
                        prog.totalUnitCount = 0
                        let downloadSemaphore = Semaphore(max: 20)
                        @Sendable func downloadFolderContents(folderUUID: String, folderURL: URL) async {
                            do {
                                let folderSemaphore = Semaphore(max: 10)
                                let tmpJSONURL = try await FileProviderUtils.shared.sessionManager.download(url, method: .post, parameters: ["uuid": folderUUID], encoding: JSONEncoding.default, headers: headers){ $0.timeoutInterval = 3600 }.validate().serializingDownloadedFileURL().value
                                print("starting \(tmpJSONURL.absoluteString)")
                                let _ = await FileProviderEnumerator.parseTempJSON(tempJSONFileURL: tmpJSONURL, errorHandler: {
                                    completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
                                }, handleFile: { file in
                                    prog.totalUnitCount += 1
                                    let metadata = FilenCrypto.shared.decryptFileMetadata(metadata: file.metadata, masterKeys: masterKeys)!
                                    try await downloadSemaphore.acquire()
                                    Task {
                                        do {
                                            defer {
                                                downloadSemaphore.release()
                                            }
                                            let _ = try await FileProviderUtils.shared.downloadFile(uuid: file.uuid, url: folderURL.appendingPathComponent(metadata.name, isDirectory: false).path, maxChunks: file.chunks, customJSON: ItemJSON(
                                                uuid: file.uuid,
                                                parent: file.parent,
                                                name: metadata.name,
                                                type: "file",
                                                mime: metadata.mime ?? "", 
                                                size: metadata.size ?? 0,
                                                timestamp: file.timestamp,
                                                lastModified: file.timestamp,
                                                key: metadata.key,
                                                chunks: file.chunks,
                                                region: file.region, 
                                                bucket: file.bucket,
                                                version: file.version))
                                            prog.completedUnitCount += 1
                                        }catch {
                                            print(error)
                                        }
                                    }
                                    return true
                                }, handleFolder: { folder in
                                    let name = FilenCrypto.shared.decryptFolderName(metadata: folder.name, masterKeys: masterKeys)
                                    let newFolderURL = folderURL.appendingPathComponent(name!, isDirectory: true)
                                    try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: true)
                                    try await folderSemaphore.acquire()
                                    Task {
                                        defer {
                                            folderSemaphore.release()
                                        }
                                        await downloadFolderContents(folderUUID: folder.uuid, folderURL:newFolderURL)
                                    }
                                    return true
                                })
                                folderSemaphore.setMax(newMax: 1)
                                try await folderSemaphore.acquire()
                            } catch {
                                completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
                            }
                        }
                        
                        await downloadFolderContents(folderUUID: itemJSON.uuid, folderURL: tempFileURL)
                        downloadSemaphore.setMax(newMax: 1)
                        try await downloadSemaphore.acquire()
                        completionHandler(tempFileURL, FileProviderItem(
                            identifier: identifier,
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
                            )), nil)
                        FileProviderUtils.shared.signalEnumerator()
                    }
                }catch{
                    print("[startProvidingItem] error:", error)
                    
                    completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
                }
            }
            return prog
        }
    }
    
    func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?, options: NSFileProviderCreateItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        if (itemTemplate.contentType == .folder) {
            Task {
                do {
                    print("Trying create dir")
                    let item = try await createDirectory(filename: itemTemplate.filename, creationDate: itemTemplate.creationDate ?? nil, inParentItemIdentifier: itemTemplate.parentItemIdentifier)
                    completionHandler(item, NSFileProviderItemFields(), false, nil)
                } catch {
                    completionHandler(nil, NSFileProviderItemFields(), false, NSFileProviderError(NSFileProviderError.serverUnreachable))
                }
            }
        } else {
            let progress = Progress(totalUnitCount: Int64(1))
            Task {
                do {
                    print("Trying import")
                    let item = try await importDocument(at: url!, toParentItemIdentifier: itemTemplate.parentItemIdentifier, with: itemTemplate.filename, creationDate: itemTemplate.creationDate ?? nil, progress: progress, size: itemTemplate.documentSize ?? 0)
                    completionHandler(item, NSFileProviderItemFields(), false, nil)
                    //await FileProviderUtils.shared.signalEnumeratorAsync()
                } catch {
                    print(error)
                    completionHandler(nil, NSFileProviderItemFields(), false, NSFileProviderError(.serverUnreachable))
                }
            }
            return progress
        }
        
        return Progress()
    }
    
    let modifySemaphore = Semaphore(max: 1)
    func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields, contents newContents: URL?, options: NSFileProviderModifyItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        print("modify some")
        print(changedFields)
        
        if let cont = newContents {
            Task {
                print("waiting sem")
                try await modifySemaphore.acquire()
                print("acquired sem")
                let prog = Progress(totalUnitCount: Int64(1))
                itemChanged(for: item, at: cont, completionHandler: completionHandler, progress: prog)
                return prog
            }
        } else {
            Task {
                var id: NSFileProviderItem?
                if (changedFields.contains(.parentItemIdentifier)) {
                    if (item.parentItemIdentifier == .trashContainer) {
                        print("trashing")
                        _ = try await trashItem(withIdentifier: item.itemIdentifier)
                        try await FileProviderUtils.shared.manager.evictItem(identifier: item.itemIdentifier)
                        // TODO: Stopped supporting cause was broken lol
                        completionHandler(nil, NSFileProviderItemFields(), false, nil)
                        return
                    } else {
                        print("reparent")
                        id = try await reparentItem(withItem: item, toParentItemWithIdentifier: item.parentItemIdentifier, newName: item.filename)
                    }
                }
                if (changedFields.contains(.filename)) {
                    print("renaming")
                    id = try await renameItem(with: item, toName: item.filename)
                }
                if (id == nil) {
                    if let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: item.itemIdentifier.rawValue) {
                        completionHandler(FileProviderItem(
                            identifier: item.itemIdentifier,
                            parentIdentifier: item.parentItemIdentifier,
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
                            )), NSFileProviderItemFields(), false, nil)
                    }
                } else {
                    completionHandler(id, NSFileProviderItemFields(), false, nil)
                }
            }
        }
        
        return Progress()
    }
    
    
    
    func deleteItem(identifier: NSFileProviderItemIdentifier, baseVersion version: NSFileProviderItemVersion, options: NSFileProviderDeleteItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (Error?) -> Void) -> Progress {
        print("del")
        
        guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: identifier.rawValue) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return Progress()
        }
        
        Task{
            do {
                try await FileProviderUtils.shared.deleteItem(uuid: itemJSON.uuid, type: itemJSON.type == "folder" ? .folder : .file)
                
                try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [itemJSON.uuid])
                completionHandler(nil)
            }catch {
                completionHandler(NSFileProviderError(.serverUnreachable))
            }
        }
        
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
        print("requesting item for \(identifier.rawValue)")
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
                identifier: .rootContainer,
                parentIdentifier: .rootContainer,
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
        
        guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: identifier.rawValue) else {
            print("wtf3")        
            print("couldnt find item \(identifier.rawValue)")
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return Progress()
        }
        print("found item \(itemJSON.name) for \(itemJSON.uuid)")
        let item = FileProviderItem(
            identifier: identifier,
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
        completionHandler(item, nil)
        return Progress()
    }
    
    func itemChanged(for item: NSFileProviderItem, at url: URL, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void, progress: Progress) {
        let identifier = item.itemIdentifier
        
        guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: identifier.rawValue), FileManager.default.fileExists(atPath: url.path) else {
            completionHandler(nil, NSFileProviderItemFields(), false, NSFileProviderError(.noSuchItem))
            modifySemaphore.release()
            return
        }
        
        Task {
            FileProviderUtils.currentUploads[itemJSON.uuid] = true
            
            defer {
                FileProviderUtils.currentUploads.removeValue(forKey: itemJSON.uuid)
                
                FileProviderUtils.shared.signalEnumerator()
            }
            
            do {
                let newItem = try await importDocument(at: url, toParentItemIdentifier: item.parentItemIdentifier, with: item.filename, progress: progress)
                
                try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [itemJSON.uuid])
                completionHandler(newItem, NSFileProviderItemFields(), false, nil)
                modifySemaphore.release()
                print("release sem")
            } catch {
                print("[itemChanged] error: \(error)")
                completionHandler(nil, NSFileProviderItemFields(), false, NSFileProviderError(NSFileProviderError.serverUnreachable))
            }
        }
    }
    
    func stopProvidingItem(at url: URL) {
        let pathComponents = url.pathComponents
        let uuid = pathComponents[pathComponents.count - 2]
        
        do {
            try FileManager().removeItem(at: url)
            
            try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [uuid])
        } catch let error {
            print("[stopProvidingItem] error: \(error)")
        }
    }
    
    func createDirectory(filename: String, creationDate: Date?, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, isBundle: Bool = false) async throws -> NSFileProviderItem {
        do {
            let directoryName = filename
            guard let parentJSON = FileProviderUtils.shared.getItemFromUUID(uuid: parentItemIdentifier.rawValue) else {
                throw NSFileProviderError(.noSuchItem)
            }
            
            let uuid = try await FileProviderUtils.shared.createFolder(name: directoryName, parent: parentJSON.uuid)
            let timeStamp = Int((creationDate ?? Date.now)?.timeIntervalSince1970 ?? 0)
            
            try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [uuid])
            try FileProviderUtils.shared.openDb().run(
                "INSERT OR REPLACE INTO items (uuid, parent, name, type, mime, size, timestamp, lastModified, key, chunks, region, bucket, version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    uuid,
                    parentJSON.uuid,
                    directoryName,
                    isBundle ? "file" : "folder",
                    "",
                    0,
                    timeStamp,
                    timeStamp,
                    "",
                    0,
                    "",
                    "",
                    0
                ]
            )
            
            return FileProviderItem(
                identifier: FileProviderUtils.shared.getIdentifierFromUUID(id: uuid),
                parentIdentifier: parentItemIdentifier,
                item: Item(
                    uuid: uuid,
                    parent: parentJSON.uuid,
                    name: directoryName,
                    type: isBundle ? .file : .folder,
                    mime: "",
                    size: 0,
                    timestamp: FilenUtils.shared.convertUnixTimestampToMs(timeStamp),
                    lastModified: FilenUtils.shared.convertUnixTimestampToMs(timeStamp),
                    key: "",
                    chunks: 0,
                    region: "",
                    bucket: "",
                    version: 0
                )
            )
        } catch {
            print("[createDirectory] error:", error)
            
            throw error
        }
    }
    
    func renameItem(with item: NSFileProviderItem, toName itemName: String) async throws -> NSFileProviderItem {
        guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: item.itemIdentifier.rawValue) else {
            throw NSFileProviderError(.noSuchItem)
        }
        
        if (itemJSON.type == "folder") {
            try await FileProviderUtils.shared.renameFolder(uuid: itemJSON.uuid, toName: itemName)
            
            try FileProviderUtils.shared.openDb().run("UPDATE items SET name = ? WHERE uuid = ?;", [
                itemName,
                itemJSON.uuid
            ])
            
            return FileProviderItem(
                identifier: FileProviderUtils.shared.getIdentifierFromUUID(id: itemJSON.uuid),
                parentIdentifier: FileProviderUtils.shared.getIdentifierFromUUID(id: itemJSON.parent),
                item: Item(
                    uuid: itemJSON.uuid,
                    parent: itemJSON.parent,
                    name: itemName,
                    type: .folder,
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
        } else {
            try await FileProviderUtils.shared.renameFile(
                uuid: itemJSON.uuid,
                metadata: FileMetadata(
                    name: itemName,
                    size: itemJSON.size,
                    mime: itemJSON.mime,
                    key: itemJSON.key,
                    lastModified: itemJSON.lastModified
                )
            )
            
            try FileProviderUtils.shared.openDb().run("UPDATE items SET name = ? WHERE uuid = ?;", [
                itemName,
                itemJSON.uuid
            ])
            
            return FileProviderItem(
                identifier: FileProviderUtils.shared.getIdentifierFromUUID(id: itemJSON.uuid),
                parentIdentifier: FileProviderUtils.shared.getIdentifierFromUUID(id: itemJSON.parent),
                item: Item(
                    uuid: itemJSON.uuid,
                    parent: itemJSON.parent,
                    name: itemName,
                    type: .file,
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
    }
    
    func trashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem {
        guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: itemIdentifier.rawValue) else {
            throw NSFileProviderError(.noSuchItem)
        }
        
        try await FileProviderUtils.shared.trashItem(uuid: itemJSON.uuid, type: itemJSON.type == "folder" ? .folder : .file)
        
        try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [itemJSON.uuid])
        
        return FileProviderItem(
            identifier: itemIdentifier,
            parentIdentifier: .trashContainer,
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
    }
    
    func untrashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier?) async throws -> NSFileProviderItem {
        guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: itemIdentifier.rawValue) else {
            throw NSFileProviderError(.noSuchItem)
        }
        
        try await FileProviderUtils.shared.restoreItem(uuid: itemJSON.uuid, type: itemJSON.type == "folder" ? .folder : .file)
        
        try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [itemJSON.uuid])
        try FileProviderUtils.shared.openDb().run(
            "INSERT OR IGNORE INTO items (uuid, parent, name, type, mime, size, timestamp, lastModified, key, chunks, region, bucket, version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                itemJSON.uuid,
                itemJSON.parent,
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
            )
        )
    }
    
    func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws {
        guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: itemIdentifier.rawValue) else {
            throw NSFileProviderError(.noSuchItem)
        }
        
        try await FileProviderUtils.shared.deleteItem(uuid: itemJSON.uuid, type: itemJSON.type == "folder" ? .folder : .file)
        
        try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [itemJSON.uuid])
    }
    
    func reparentItem(withItem item: NSFileProviderItem, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?) async throws -> NSFileProviderItem {
        guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: item.itemIdentifier.rawValue), let parentJSON = FileProviderUtils.shared.getItemFromUUID(uuid: parentItemIdentifier.rawValue) else {
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
            identifier: item.itemIdentifier,
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
    
    func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, with filename: String, creationDate: Date? = nil, progress: Progress = Progress(), size: NSNumber? = nil, type: String? = nil) async throws -> NSFileProviderItem {
        guard let parentJSON = FileProviderUtils.shared.getItemFromUUID(uuid: parentItemIdentifier.rawValue) else {
            throw NSFileProviderError(.noSuchItem)
        }
        do {
            if fileURL.isDirectory {
                let dirContents = try FileManager.default.contentsOfDirectory(atPath: fileURL.path)
                let fProvItem = try await createDirectory(filename: filename, creationDate: nil, inParentItemIdentifier: parentItemIdentifier, isBundle: true)
                progress.totalUnitCount = Int64(dirContents.count)
                for name in dirContents {
//                    Task {
                        let _ = try await importDocument(at: fileURL.appendingPathComponent(name), toParentItemIdentifier: fProvItem.itemIdentifier, with: name, creationDate: creationDate)
                        progress.completedUnitCount += 1
//                    }
                }
                print ("\(fProvItem.filename) has \(fProvItem.itemIdentifier.rawValue)")
                
                return fProvItem
            }
            let result = try await FileProviderUtils.shared.uploadFile(url: fileURL.path, parent: parentJSON.uuid, with: filename, progress: progress)
            
            try FileProviderUtils.shared.openDb().run("DELETE FROM items WHERE uuid = ?", [result.uuid])
            try FileProviderUtils.shared.openDb().run(
                "INSERT OR IGNORE INTO items (uuid, parent, name, type, mime, size, timestamp, lastModified, key, chunks, region, bucket, version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    result.uuid,
                    parentJSON.uuid,
                    result.name,
                    //type ?? result.type,
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
                identifier: FileProviderUtils.shared.getIdentifierFromUUID(id: result.uuid),
                parentIdentifier: parentItemIdentifier,
                item: Item(
                    uuid: result.uuid,
                    parent: parentJSON.uuid,
                    name: result.name,
                    //type: ((type ?? result.type) == "folder") ? .folder : .file,
                    type: .folder,
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
            )
        )
        
        return item
    }
    
    func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem {
        guard let itemJSON = FileProviderUtils.shared.getItemFromUUID(uuid: itemIdentifier.rawValue) else {
            throw NSFileProviderError(.noSuchItem)
        }
        
        let item = FileProviderItem(
            identifier: itemIdentifier,
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
            )
        )
        
        item.tagData = tagData
        
        return item
    }
    
    func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest) throws -> NSFileProviderEnumerator {
        print("mmm \(containerItemIdentifier.rawValue)")
        if (!FileProviderUtils.shared.isLoggedIn() || FileProviderUtils.shared.needsFaceID()) {
            print("fail")
            
            throw NSFileProviderError(.notAuthenticated)
        }
        
        return FileProviderEnumerator(identifier: containerItemIdentifier, isReplicatedStorage: true)
    }
}
