//
//  NSCommunicationCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/10/19.
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
import Alamofire
import CFNetwork

@objc public protocol NCCommunicationCommonDelegate {
    @objc optional func authenticationChallenge(_ challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    @objc optional func downloadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func uploadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Double, description: String?, error: Error?, statusCode: Int)
    @objc optional func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, description: String?, error: Error?, statusCode: Int)
}

class NCCommunicationCommon: NSObject {
    @objc static let sharedInstance: NCCommunicationCommon = {
        let instance = NCCommunicationCommon()
        return instance
    }()
    
    var username = ""
    var password = ""
    var userAgent: String?
    var capabilitiesGroup: String?
    
    // Protocol
    var delegate: NCCommunicationCommonDelegate?
    
    // Session
    @objc let sessionMaximumConnectionsPerHost = 5
    @objc let sessionIdentifierBackground: String = "com.nextcloud.session.background"
    @objc let sessionIdentifierBackgroundwifi: String = "com.nextcloud.session.backgroundwifi"
    @objc let sessionIdentifierExtension: String = "com.nextcloud.session.extension"

    //MARK: - Setup
    
    @objc public func setup(username: String, password: String, userAgent: String?, capabilitiesGroup: String?, delegate: NCCommunicationCommonDelegate?) {
        
        self.username = username
        self.password = password
        self.userAgent = userAgent
        self.capabilitiesGroup = capabilitiesGroup
        self.delegate = delegate
    }
    
    @objc public func setup(userAgent: String?, capabilitiesGroup: String?, delegate: NCCommunicationCommonDelegate?) {
        
        self.userAgent = userAgent
        self.capabilitiesGroup = capabilitiesGroup
        self.delegate = delegate
    }
    
    //MARK: -  Delegate session
    
    public func authenticationChallenge(_ challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if delegate == nil {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        } else {
            delegate?.authenticationChallenge?(challenge, completionHandler: { (authChallengeDisposition, credential) in
                completionHandler(authChallengeDisposition, credential)
            })
        }
    }
    
    public func downloadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.downloadProgress?(progress, fileName: fileName, ServerUrl: ServerUrl, session: session, task: task)
    }

    public func uploadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.uploadProgress?(progress, fileName: fileName, ServerUrl: ServerUrl, session: session, task: task)
    }
    
    public func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, description: String?, error: Error?, statusCode: Int) {
        delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, description: description, error: error, statusCode: statusCode)
    }
    
    public func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Double, description: String?, error: Error?, statusCode: Int) {
        delegate?.downloadComplete?(fileName: fileName, serverUrl: serverUrl, etag: etag, date: date, dateLastModified: dateLastModified, length: length, description: description, error: error, statusCode: statusCode)
    }

    //MARK: - Common
    
    func convertDate(_ dateString: String, format: String) -> NSDate? {
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.init(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = format
        if let date = dateFormatter.date(from: dateString) {
            return date as NSDate
        } else {
            return nil
        }
    }
    
    func encodeUrlString(_ string: String) -> URLConvertible? {
        
        let allowedCharacterSet = (CharacterSet(charactersIn: " ").inverted)
        if let escapedString = string.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {            
            var url: URLConvertible
            do {
                try url = escapedString.asURL()
                return url
            } catch _ {
                return nil
            }
        }
        return nil
    }
    
    func getError(code: Int, description: String) -> Error {
        
        return NSError(domain: "Nextcloud", code: code, userInfo: [NSLocalizedDescriptionKey : description])
    }
    
    func getError(error: AFError?, httResponse: HTTPURLResponse?) -> (errorCode: Int, description: String?) {
        
        if let errorCode = httResponse?.statusCode  {
            switch errorCode {
            case -999:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_internal_server_", comment: ""))
            case -1001:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_time_out_", comment: ""))
            case -1004:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_server_down_", comment: ""))
            case -1005:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_not_possible_connect_to_server_", comment: ""))
            case -1009:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_not_connected_internet_", comment: ""))
            case -1011:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_error_", comment: ""))
            case -1012:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_not_possible_connect_to_server_", comment: ""))
            case -1013:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_user_authentication_required_", comment: ""))
            case -1200:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_ssl_connection_error_", comment: ""))
            case -1202:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_ssl_certificate_untrusted_", comment: ""))
            case 101:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_forbidden_characters_from_server_", comment: ""))
            case 400:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_bad_request_", comment: ""))
            case 403:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_error_not_permission_", comment: ""))
            case 404:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_error_path_", comment: ""))
            case 423:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_webdav_locked_", comment: ""))
            case 500:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_internal_server_", comment: ""))
            case 503:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_server_error_retry_", comment: ""))
            case 507:
                return(errorCode, "\(errorCode):" + NSLocalizedString("_user_over_quota_", comment: ""))
            default:
                return(errorCode, httResponse?.description)
            }
        }
        
        if let error = error {
            switch error {
            case .createUploadableFailed(let error as NSError):
                return(error.code, error.localizedDescription)
            case .createURLRequestFailed(let error as NSError):
                return(error.code, error.localizedDescription)
            case .requestAdaptationFailed(let error as NSError):
                return(error.code, error.localizedDescription)
            case .sessionInvalidated(let error as NSError):
                return(error.code, error.localizedDescription)
            case .sessionTaskFailed(let error as NSError):
                return(error.code, error.localizedDescription)
            default:
                return(error._code, error.localizedDescription)
            }
        }
        return(0,"")
    }
 }
