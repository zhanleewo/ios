//
//  FileProviderExtension.swift
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

/* -----------------------------------------------------------------------------------------------------------------------------------------------
                                                            STRUCT item
   -----------------------------------------------------------------------------------------------------------------------------------------------
 
 
    itemIdentifier = NSFileProviderItemIdentifier.rootContainer.rawValue            --> root
    parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer.rawValue      --> root
 
                                    ↓
 
    itemIdentifier = metadata.ocId (ex. 00ABC1)                                     --> func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier
    parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer.rawValue      --> func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier?
 
                                    ↓

    itemIdentifier = metadata.ocId (ex. 00CCC)                                      --> func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier
    parentItemIdentifier = parent itemIdentifier (00ABC1)                           --> func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier?
 
                                    ↓
 
    itemIdentifier = metadata.ocId (ex. 000DD)                                      --> func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier
    parentItemIdentifier = parent itemIdentifier (00CCC)                            --> func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier?
 
   -------------------------------------------------------------------------------------------------------------------------------------------- */

class FileProviderExtension: NSFileProviderExtension, NCNetworkingDelegate {
    
    var outstandingSessionTasks = [URL: URLSessionTask]()
    
    override init() {
        super.init()
        
        // Create directory File Provider Storage
        CCUtility.getDirectoryProviderStorage()
    }
    
    // MARK: - Enumeration
    
    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        
        var maybeEnumerator: NSFileProviderEnumerator? = nil
        
