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

@objc public protocol NCCommunicationBackgroundDelegate {
    @objc optional func authenticationChallenge(_ challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    @objc optional func downloadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func uploadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func uploadComplete(fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask, error: Error?)
}

@objc public class NCCommunicationBackground: NSObject, URLSessionTaskDelegate, URLSessionDelegate, URLSessionDownloadDelegate {
    @objc public static let sharedInstance: NCCommunicationBackground = {
        let instance = NCCommunicationBackground()
        return instance
    }()
    
    var username = ""
    var password = ""
    var userAgent: String?
    var capabilitiesGroup: String?
    @objc public var delegate: NCCommunicationBackgroundDelegate?
    
    @objc public lazy var sessionManagerExtension: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: NCCommunicationCommon.sharedInstance.session_extension)
        configuration.allowsCellularAccess = true
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        configuration.sharedContainerIdentifier = capabilitiesGroup
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        session.sessionDescription = NCCommunicationCommon.sharedInstance.session_extension
        return session
    }()
    
    @objc public func upload(serverUrlFileName: String, fileNamePathSource: String, session: URLSession?) -> URLSessionUploadTask? {
        
        guard let url = NCCommunicationCommon.sharedInstance.encodeUrlString(serverUrlFileName) as? URL else {
            return nil
        }
        var request = URLRequest(url: url)
        let loginString = "\(username):\(password)"
        guard let loginData = loginString.data(using: String.Encoding.utf8) else {
            return nil
        }
        let base64LoginString = loginData.base64EncodedString()
        
        request.httpMethod = "PUT"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")

        // session
        var session = session
        if session == nil { session = sessionManagerExtension}
        let task = session!.uploadTask(with: request, fromFile: URL.init(fileURLWithPath: fileNamePathSource))
        
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
            self.delegate?.downloadProgress?(progress, fileName: fileName, ServerUrl: serverUrl, session: session, task: downloadTask)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) { }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        guard totalBytesExpectedToSend != NSURLSessionTransferSizeUnknown else { return }
        guard let url = task.currentRequest?.url?.absoluteString.removingPercentEncoding else { return }
        let fileName = (url as NSString).lastPathComponent
        let serverUrl = url.replacingOccurrences(of: "/"+fileName, with: "")
        let progress = Double(Double(totalBytesSent)/Double(totalBytesExpectedToSend))

        DispatchQueue.main.async {
            self.delegate?.uploadProgress?(progress, fileName: fileName, ServerUrl: serverUrl, session: session, task: task)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        var fileName: String = "", serverUrl: String = ""
        let url = task.currentRequest?.url?.absoluteString.removingPercentEncoding
        if url != nil {
            fileName = (url! as NSString).lastPathComponent
            serverUrl = url!.replacingOccurrences(of: "/"+fileName, with: "")
        }
        
        DispatchQueue.main.async {
            if task is URLSessionUploadTask {
                self.delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, session: session, task: task, error: error)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
                
        if delegate == nil {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        } else {
            delegate?.authenticationChallenge?(challenge, completionHandler: { (authChallengeDisposition, credential) in
                completionHandler(authChallengeDisposition, credential)
            })
        }
    }
    
}
