//
//  FileProviderItem.swift
//  Files
//
//  Created by Marino Faggiana on 26/03/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import FileProvider

final class FileProviderItem: NSObject {
    
    let parentItemIdent: NSFileProviderItemIdentifier

    let metadata: tableMetadata?
    let tableLocalFile: tableLocalFile?
    let tableTag: tableTag?

    init(metadata: tableMetadata, parentItemIdentifier: NSFileProviderItemIdentifier) {
        
        self.metadata = metadata
        self.parentItemIdent = parentItemIdentifier
        self.tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        self.tableTag = NCManageDatabase.sharedInstance.getTag(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

        super.init()
    }
}

extension FileProviderItem: NSFileProviderItem {
    
    var itemIdentifier: NSFileProviderItemIdentifier {
        return self.parentItemIdent
    }
  
    var parentItemIdentifier: NSFileProviderItemIdentifier {
        return fileProviderUtility.sharedInstance.getItemIdentifier(metadata: self.metadata!)
    }
  
    var filename: String {
        return metadata!.fileNameView
    }
  
    var typeIdentifier: String {
        return CCUtility.insertTypeFileIconName(metadata!.fileNameView, metadata: metadata!)
    }

    var capabilities: NSFileProviderItemCapabilities {
        if metadata!.directory {
            return [.allowsAddingSubItems, .allowsContentEnumerating, .allowsReading, .allowsDeleting, .allowsRenaming]
        } else {
            return [.allowsWriting, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting]
        }
    }

    var childItemCount: NSNumber? {
        return nil
    }
    
    var documentSize: NSNumber? {
        return NSNumber(value: metadata!.size)
    }
    
    var isTrashed: Bool {
        return false
    }
    
    var contentModificationDate: Date? {
        return metadata!.date as Date
    }
    
    var creationDate: Date? {
        return metadata!.date as Date
    }
    
    var lastUsedDate: Date? {
        return metadata!.date as Date
    }
    
    var versionIdentifier: Data? {
        return metadata!.etag.data(using: .utf8)
    }
    
    var isMostRecentVersionDownloaded: Bool {
        return true
    }
    
    var isUploading: Bool {
        if metadata!.status == Int(k_metadataStatusInUpload) {
            return true
        } else {
            return false
        }
    }
    
    var isUploaded: Bool {
        if metadata!.status == Int(k_metadataStatusInUpload) {
            return false
        } else {
            return true
        }
    }
    
    var uploadingError: Error? {
        if metadata!.status == Int(k_metadataStatusUploadError) {
            return NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
        } else {
            return nil
        }
    }
    
    var isDownloading: Bool {
        if metadata!.status == Int(k_metadataStatusInDownload) {
            return true
        } else {
            return false
        }
    }
    
    var isDownloaded: Bool {
        if tableLocalFile == nil {
            return false
        } else {
            return true
        }
    }
    
    var downloadingError: Error? {
        if metadata!.status == Int(k_metadataStatusDownloadError) {
            return NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
        } else {
            return nil
        }
    }
    
    var tagData: Data? {
        if tableTag != nil {
            return tableTag!.tagIOS
        } else {
            return nil
        }
    }
    
    var favoriteRank: NSNumber? {
        let rank = fileProviderData.sharedInstance.listFavoriteIdentifierRank[metadata!.ocId]
        if (rank == nil) {
            return nil
        } else {
            return rank
        }
    }
}
