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
            let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!
            let webarchiveDirectory = "\(docPath)/webarchives/"
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: webarchiveDirectory) {
                do {
                    try fileManager.createDirectory(atPath: webarchiveDirectory, withIntermediateDirectories: true, attributes: nil)
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
        
        let url = URL(string: "https://onevcat.com/2016/01/create-framework/")!
        Archiver.logEnabled = true
        Archiver.archiveWebpageFormUrl(url) { (webarchiveData, metaData, error) in
            guard let data = webarchiveData as? NSData else {
                print("no data, error : \(error)")
                return
            }
            
            let webarchiveDirectory = FileHelper.webarchiveDirectory
            let webarchivePath = "\(webarchiveDirectory)/\(FileHelper.testWebarchiveFile)"
            if data.write(toFile: webarchivePath, atomically: true) {
                DispatchQueue.main.async(execute: {
                    self.performSegue(withIdentifier: "showWeb", sender: webarchivePath)
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? WebViewController {
            vc.webarchivePath = sender as? String
        }
    }
}

