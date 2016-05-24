//
//  BiblioArchiver.swift
//  BiblioArchiver
//
//  Created by huangluyang on 16/5/19.
//  Copyright © 2016年 huangluyang. All rights reserved.
//

import Foundation
import Fuzi

/// Archive completion handler block
public typealias ArchiveCompletionHandler = (webarchiveData: NSData?, error: ArchiveErrorType?) -> ()

/// Fetch resource paths completion handler block
public typealias FetchResourcePathCompletionHandler = (data: NSData?, resources: [String]?, error: ArchiveErrorType?) -> ()

/// Error type
public enum ArchiveErrorType: ErrorType {
    case FetchHTMLError
    case HTMLInvalid
    case FailToInitHTMLDocument
    case FetchResourceFailed
    case PlistSerializeFailed
}

/// Resource fetch options
public struct ResourceFetchOptions: OptionSetType {
    /// rawValue
    public var rawValue: UInt

    /**
     Init options with a raw value

     - parameter rawValue: Options raw value

     - returns: a options
     */
    public init(rawValue: UInt) {
       self.rawValue = rawValue
    }

    /// Fetch image
    public static var FetchImage = ResourceFetchOptions(rawValue: 1 << 1)
    /// Fetch js
    public static var FetchJs = ResourceFetchOptions(rawValue: 1 << 2)
    /// Fetch css
    public static var FetchCss = ResourceFetchOptions(rawValue: 1 << 3)
}

private let kResourceAssembleQueue = "com.lkq.ResourceAssembleQueue"

private let kWebResourceUrl = "WebResourceURL"
private let kWebResourceMIMEType = "WebResourceMIMEType"
private let kWebResourceData = "WebResourceData"
private let kWebResourceTextEncodingName = "WebResourceTextEncodingName"
private let kWebSubresources = "WebSubresources"
private let kWebResourceFrameName = "WebResourceFrameName"
private let kWebMainResource = "WebMainResource"

/// Archiver
public class Archiver {
    static let defaultFetchOptions: ResourceFetchOptions = [.FetchImage, .FetchJs, .FetchCss]

    /// flag for whether log or not
    public static var logEnabled = false

    /**
     Archive web page from url

     - parameter url: The destination url
     - parameter completionHandler: Called when the web page archived
     */
    public static func archiveWebpageFormUrl(url: NSURL, completionHandler: ArchiveCompletionHandler) {

        self.resourcePathsFromUrl(url, fetchOptions: defaultFetchOptions) { (data, resources, error) in
            guard let resources = resources else {
                printLog("resource fetch error : \(error)")
                completionHandler(webarchiveData: nil, error: .FetchResourceFailed)
                return
            }

            let resourceInfo = NSMutableDictionary(capacity: resources.count)

            let assembleQueue = dispatch_queue_create(kResourceAssembleQueue, nil)
            let downloadGroup = dispatch_group_create()
            let defaultGlobalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

            for path in resources {
                guard let resourceUrl = NSURL(string: path) else {
                    continue
                }
                dispatch_group_async(downloadGroup, defaultGlobalQueue, {
                    let semapore = dispatch_semaphore_create(0)
                    let task = NSURLSession.sharedSession().dataTaskWithURL(resourceUrl, completionHandler: { (data, response, error) in

                        guard let response = response as? NSHTTPURLResponse where response.statusCode == 200 else {
                            printLog("url : <\(path)> failed")
                            dispatch_semaphore_signal(semapore)
                            return
                        }

                        let resource = NSMutableDictionary(capacity: 3)
                        resource[kWebResourceUrl] = path
                        if let mimeType = response.MIMEType {
                            resource[kWebResourceMIMEType] = mimeType
                        }
                        if let data = data {
                            resource[kWebResourceData] = data
                        }

                        dispatch_sync(assembleQueue, {
                            resourceInfo[path] = resource
                        })

                        printLog("url : <\(path)> downloaded")
                        dispatch_semaphore_signal(semapore)
                    })
                    task.resume()
                    dispatch_semaphore_wait(semapore, DISPATCH_TIME_FOREVER)
                    printLog("dispatch task : <\(path)> completed")
                })
            }

            dispatch_group_notify(downloadGroup, assembleQueue, {
                let webSubresources = resourceInfo.allValues

                let mainResource = NSMutableDictionary(capacity: 5)
                if let data = data {
                    mainResource[kWebResourceData] = data
                }
                mainResource[kWebResourceFrameName] = ""
                mainResource[kWebResourceMIMEType] = "text/html"
                mainResource[kWebResourceTextEncodingName] = "UTF-8"
                mainResource[kWebResourceUrl] = url.absoluteString

                let webarchive = NSMutableDictionary(capacity: 2)
                webarchive[kWebSubresources] = webSubresources
                webarchive[kWebMainResource] = mainResource

                printLog("webarchive : \(webarchive.ba_description())")

                do {
                    let webarchiveData = try NSPropertyListSerialization.dataWithPropertyList(webarchive, format: .BinaryFormat_v1_0, options: 0)
                    completionHandler(webarchiveData: webarchiveData, error: nil)
                } catch { error
                    printLog("plist serialize error : \(error)")
                    completionHandler(webarchiveData: nil, error: .PlistSerializeFailed)
                }
            })
        }
    }