        // Check account single
        if (containerItemIdentifier != NSFileProviderItemIdentifier.workingSet) {
            if fileProviderData.sharedInstance.setupActiveAccount(domain: nil, providerExtension: self) == false {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo:[:])
            }
        }
        
        // Check account domain
        /*
        if (containerItemIdentifier != NSFileProviderItemIdentifier.workingSet) {
            if containerItemIdentifier == NSFileProviderItemIdentifier.rootContainer && self.domain?.identifier.rawValue == nil {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo:[:])
            } else if self.domain?.identifier.rawValue != nil {
                if fileProviderData.sharedInstance.setupActiveAccount(domain: self.domain?.identifier.rawValue, providerExtension: self) == false {
                    throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo:[:])
                }
            } else {
                if fileProviderData.sharedInstance.setupActiveAccount(itemIdentifier: containerItemIdentifier, providerExtension: self) == false {
                    throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo:[:])
                }
            }
        }
        */

        if (containerItemIdentifier == NSFileProviderItemIdentifier.rootContainer) {
            maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
        } else if (containerItemIdentifier == NSFileProviderItemIdentifier.workingSet) {
            maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
        } else {
            // determine if the item is a directory or a file
            // - for a directory, instantiate an enumerator of its subitems
            // - for a file, instantiate an enumerator that observes changes to the file
            let item = try self.item(for: containerItemIdentifier)
            
            if item.typeIdentifier == kUTTypeFolder as String {
                maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
            } else {
                maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
            }
        }
        
        guard let enumerator = maybeEnumerator else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
        }
        
        return enumerator
    }
    
    // MARK: - Item

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        
        if identifier == .rootContainer {
            
            let metadata = tableMetadata()
            
            metadata.account = fileProviderData.sharedInstance.account
            metadata.directory = true
            metadata.ocId = NSFileProviderItemIdentifier.rootContainer.rawValue
            metadata.fileName = ""
            metadata.fileNameView = ""
            metadata.serverUrl = fileProviderData.sharedInstance.homeServerUrl
            metadata.typeFile = k_metadataTypeFile_directory
            
            return FileProviderItem(metadata: metadata, parentItemIdentifier: NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue))
            
        } else {
            
            guard let metadata = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(identifier) else {
                throw NSFileProviderError(.noSuchItem)
            }
            guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
                throw NSFileProviderError(.noSuchItem)
            }
            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
            return item
        }
    }
    
    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        
        // resolve the given identifier to a file on disk
        guard let item = try? item(for: identifier) else {
            return nil
        }
        
        // in this implementation, all paths are structured as <base storage directory>/<item identifier>/<item file name>
        
        let manager = NSFileProviderManager.default
        var url = manager.documentStorageURL.appendingPathComponent(identifier.rawValue, isDirectory: true)
        
        if item.typeIdentifier == (kUTTypeFolder as String) {
            url = url.appendingPathComponent(item.filename, isDirectory:true)
        } else {
            url = url.appendingPathComponent(item.filename, isDirectory:false)
        }
        
        return url
    }
    
    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        
        // resolve the given URL to a persistent identifier using a database
        let pathComponents = url.pathComponents
        
        // exploit the fact that the path structure has been defined as
        // <base storage directory>/<item identifier>/<item file name> above
        assert(pathComponents.count > 2)
        
        let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
        return itemIdentifier
    }
    
    // MARK: -
    
    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        
        guard let identifier = persistentIdentifierForItem(at: url) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
        
        do {
            let fileProviderItem = try item(for: identifier)
            let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
            try NSFileProviderManager.writePlaceholder(at: placeholderURL,withMetadata: fileProviderItem)
            completionHandler(nil)
        } catch let error {
            print("error: \(error)")
            completionHandler(error)
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
        
        let pathComponents = url.pathComponents
        let identifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
        
        if let _ = outstandingSessionTasks[url] {
            return
        }
        
        guard let metadata = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(identifier) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
        let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        if tableLocalFile != nil && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) && tableLocalFile?.etag == metadata.etag  {
            completionHandler(nil)
            return
        }
        
        let task = NCCommunication.sharedInstance.download(serverUrlFileName: metadata.serverUrl + "/" + metadata.fileName, fileNamePathLocalDestination: url.path, account: fileProviderData.sharedInstance.account, progressHandler: { (progress) in
            
        }) { (account, etag, date, lenght, error) in
            
            // remove Task
            self.outstandingSessionTasks.removeValue(forKey: url)
            
            if error == nil {
                
                guard let metadata = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(identifier) else {
                    completionHandler(NSFileProviderError(.noSuchItem))
                    return
                }
                
                metadata.date = date! as NSDate
                metadata.etag = etag!
                metadata.size = Double(lenght)
                
                guard let metadataUpdate = NCManageDatabase.sharedInstance.addMetadata(metadata) else { return }
                NCManageDatabase.sharedInstance.addLocalFile(metadata: metadataUpdate)
                
                completionHandler(nil)
                
            } else {
                
//                if errorCode == Int(CFNetworkErrors.cfurlErrorCancelled.rawValue) {
//                    completionHandler(NSFileProviderError(.noSuchItem))
//                } else {
                    completionHandler(NSFileProviderError(.serverUnreachable))
//                }
            }
        }
        
        // Add and register task
        if task != nil {
            outstandingSessionTasks[url] = task
            NSFileProviderManager.default.register(task!, forItemWithIdentifier: NSFileProviderItemIdentifier(identifier.rawValue)) { (error) in }
        }
    }
    
    override func itemChanged(at url: URL) {
        
        let pathComponents = url.pathComponents
        assert(pathComponents.count > 2)
        let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", itemIdentifier.rawValue)) else { return }

        let fileName = pathComponents[pathComponents.count - 1]
        let fileNameServerUrl = metadata.serverUrl + "/" + fileName
        let fileNameLocalPath = url.path
        
        _ = NCCommunication.sharedInstance.upload(serverUrlFileName: fileNameServerUrl, fileNamePathSource: fileNameLocalPath, account: fileProviderData.sharedInstance.account, progressHandler: { (progress) in
        }) { (account, ocId, etag, date, error) in
            if error == nil {
                NCManageDatabase.sharedInstance.setLocalFile(ocId: itemIdentifier.rawValue, date: date! as NSDate, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: nil, etag: etag!)
                // remove preview ico
                CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageIconOcId(itemIdentifier.rawValue, fileNameView: fileName))
            }
        }
    }
    
    /*
    override func itemChanged(at url: URL) {
        
        var size = 0 as Double
        let pathComponents = url.pathComponents
        assert(pathComponents.count > 2)
        let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND ocId == %@", fileProviderData.sharedInstance.account, itemIdentifier.rawValue)) else { return }
        guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else { return }
        
        // typefile directory ? (NOT PERMITTED)
        do {
            let attributes = try fileProviderUtility.sharedInstance.fileManager.attributesOfItem(atPath: url.path)
            size = attributes[FileAttributeKey.size] as! Double
            let typeFile = attributes[FileAttributeKey.type] as! FileAttributeType
            if typeFile == FileAttributeType.typeDirectory {
                return
            }
        } catch { return }
        
        let fileName = pathComponents[pathComponents.count - 1]
        let fileNameServerUrl = metadata.serverUrl + "/" + fileName
        let fileNameLocalPath = url.path
        
        let task = OCNetworking.sharedManager()?.upload(withAccount: fileProviderData.sharedInstance.account, fileNameServerUrl: fileNameServerUrl, fileNameLocalPath: fileNameLocalPath, encode: true, communication: OCNetworking.sharedManager()?.sharedOCCommunicationExtension(), progress: { (progress) in
            
        }, completion: { (account, ocId, etag, date, message, errorCode) in
            
            // remove Task
            self.outstandingSessionTasks.removeValue(forKey: url)
            
            guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND ocId == %@", fileProviderData.sharedInstance.account, itemIdentifier.rawValue)) else { return }
            
            if account == fileProviderData.sharedInstance.account && errorCode == 0 {
                
                metadata.sessionTaskIdentifier = Int(k_taskIdentifierDone)
                metadata.status = Int(k_metadataStatusNormal)
                metadata.session = ""
                metadata.date = date! as NSDate
                metadata.etag = etag!
                metadata.size = size
                
                guard let metadataUpdate = NCManageDatabase.sharedInstance.addMetadata(metadata) else { return }
                NCManageDatabase.sharedInstance.setLocalFile(ocId: metadataUpdate.ocId, date: metadataUpdate.date, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: nil, etag: metadataUpdate.etag)
                
                // Signal update/delete
                _ = fileProviderData.sharedInstance.fileProviderSignal(metadata: metadataUpdate, parentItemIdentifier: parentItemIdentifier, delete: false, update: true)
                
            } else {
                
                metadata.sessionTaskIdentifier = Int(k_taskIdentifierDone)
                metadata.status = Int(k_metadataStatusNormal)
                metadata.session = ""
                _ = NCManageDatabase.sharedInstance.addMetadata(metadata)
            }
        })
        
        // Add and register task
        if task != nil {
            
            metadata.sessionTaskIdentifier = Int(task!.taskIdentifier)
            metadata.status = Int(k_metadataStatusUploading)
            metadata.session = k_upload_session_extension
            
            guard let metadataUpdate = NCManageDatabase.sharedInstance.addMetadata(metadata) else { return }
            
            // Signal update/delete
            _ = fileProviderData.sharedInstance.fileProviderSignal(metadata: metadataUpdate, parentItemIdentifier: parentItemIdentifier, delete: false, update: true)
            
            self.outstandingSessionTasks[url] = task
            NSFileProviderManager.default.register(task!, forItemWithIdentifier: NSFileProviderItemIdentifier(itemIdentifier.rawValue)) { (error) in }
        }
    }
    */
    
    override func stopProvidingItem(at url: URL) {
        // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
        // Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.
        
        // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
        
        // look up whether the file has local changes
        let fileHasLocalChanges = false
        
        if !fileHasLocalChanges {
            // remove the existing file to free up space
            do {
                _ = try fileProviderUtility.sharedInstance.fileManager.removeItem(at: url)
            } catch let error {
                print("error: \(error)")
            }
            
            // write out a placeholder to facilitate future property lookups
            self.providePlaceholder(at: url, completionHandler: { error in
                // handle any error, do any necessary cleanup
            })
        }
        
        // Download task
        if let downloadTask = outstandingSessionTasks[url] {
            downloadTask.cancel()
            outstandingSessionTasks.removeValue(forKey: url)
        }
    }
    
    override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
                
        DispatchQueue.main.async {
            
            autoreleasepool {
            
                var size = 0 as Double
                var error: NSError?
                let metadata = tableMetadata()
                
                guard let tableDirectory = fileProviderUtility.sharedInstance.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.sharedInstance.account, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                
                if fileURL.startAccessingSecurityScopedResource() == false {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                
                // typefile directory ? (NOT PERMITTED)
                do {
                    let attributes = try fileProviderUtility.sharedInstance.fileManager.attributesOfItem(atPath: fileURL.path)
                    size = attributes[FileAttributeKey.size] as! Double
                    let typeFile = attributes[FileAttributeKey.type] as! FileAttributeType
                    if typeFile == FileAttributeType.typeDirectory {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                        return
                    }
                } catch {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
        
                let fileName = NCUtility.sharedInstance.createFileName(fileURL.lastPathComponent, serverUrl: tableDirectory.serverUrl, account: fileProviderData.sharedInstance.account)
                let ocIdTemp = NSUUID().uuidString.lowercased()
                
                NSFileCoordinator().coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &error) { (url) in
                    _ = fileProviderUtility.sharedInstance.moveFile(url.path, toPath: CCUtility.getDirectoryProviderStorageOcId(ocIdTemp, fileNameView: fileName))
                }
                
                fileURL.stopAccessingSecurityScopedResource()
                
                // ---------------------------------------------------------------------------------
                
                metadata.account = fileProviderData.sharedInstance.account
                metadata.date = NSDate()
                metadata.directory = false
                metadata.etag = ""
                metadata.fileName = fileName
                metadata.fileNameView = fileName
                metadata.ocId = ocIdTemp
                metadata.serverUrl = tableDirectory.serverUrl
                metadata.size = size
                metadata.status = Int(k_metadataStatusInUpload)
                CCUtility.insertTypeFileIconName(fileName, metadata: metadata)
                
                guard let metadataForUpload = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                
                let serverUrlFileName = tableDirectory.serverUrl + "/" + fileName
                let fileNamePathSource = CCUtility.getDirectoryProviderStorageOcId(ocIdTemp, fileNameView: fileName)!
                
                if let task = NCCommunicationBackground.sharedInstance.upload(serverUrlFileName: serverUrlFileName, fileNamePathSource: fileNamePathSource, description: ocIdTemp, session: NCCommunicationBackground.sharedInstance.sessionManagerExtension) {
                    NSFileProviderManager.default.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(ocIdTemp)) { (error) in }
                }
                
                let item = FileProviderItem(metadata: metadataForUpload, parentItemIdentifier: parentItemIdentifier)
                completionHandler(item, nil)
            }
        }
    }
    
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, session: URLSession, task: URLSessionTask, error: Error?) {
                
        guard let ocIdTemp = task.taskDescription else { return }
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp)) else { return }
        
        if error == nil  {
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
