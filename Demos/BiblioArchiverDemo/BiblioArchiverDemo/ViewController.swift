//
//  ViewController.swift
//  BiblioArchiverDemo
//
//  Created by huangluyang on 16/5/19.
//  Copyright © 2016年 huangluyang. All rights reserved.
//

import UIKit
import BiblioArchiver

struct FileHelper {
    static var webarchiveDirectory: String {
        get {
            let docPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).last!
            let webarchiveDirectory = "\(docPath)/webarchives/"
            let fileManager = NSFileManager.defaultManager()
            if !fileManager.fileExistsAtPath(webarchiveDirectory) {
                do {
                    try fileManager.createDirectoryAtPath(webarchiveDirectory, withIntermediateDirectories: true, attributes: nil)
                }
                catch { error
                    print("create webarchive directory failed : \(error)")
                }
            }
            return webarchiveDirectory
        }
    }

    static let testWebarchiveFile = "onevcat.webarchive"
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let url = NSURL(string: "https://onevcat.com/2016/01/create-framework/")!
        Archiver.logEnabled = true
        Archiver.archiveWebpageFormUrl(url) { (webarchiveData, error) in
            guard let data = webarchiveData else {
                print("no data, error : \(error)")
                return
            }
            
            let webarchiveDirectory = FileHelper.webarchiveDirectory
            let webarchivePath = "\(webarchiveDirectory)/\(FileHelper.testWebarchiveFile)"
            if data.writeToFile(webarchivePath, atomically: true) {
                dispatch_async(dispatch_get_main_queue(), { 
                    self.performSegueWithIdentifier("showWeb", sender: webarchivePath)
                })
            }
            else {
                print("failed to write file to disk")
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let vc = segue.destinationViewController as? WebViewController {
            vc.webarchivePath = sender as? String
        }
    }
}

