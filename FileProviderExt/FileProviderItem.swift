//
//  FileProviderItem.swift
//  FileProviderExt
//
//  Created by Jan Lenczyk on 30.09.23.
//

import FileProvider
import UniformTypeIdentifiers

class FileProviderItem: NSObject, NSFileProviderItem {
  private let identifier: NSFileProviderItemIdentifier
  private let parentIdentifier: NSFileProviderItemIdentifier
    var item: Item

    
    init (identifier: NSFileProviderItemIdentifier, parentIdentifier: NSFileProviderItemIdentifier, item: Item) {
    self.identifier = identifier
    self.parentIdentifier = parentIdentifier
    self.item = item
    super.init()
  }

  var itemIdentifier: NSFileProviderItemIdentifier {
    self.identifier
  }
    
    var lastUsedDate: Date? {
        return self.contentModificationDate
    }
  
  var parentItemIdentifier: NSFileProviderItemIdentifier {
    self.parentIdentifier
  }
  
  var capabilities: NSFileProviderItemCapabilities {
      if (self.contentType == .folder) {
          return [ .allowsAddingSubItems,
                   .allowsContentEnumerating,
                   .allowsReading,
                   .allowsDeleting,
                   .allowsRenaming ]
      } else {
          return [ .allowsWriting,
                   .allowsReading,
                   .allowsDeleting,
                   .allowsRenaming,
                   .allowsReparenting]
      }
  }
    
    var contentPolicy: NSFileProviderContentPolicy {
        return .downloadLazilyAndEvictOnRemoteUpdate
    }
  
  var filename: String {
    self.item.name
  }
  
  var documentSize: NSNumber? {
    if (self.item.type == .folder) {
      return nil
    }
    
    return NSNumber(value: self.item.size)
  }
  
  var creationDate: Date? {
    Date(timeIntervalSince1970: TimeInterval(self.item.timestamp))
  }
  
    var contentModificationDate: Date? {
        (self.item.type == .folder) ?
        Date(timeIntervalSince1970: TimeInterval(self.item.lastModified)) :
        Date(timeIntervalSince1970: TimeInterval(self.item.lastModified / 1000))
    }
  
  var contentType: UTType {
    self.item.type == .folder ? .folder : (UTType(filenameExtension: FileProviderUtils.shared.fileExtension(from: self.item.name) ?? "") ?? .data)
  }
  
//  var favoriteRank: NSNumber? {
//    get {
//      nil //FileProviderUtils.shared.getFavoriteRank(uuid: itemIdentifier.rawValue)
//    }
//
//    set {
//      //FileProviderUtils.shared.setFavoriteRank(uuid: itemIdentifier.rawValue, rank: newValue)
//    }
//  }

  var tagData: Data? {
    get {
      nil //FileProviderUtils.shared.getTagData(uuid: itemIdentifier.rawValue)
    }
    
    set {
      //FileProviderUtils.shared.setTagData(uuid: itemIdentifier.rawValue, data: newValue)
    }
  }
  
  var childItemCount: NSNumber? {
    nil
  }
  
//  var versionIdentifier: Data? {
//    nil
//  }
    var itemVersion: NSFileProviderItemVersion {
//        return NSFileProviderItemVersion(contentVersion: Data(bytes: &item.version, count: MemoryLayout.size(ofValue: item.version)), metadataVersion: Data(bytes: &item.version, count: MemoryLayout.size(ofValue: item.version)))
        return NSFileProviderItemVersion()
    }
  
  var isMostRecentVersionDownloaded: Bool {
    true
  }
  
//  var isDownloaded: Bool {
////      autoreleasepool {
////        if let downloading = FileProviderUtils.currentDownloads[self.item.uuid] {
////          return !downloading
////        }
////        
////        return false
////      }
//      return false
//  }
  
  var isUploading: Bool {
    autoreleasepool {
      if let uploading = FileProviderUtils.currentUploads[self.item.uuid] {
        return uploading
      }
      
      return false
    }
  }
  
  var isDownloading: Bool {
    autoreleasepool {
      if let downloading = FileProviderUtils.currentDownloads[self.item.uuid] {
        return downloading
      }
      
      return false
    }
  }
}

