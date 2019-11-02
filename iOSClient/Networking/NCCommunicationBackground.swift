//
//  NCCommunicationBackground.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 29/10/19.
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


import Foundation

@objc public class NCCommunicationBackground: NSObject, URLSessionTaskDelegate, URLSessionDelegate, URLSessionDownloadDelegate {
    @objc public static let sharedInstance: NCCommunicationBackground = {
        let instance = NCCommunicationBackground()
        return instance
    }()
        
    @objc public lazy var sessionManagerTransfer: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: NCCommunicationCommon.sharedInstance.session_identifier_background)
        configuration.allowsCellularAccess = true
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        return session
    }()
    
    @objc public lazy var sessionManagerExtension: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: NCCommunicationCommon.sharedInstance.session_identifier_extension)
        configuration.allowsCellularAccess = true
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        configuration.sharedContainerIdentifier = NCCommunicationCommon.sharedInstance.capabilitiesGroup
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        return session
    }()
    
    //MARK: - Download
    
    @objc public func downlopad(serverUrlFileName: String, fileNameLocalPath: String, session: URLSession) -> URLSessionDownloadTask? {
        
        guard let url = NCCommunicationCommon.sharedInstance.encodeUrlString(serverUrlFileName) as? URL else {
            return nil
        }
        var request = URLRequest(url: url)
        let loginString = "\(NCCommunicationCommon.sharedInstance.username):\(NCCommunicationCommon.sharedInstance.password)"
        guard let loginData = loginString.data(using: String.Encoding.utf8) else {
            return nil
        }
        let base64LoginString = loginData.base64EncodedString()
        
        request.setValue(NCCommunicationCommon.sharedInstance.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        // session
        let task = session.downloadTask(with: request)
        
        task.taskDescription = fileNameLocalPath
        task.resume()
        return task
    }
    
    //MARK: - Upload
    
    @objc public func upload(serverUrlFileName: String, fileNamePathSource: String, description: String?, session: URLSession) -> URLSessionUploadTask? {
        
        guard let url = NCCommunicationCommon.sharedInstance.encodeUrlString(serverUrlFileName) as? URL else {
            return nil
        }
        var request = URLRequest(url: url)
        let loginString = "\(NCCommunicationCommon.sharedInstance.username):\(NCCommunicationCommon.sharedInstance.password)"
        guard let loginData = loginString.data(using: String.Encoding.utf8) else {
            return nil
        }
        let base64LoginString = loginData.base64EncodedString()
        
        request.httpMethod = "PUT"
        request.setValue(NCCommunicationCommon.sharedInstance.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
      
        // session
        let task = session.uploadTask(with: request, fromFile: URL.init(fileURLWithPath: fileNamePathSource))
        
        task.taskDescription = description
        task.resume()
        return task
    }
    
    //MARK: - SessionDelegate
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) { }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        guard totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown else { return }
        guard let url = downloadTask.currentRequest?.url?.absoluteString.removingPercentEncoding else { return }
        let fileName = (url as NSString).lastPathComponent
        let serverUrl = url.replacingOccurrences(of: "/"+fileName, with: "")
        let progress = Double(Double(totalBytesWritten)/Double(totalBytesExpectedToWrite))

        DispatchQueue.main.async {
            NCCommunicationCommon.sharedInstance.downloadProgress(progress, fileName: fileName, ServerUrl: serverUrl, session: session, task: downloadTask)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        if let httpResponse = (downloadTask.response as? HTTPURLResponse) {
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                if let destinationFilePath = downloadTask.taskDescription {
                    let destinationUrl = NSURL.fileURL(withPath: destinationFilePath)
                    do {
                        try FileManager.default.removeItem(at: destinationUrl)
                        try FileManager.default.copyItem(at: location, to: destinationUrl)
                    } catch { }
                }
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        guard totalBytesExpectedToSend != NSURLSessionTransferSizeUnknown else { return }
        guard let url = task.currentRequest?.url?.absoluteString.removingPercentEncoding else { return }
        let fileName = (url as NSString).lastPathComponent
        let serverUrl = url.replacingOccurrences(of: "/"+fileName, with: "")
        let progress = Double(Double(totalBytesSent)/Double(totalBytesExpectedToSend))

        DispatchQueue.main.async {
            NCCommunicationCommon.sharedInstance.uploadProgress(progress, fileName: fileName, ServerUrl: serverUrl, session: session, task: task)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        var fileName: String = "", serverUrl: String = "", etag: String?, ocId: String?, date: NSDate?, dateLastModified: NSDate?, length: Double = 0
        let url = task.currentRequest?.url?.absoluteString.removingPercentEncoding
        if url != nil {
            fileName = (url! as NSString).lastPathComponent
            serverUrl = url!.replacingOccurrences(of: "/"+fileName, with: "")
        }
        
        let statusCode = (task.response as! HTTPURLResponse).statusCode

        if let header = (task.response as? HTTPURLResponse)?.allHeaderFields {
            etag = header["OC-ETag"] as? String
            if etag != nil { etag = etag!.replacingOccurrences(of: "\"", with: "") }
            ocId = header["OC-FileId"] as? String
            if let dateString = header["Date"] as? String {
                date = NCCommunicationCommon.sharedInstance.convertDate(dateString, format: "EEE, dd MMM y HH:mm:ss zzz")
            }
            if let dateString = header["Last-Modified"] as? String {
                dateLastModified = NCCommunicationCommon.sharedInstance.convertDate(dateString, format: "EEE, dd MMM y HH:mm:ss zzz")
            }
            length = header["Content-Length"] as? Double ?? 0
        }
        
        DispatchQueue.main.async {
            if task is URLSessionDownloadTask {
                NCCommunicationCommon.sharedInstance.downloadComplete(fileName: fileName, serverUrl: serverUrl, etag: etag, date: date, dateLastModified: dateLastModified, length: length, session: session, task: task, error: error, statusCode: statusCode)
            }
            if task is URLSessionUploadTask {
                NCCommunicationCommon.sharedInstance.uploadComplete(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, session: session, task: task, error: error, statusCode: statusCode)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        NCCommunicationCommon.sharedInstance.authenticationChallenge(challenge, completionHandler: { (authChallengeDisposition, credential) in
            completionHandler(authChallengeDisposition, credential)
        })
    }
}
