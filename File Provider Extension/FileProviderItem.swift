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

class FileProviderItem: NSObject, NSFileProviderItem {

    var metadata = tableMetadata()

    var itemIdentifier: NSFileProviderItemIdentifier {
        return fileProviderUtility.sharedInstance.getItemIdentifier(metadata: metadata)
    }
    
    var filename: String {
        return metadata.fileNameView
    }
    
    var contentModificationDate: Date? {
        return metadata.date as Date
    }
    
    var creationDate: Date? {
        return metadata.date as Date
    }
    
    var lastUsedDate: Date? {
        return metadata.date as Date
    }

    
    var typeIdentifier: String = ""
    var capabilities: NSFileProviderItemCapabilities {
        if (metadata.directory) {
            return [ .allowsAddingSubItems, .allowsContentEnumerating, .allowsReading, .allowsDeleting, .allowsRenaming ]
        } else {
            return [ .allowsWriting, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting ]
        }
    }
    
    var childItemCount: NSNumber?
    var documentSize: NSNumber?

    var parentItemIdentifier: NSFileProviderItemIdentifier
    var isTrashed: Bool = false
   
    var isMostRecentVersionDownloaded: Bool = true

    var isUploading: Bool = false
    var isUploaded: Bool = true
    var uploadingError: Error?
    
    var isDownloading: Bool = false
    var isDownloaded: Bool = true
    var downloadingError: Error?

    var tagData: Data?
    var favoriteRank: NSNumber? 

    init(metadata: tableMetadata, parentItemIdentifier: NSFileProviderItemIdentifier) {
        
        self.metadata = metadata
        self.parentItemIdentifier = parentItemIdentifier
    
        documentSize = NSNumber(value: metadata.size)
        
        typeIdentifier = CCUtility.insertTypeFileIconName(metadata.fileNameView, metadata: metadata)
        
        if (!metadata.directory) {
            
            documentSize = NSNumber(value: metadata.size)
           
            // Local file
            let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            if tableLocalFile == nil {
                isMostRecentVersionDownloaded = false
                isDownloaded = false
            } else {
                isMostRecentVersionDownloaded = true
                isDownloaded = true
            }
            
            // Downloading
            if (metadata.status == Int(k_metadataStatusInDownload)) {
                isDownloaded = false
                isDownloading = true
            }
            
            // Upload
            if (metadata.status == Int(k_metadataStatusInUpload)) {
                isUploaded = false
                isUploading = true
            }
            
            // Error ?
            if metadata.sessionError != "" {
                uploadingError = NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
            }
            
        } else {
            
            // Favorite directory
            let rank = fileProviderData.sharedInstance.listFavoriteIdentifierRank[metadata.ocId]
            if (rank == nil) {
                favoriteRank = nil
            } else {
                favoriteRank = fileProviderData.sharedInstance.listFavoriteIdentifierRank[metadata.ocId]
            }
        }
        
        // Tag
        if let tableTag = NCManageDatabase.sharedInstance.getTag(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            tagData = tableTag.tagIOS
        }
    }
}
