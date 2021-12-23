//
//  GoogleAuthenticator.swift
//  Runner
//
//  Created by Roei Erez on 4/11/19.
//  Copyright © 2019 The Chromium Authors. All rights reserved.
//

import Foundation
import GoogleSignIn
import Bindings;

class GoogleAuthenticator : NSObject, BackupAuthenticatorProtocol {
    private var queue : DispatchQueue = DispatchQueue(label: "com.breez.client.gdrive.oauth")
    private var inProgressOperation : SignInOperation?
    
    
    func startSignInOperation(silentOnly: Bool) -> SignInOperation {
        return queue.sync{
            if (inProgressOperation == nil) {
                inProgressOperation = SignInOperation(silentOnly: silentOnly);
                DispatchQueue.main.async{
                    self.inProgressOperation!.start();
                }
            }
            
            return inProgressOperation!;
        };
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut();
    }
    
    func getAccessToken(silentOnly: Bool) throws -> String{        
        let signInOperation = startSignInOperation(silentOnly: silentOnly);
        signInOperation.waitUntilFinished();
        queue.sync{
            inProgressOperation = nil;
        }

        if (signInOperation.error != nil) {
            throw signInOperation.error!;
        }
        return signInOperation.accessToken!;
    }
    
    func backupProviderSignIn(silent: Bool, in err: NSErrorPointer) -> String {
        do {
            return try self.getAccessToken(silentOnly: silent);
        }
        catch {
            err?.pointee = NSError(domain: "AuthError " + error.localizedDescription, code: 0, userInfo: nil);
        }
        return "";
    }
    
}

class SignInOperation : Operation {
    
    private enum State {
        case ready
        case executing
        case finished
    }
    
    private var silentOnly = false;
    private var state = State.ready;
    private var silentSignInFailed = false;
    var accessToken : String?;
    var error : Error?;
    private var configuration: GIDConfiguration = GIDConfiguration(clientID: "")
    
    init(silentOnly: Bool){
        super.init();
        self.silentOnly = silentOnly;        
    }

    override var isAsynchronous: Bool {
        return true;
    }
    
    override var isReady : Bool {
        return state == .ready;
    }
    
    override var isExecuting: Bool {
        return state == .executing;
    }
    
    override var isFinished: Bool {
        return state == .finished;
    }
    
    override func start() {
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            if let plist = NSMutableDictionary.init(contentsOfFile: path) {
                //GIDSignIn.sharedInstance.delegate = self;
                let viewController = UIApplication.shared.keyWindow!.rootViewController!;
                self.configuration = GIDConfiguration(clientID: plist["CLIENT_ID"] as! String)
                //GIDSignIn.sharedInstance.presentingViewController = viewController;
//                GIDSignIn.sharedInstance.clientID = plist["CLIENT_ID"] as? String;
                GIDSignIn.sharedInstance.addScopes(["https://www.googleapis.com/auth/drive.appdata"], presenting: viewController);
                state = .executing;
                GIDSignIn.sharedInstance.restorePreviousSignIn()
                return;
            }
        }
        
        self.onFinish(withToken: nil, error: NSError(domain: "AuthError", code: 0, userInfo: nil));
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        
        if (error == nil || self.silentOnly || self.silentSignInFailed) {
            var accessToken : String? = nil;
            if (error == nil) {
                accessToken = user.authentication.accessToken;
            }
            self.onFinish(withToken: accessToken, error: error);
            return;
        }
        
        silentSignInFailed = true;
        GIDSignIn.sharedInstance.signIn(with: self.configuration, presenting: UIApplication.shared.keyWindow!.rootViewController!);
    }
    
    func sign(_ signIn: GIDSignIn!, present viewController: UIViewController!) {
        let rootController = UIApplication.shared.keyWindow!.rootViewController;
        rootController?.present(viewController, animated: true, completion: nil);
    }
    
    func sign(_ signIn: GIDSignIn!, dismiss viewController: UIViewController!) {
        viewController.dismiss(animated: true, completion: nil);
    }
    
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {

    }
    
    func onFinish(withToken : String?, error: Error?){
        self.error = error;
        self.accessToken = withToken;
        self.willChangeValue(forKey: "isFinished");
        self.state = .finished;
        self.didChangeValue(forKey: "isFinished");
    }
}
