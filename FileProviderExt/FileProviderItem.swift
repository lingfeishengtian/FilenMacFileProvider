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
    
    var fileSystemFlags: NSFileProviderFileSystemFlags {
        var fsflags = [
            NSFileProviderFileSystemFlags.userReadable,
            .userWritable
            ]
        let type = UTType(tag: FileProviderUtils.shared.fileExtension(from: self.item.name) ?? "", tagClass: .filenameExtension, conformingTo: nil)
        if type?.conforms(to: .directory) ?? false && type?.conforms(to: .package) ?? false {
            fsflags.append(.userExecutable)
        }
        return NSFileProviderFileSystemFlags(fsflags)
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
      let type = UTType(tag: FileProviderUtils.shared.fileExtension(from: self.item.name) ?? "", tagClass: .filenameExtension, conformingTo: nil)
      if type?.conforms(to: .directory) ?? false && type?.conforms(to: .package) ?? false {
          return type!
      }
          return (self.item.type == .folder) ?
        //(UTType(tag: FileProviderUtils.shared.fileExtension(from: self.item.name) ?? "", tagClass: .filenameExtension, conformingTo: .package) ?? .folder) :
          .folder :
      (UTType(tag: FileProviderUtils.shared.fileExtension(from: self.item.name) ?? "", tagClass: .filenameExtension, conformingTo: nil)) ?? .content
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

