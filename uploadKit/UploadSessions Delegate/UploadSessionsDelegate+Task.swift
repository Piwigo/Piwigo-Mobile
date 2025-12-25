//
//  UploadSessionsDelegate+Task.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 24/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: - Session Task Delegate
extension UploadSessionsDelegate: URLSessionTaskDelegate {
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        UploadSessionsDelegate.logger.notice("Task-level authentication requested by server.")

        // Check authentication method
        let authMethod = challenge.protectionSpace.authenticationMethod
        guard authMethod == NSURLAuthenticationMethodHTTPBasic,
              authMethod == NSURLAuthenticationMethodHTTPDigest else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Get HTTP basic authentification credentials
        let account = NetworkVars.shared.httpUsername
        let password = KeychainUtilities.password(forService: NetworkVars.shared.service, account: account)
        if password.isEmpty {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let credential = URLCredential(user: account,
                                       password: password,
                                       persistence: .forSession)
        completionHandler(.useCredential, credential)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {

        // Get upload info from the task
        guard let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID),
              let chunk = Int((task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk))!)
        else {
            UploadSessionsDelegate.logger.notice("Could not extract HTTP header fields.")
            preconditionFailure("Could not extract HTTP header fields.")
        }

        // Update counter
        Task { @UploadManagerActor in
            // Add chunk to counter if needed (e.g. situation where the app is relauched)
            UploadManager.shared.addChunk(chunk, toCounterWithID: identifier)
            
            // Update UploadQueue cell and button shown in root album (or default album)
            UploadManager.shared.addBytes(bytesSent, toCounterWithID: identifier)
            
            // Update progress bar
            let progress = UploadManager.shared.getProgress(forCounterWithID: identifier)
            DispatchQueue.main.async {
                let uploadInfo: [String : Any] = ["localIdentifier" : identifier,
                                                  "progressFraction" : progress]
                NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
            }
            
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.none
            numberFormatter.usesGroupingSeparator = true
            let bytes = numberFormatter.string(from: NSNumber(value: bytesSent)) ?? ""
            numberFormatter.numberStyle = NumberFormatter.Style.decimal
            numberFormatter.roundingMode = .ceiling
            numberFormatter.roundingIncrement = NSNumber(value: 0.01)
            let progressPercent = numberFormatter.string(from: NSNumber(value: progress * 100)) ?? ""
            UploadSessionsDelegate.logger.notice("Task \(task.taskIdentifier, privacy: .public) did send \(bytes, privacy: .public) bytes | counter: \(progressPercent, privacy: .public) %")
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        
        // Get upload info from the task
        guard let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID),
              let chunk = Int((task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk))!),
              let chunks = Int((task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunks))!),
              let taskDescription = task.taskDescription
        else {
            UploadSessionsDelegate.logger.notice("Could not extract HTTP header fields.")
            preconditionFailure("Could not extract HTTP header fields.")
        }

        // Add chunk to counter if needed (e.g. situation where the app is relauched)
        Task { @UploadManagerActor in
            UploadManager.shared.addChunk(chunk, toCounterWithID: identifier)
        }

        // The below code updates the stored cookie with the pwg_id returned by the server.
        // This allows to check that the upload session was well closed by the server.
        // For example by requesting image properties or an image deletion.
//        debugPrint("\(task.response.debugDescription)")
//        if let requestURL = task.originalRequest?.url,
//           let cookies = HTTPCookieStorage.shared.cookies(for: requestURL), cookies.count > 0,
//           var properties = cookies[0].properties {
//            let oldPwgID = cookies[0].value
//            debugPrint("oldPwgID => \(oldPwgID)")
//
//            if let response = task.response as? HTTPURLResponse,
//               let setCookie = response.allHeaderFields["Set-Cookie"] as? String {
//                let strPart2 = setCookie.components(separatedBy: "pwg_id=")
//                if strPart2.count > 1 {
//                    let newPwgID = strPart2[1].components(separatedBy: " ")[0].drop(while: {$0 == ";"})
//                    properties.updateValue(newPwgID, forKey: .value)
//                    if let cookie = HTTPCookie(properties: properties) {
//                        debugPrint("newPwgID => \(newPwgID)")
//                        HTTPCookieStorage.shared.setCookie(cookie)
//                    }
//                }
//            }
//        }

        // Manage the error type
        var pwgError: PwgKitError?
        if let error = error as? URLError {
            pwgError = .requestFailed(innerError: error)
        }
        else if let error = error as? DecodingError {
            pwgError = .decodingFailed(innerError: error)
        }
        else if let response = task.response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode) == false {
            pwgError = .invalidStatusCode(statusCode: response.statusCode)
        }
        else if let error = error {
            pwgError = .otherError(innerError: error)
        }
        
        // Log task completion
        if let pwgError, taskDescription.contains(pwgHTTPCancelled) == false {
            UploadSessionsDelegate.logger.notice("Task \(task.taskIdentifier, privacy: .public) of chunk \(chunk+1, privacy: .public)/\(chunks, privacy: .public) failed with error \(String(describing: pwgError.localizedDescription), privacy: .public).")
        } else {
            UploadSessionsDelegate.logger.notice("Task \(task.taskIdentifier, privacy: .public) of chunk \(chunk+1, privacy: .public)/\(chunks, privacy: .public) completed.")
        }
        
        // Handle the response with the Upload Manager
        let sessionIdentifier = (task.taskDescription ?? "").components(separatedBy: " ").first
        switch sessionIdentifier {
        case uploadSessionIdentifier:
            Task { @UploadManagerActor in
                UploadManager.shared.didCompleteUploadTask(task, withError: pwgError)
            }
        case uploadBckgSessionIdentifier:
            Task { @UploadManagerActor in
                UploadManager.shared.didCompleteBckgUploadTask(task, withError: pwgError)
            }
        default:
            UploadSessionsDelegate.logger.notice("Unexpected session identifier.")
            preconditionFailure("Unexpected session identifier.")
        }
    }
}