    /**
     Log all resources within html from url

     - parameter url: Destination url
     */
    public static func logHTMLResources(fromUrl url: NSURL) {

        self.resourcePathsFromUrl(url, fetchOptions: [.FetchImage, .FetchJs, .FetchCss]) { (data, resources, error) in
            guard let resources = resources else {
                printLog("resource fetch error : \(error)")
                return
            }

            printLog("resource -> \(resources)")
        }
    }

    /**
     Fetch resource paths within web page from the specific url

     - parameter url:               Destination url
     - parameter fetchOptions:      Fetch options
     - parameter completionHandler: Called when resources fetch finished
     */
    public static func resourcePathsFromUrl(url: NSURL, fetchOptions: ResourceFetchOptions, completionHandler: FetchResourcePathCompletionHandler) {

        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithURL(url) { (data, response, error) in

            guard let htmlData = data else {
                printLog("fetch html error : \(error)")
                completionHandler(data: data, resources: nil, error: ArchiveErrorType.FetchHTMLError)
                return
            }

            guard let html = (NSString(data: htmlData, encoding: NSUTF8StringEncoding) as? String) else {
                printLog("html invalid")
                completionHandler(data: data, resources: nil, error: ArchiveErrorType.HTMLInvalid)
                return
            }

            guard let doc = try? HTMLDocument(string: html, encoding: NSUTF8StringEncoding) else {
                printLog("init html doc error, html : \(html)")
                completionHandler(data: data, resources: nil, error: ArchiveErrorType.FailToInitHTMLDocument)
                return
            }

            printLog("html --> \(html)")

            var resources: [String] = []

            let resoucePathFilter: (base: String?) -> String? = { base in
                guard let base = base else {
                    return nil
                }
                if base.hasPrefix("http") {
                    return base
                } else if base.hasPrefix("//") {
                    return "https:\(base)"
                } else if base.hasPrefix("/"), let host = url.host {
                    return "\(url.scheme)://\(host)\(base)"
                }
                return nil
            }

            // images
            if fetchOptions.contains(.FetchImage) {
                let imagePaths = doc.xpath("//img[@src]").flatMap({ (node: XMLElement) -> String? in

                    return resoucePathFilter(base: node["src"])
                })
                resources += imagePaths
            }

            // js
            if fetchOptions.contains(.FetchJs) {
                let jsPaths = doc.xpath("//script[@src]").flatMap({ node in

                    return resoucePathFilter(base: node["src"])
                })
                resources += jsPaths
            }

            // css
            if fetchOptions.contains(.FetchCss) {
                let cssPaths = doc.xpath("//link[@rel='stylesheet'][@href]").flatMap({ node in

                    return resoucePathFilter(base: node["href"])
                })
                resources += cssPaths
            }

            completionHandler(data: data, resources: resources, error: nil)
        }
        task.resume()
    }
}

extension Archiver {
    static func printLog<T>(message: T, file: String = #file, method: String = #function, line: Int = #line) {
        if self.logEnabled {
            print("\((file as NSString).lastPathComponent)[\(line)], \(method): \(message)")
        }
    }
}

extension NSDictionary {

    /**
     Custom friendly log format

     - returns: Formatted output
     */
    public func ba_description() -> String {
        return self.ba_description(0)
    }

    /**
     Custom friendly log format

     - parameter depth: Number of beginning whitespaces

     - returns: Formatted output
     */
    public func ba_description(depth: Int) -> String {
        let tabs = String.ba_tabsWithCount(depth)
        var description = "{\n"
        let contentTabs = depth == 0 ? "  " : "\(tabs)\(tabs)"
        self.enumerateKeysAndObjectsUsingBlock { (key, obj, stop) in
            var subdescription = obj
            if let obj = obj as? NSDictionary {
                subdescription = obj.ba_description(depth + 1)
            }
            if let obj = obj as? NSArray {
                subdescription = obj.ba_description(depth + 1)
            }
            if obj.isKindOfClass(NSData.self) {
                subdescription = "NSData"
            }
            description += "\(contentTabs)\(key): \(subdescription),\n"
        }
        description += "\(tabs)}"
        return description
    }
}

extension NSArray {

    /**
     Custom friendly log format

     - returns: Formatted output
     */
    public func ba_description() -> String {
        return self.ba_description(0)
    }

    /**
     Custom friendly log format

     - parameter depth: Number of beginning whitespaces

     - returns: Formatted output
     */
    public func ba_description(depth: Int) -> String {
        let tabs = String.ba_tabsWithCount(depth)
        var description = "[\n"
        let contentTabs = depth == 0 ? "  " : "\(tabs)\(tabs)"
        self.enumerateObjectsUsingBlock { (obj, idx, stop) in
            var subdescription = obj
            if let obj = obj as? NSDictionary {
                subdescription = obj.ba_description(depth + 1)
            }
            if let obj = obj as? NSArray {
                subdescription = obj.ba_description(depth + 1)
            }
            if obj.isKindOfClass(NSData.self) {
                subdescription = "NSData"
            }
            description += "\(contentTabs)\(subdescription),\n"
        }
        description += "\(tabs)]"

        return description
    }
}

extension String {
    /**
     Generate whitespaces with specific count

     - parameter count: Count of whitespace

     - returns: Whitespaces with specific count
     */
    public static func ba_tabsWithCount(count: Int) -> String {
        var tabs = ""
        var index = count
        while index > 0 {
            tabs += "  "
            index -= 1
        }
        return tabs
    }
}
