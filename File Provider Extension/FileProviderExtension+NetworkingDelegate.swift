//
//  FileProviderExtension+NetworkingDelegate.swift
//  File Provider Extension
//
//  Created by Marino Faggiana on 02/11/2019.
//  Copyright © 2019 TWS. All rights reserved.
//

import FileProvider

extension FileProviderExtension: NCNetworkingDelegate {

    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Double, session: URLSession, task: URLSessionTask, error: Error?, statusCode: Int) {
        
        if error == nil && statusCode >= 200 && statusCode < 300 {
        }
    }
    
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, session: URLSession, task: URLSessionTask, error: Error?, statusCode: Int) {
                
        guard let ocIdTemp = task.taskDescription else { return }
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp)) else { return }
        
        if error == nil && statusCode >= 200 && statusCode < 300 {
            guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
                return
            }
            var item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
            
            metadata.fileName = fileName
            metadata.serverUrl = serverUrl
            if let etag = etag { metadata.etag = etag }
            if let ocId = ocId { metadata.ocId = ocId }
            if let date = date { metadata.date = date }
            metadata.status = Int(k_metadataStatusNormal)
                  
            guard let metadataUpdated = NCManageDatabase.sharedInstance.addMetadata(metadata) else { return }
            NCManageDatabase.sharedInstance.addLocalFile(metadata: metadataUpdated)
            NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
            
            // Signal delete
            fileProviderData.sharedInstance.fileProviderSignalDeleteContainerItemIdentifier[item.itemIdentifier] = item.itemIdentifier
            fileProviderData.sharedInstance.fileProviderSignalDeleteWorkingSetItemIdentifier[item.itemIdentifier] = item.itemIdentifier

            // File system
            let atPath = CCUtility.getDirectoryProviderStorageOcId(ocIdTemp)
            let toPath = CCUtility.getDirectoryProviderStorageOcId(ocId)
            CCUtility.moveFile(atPath: atPath, toPath: toPath)
            
            // Signal update
            item = FileProviderItem(metadata: metadataUpdated, parentItemIdentifier: parentItemIdentifier)
            fileProviderData.sharedInstance.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
            fileProviderData.sharedInstance.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
            
            fileProviderData.sharedInstance.signalEnumerator(for: [parentItemIdentifier, .workingSet])
            
        } else {
           
            // Error
            NCManageDatabase.sharedInstance.setMetadataSession("", sessionError: error?.localizedDescription, sessionSelector: "", sessionTaskIdentifier: 0, status: Int(k_metadataStatusUploadError), predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
        }
    }
}
