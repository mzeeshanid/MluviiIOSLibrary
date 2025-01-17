//
//  MluviiChatLibrary.swift
//  MluviiChat
//
//  Created by Mluvi Mac on 21.03.18.
//  Copyright © 2018 Mluvii. All rights reserved.
//

import UIKit
import WebKit

public typealias NavigationActionDelegate = (WKWebView, WKNavigationAction)->WKWebView?

public class MluviiChatLibrary :  UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    
    private var webView:WKWebView? = nil
    
    private var completeLink: String = ""
    
    private var navigationActionDelegate: NavigationActionDelegate? = nil
    
    typealias ChatEnded = () -> Void
    
    var endedFunc: ChatEnded? = nil
    
    var statusFunc: ((_ status: Int32) -> Void)? = nil
    
    var eventFunc: ((_ event: String, _ sessionId: Int64?) -> Void)? = nil
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public func setChatEnded(ended: @escaping () -> Void) {
        endedFunc = ended
    }
    
    public func setStatusUpdater(statusF: @escaping (_ status: Int32) -> Void){
        statusFunc = statusF
    }
    
    public func setMluviiEventCallbackFunc(eventF: @escaping (_ event: String, _ sessionId: Int64?) -> Void){
        eventFunc = eventF
    }
    
    public func resetUrl(){
        let url = URL(string: completeLink)!
        webView?.load(URLRequest(url:url))
        webView?.frame = CGRect(x: 0,y: 0,width: 0,height: 0)
    }
    
    public func openChat(){
        let openScript:String = "openChat()"
        webView?.evaluateJavaScript(openScript, completionHandler: nil)
        webView?.frame = self.view.frame;
        self.view.autoresizesSubviews = true;
        
    }
    
    public func openVideo() {
        let openScript:String = "$owidget.openAppOnCurrentPage('av')"
        webView?.evaluateJavaScript(openScript, completionHandler: nil)
        webView?.frame = self.view.frame;
        self.view.autoresizesSubviews = true;
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        print("Orientation Change")
        webView?.frame = CGRect(x:0, y: 0, width: size.width, height: size.height)
    }
    
    public func createLink(url:String, companyGuid:String, tenantId:String, presetName:String? = nil, language:String? = nil, scope:String? = nil) -> String {
        var link: String = "https://\(url)/MobileSdkWidget?c=\(companyGuid)&t=\(tenantId)"
        var optionalPresetName = ""
        if(presetName != nil){
            optionalPresetName = "&p=\(presetName!)"
        }
        var optionalLanguage = ""
        if(language != nil){
            optionalLanguage = "&l=\(language!)"
        }
        var optionalScope = ""
        if(scope != nil){
            optionalScope = "&s=\(scope!)"
        }
        let optionalQuery = "\(optionalPresetName)\(optionalLanguage)\(optionalScope)"
        print("optionalQuery \(optionalQuery)")
        link = "\(link)\(optionalQuery)"
        let encodedLink = link.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
        print("link: \(encodedLink!)")
        completeLink = encodedLink!
        return encodedLink!
    }
    
    public func createWebView(
        url:String,
        companyGuid:String,
        tenantId:String,
        presetName:String?,
        language:String?,
        scope:String?,
        navigationActionCustomDelegate: NavigationActionDelegate?
    ) -> WKWebView {
        if(webView == nil){
            navigationActionDelegate = navigationActionCustomDelegate
            let config = WKWebViewConfiguration()
            let pref = WKPreferences()
            pref.javaScriptEnabled = true
            pref.javaScriptCanOpenWindowsAutomatically = true
            let contentController = WKUserContentController()
            contentController.add(self, name: "mluviiLibrary")
            config.userContentController = contentController
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []
            config.preferences = pref
            completeLink = createLink(url: url, companyGuid: companyGuid, tenantId: tenantId, presetName: presetName, language: language, scope: scope)
            webView = WKWebView(frame: CGRect(x: 0,y: 0,width: 0,height: 0), configuration: config)
            webView!.navigationDelegate = self
            webView!.uiDelegate = self
            let url = URL(string: completeLink)!
            webView?.load(URLRequest(url:url))
            webView?.allowsBackForwardNavigationGestures = false
        }
        return webView!
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        let jsonObject = message.body as! [String:AnyObject]
        if(jsonObject["type"] as! String == "status"){
            let widgetState = jsonObject["value"] as! Int32
            print("Widget State: ", widgetState)
            statusFunc!(widgetState)
        }
        if(jsonObject["type"] as! String == "close"){
            print("Calling ended function")
            endedFunc!()
        }
        
        if(jsonObject["type"] as! String == "sessionEnded"){
            if let values = jsonObject["value"] as? [Any]{
                if values.count == 2 {
                    let eventName = values[0] as? String ?? ""
                    let sessionID = values[1] as? Int64 ?? nil
                    guard let eventFunc = eventFunc else{
                        return
                    }
                    eventFunc(eventName, sessionID)
                }
            }
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error:Error){
        print(error.localizedDescription)
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!){
        print("Start to load: "+navigation.debugDescription)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!){
        print("Finish to load")
        let script:String = "console.log('Setting window.close');var _close = window.close; window.close= function(){if(window['webkit'] && window['webkit'].messageHandlers.mluviiLibrary) { window['webkit'].messageHandlers.mluviiLibrary.postMessage({type:'close', value: 'true'}) } };var mluviiEventHandler = function(event,sessionId){if(window['webkit'] && window['webkit'].messageHandlers.mluviiLibrary){ window['webkit'].messageHandlers.mluviiLibrary.postMessage({type:'sessionEnded', value: [event,sessionId]}); }}; window.mluviiEventHandler = mluviiEventHandler;"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if (navigationActionDelegate != nil) {
            return navigationActionDelegate!(webView, navigationAction)
        }
        
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            if url.description.lowercased().range(of: "http://") != nil ||
                url.description.lowercased().range(of: "https://") != nil ||
                url.description.lowercased().range(of: "mailto:") != nil {
                UIApplication.shared.open(url)
            }
        }
        
        return nil
    }
    
    public func addCustomData(name:String, value:String) {
        let script = "$owidget.addCustomData('\(name)', '\(value)')"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }
}
