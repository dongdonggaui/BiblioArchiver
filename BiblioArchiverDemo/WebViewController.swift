//
//  WebViewController.swift
//  BiblioArchiverDemo
//
//  Created by huangluyang on 16/5/20.
//  Copyright © 2016年 huangluyang. All rights reserved.
//

import UIKit

class WebViewController: UIViewController {

    @IBOutlet weak var webView: UIWebView!
    
    var webarchivePath: String?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let path = webarchivePath {
            let url = URL(fileURLWithPath: path)
            self.webView.loadRequest(URLRequest(url: url))
        }
        else {
            print("webarchive path : \(webarchivePath) invalid")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
