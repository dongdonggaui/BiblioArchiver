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
public typealias ArchiveCompletionHandler = (_ webarchiveData: Data?, _ metaData: [String: String?]?, _ error: ArchiveErrorType?) -> ()

/// Fetch resource paths completion handler block
public typealias FetchResourcePathCompletionHandler = (_ data: Data?, _ metaData: [String: String?]?, _ resources: [String]?, _ error: ArchiveErrorType?) -> ()

/// Error type
public enum ArchiveErrorType: Error {
    case urlInvalid
    case fetchHTMLError
    case htmlInvalid
    case failToInitHTMLDocument
    case fetchResourceFailed
    case plistSerializeFailed
}

/// Meta data key 'title'
public let ArchivedWebpageMetaKeyTitle = "title"

/// Resource fetch options
public struct ResourceFetchOptions: OptionSet {
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
    public static func archiveWebpageFormUrl(_ url: URL, completionHandler: @escaping ArchiveCompletionHandler) {

        self.resourcePathsFromUrl(url, fetchOptions: defaultFetchOptions) { (data, metaData, resources, error) in
            guard let resources = resources else {
                printLog("resource fetch error : \(error?.localizedDescription ?? "")")
                completionHandler(nil, nil, .fetchResourceFailed)
                return
            }
            
            let resourceInfo = NSMutableDictionary(capacity: resources.count)

            let assembleQueue = DispatchQueue(label: kResourceAssembleQueue, attributes: [])
            let downloadGroup = DispatchGroup()
            let defaultGlobalQueue = DispatchQueue.global(qos: .default)

            for path in resources {
                guard let resourceUrl = URL(string: path) else {
                    continue
                }
                defaultGlobalQueue.async(group: downloadGroup, execute: {
                    let semapore = DispatchSemaphore(value: 0)
                    let task = URLSession.shared.dataTask(with: resourceUrl, completionHandler: { (data, response, error) in

                        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                            printLog("url : <\(path)> failed")
                            semapore.signal()
                            return
                        }

                        let resource = NSMutableDictionary(capacity: 3)
                        resource[kWebResourceUrl] = path
                        if let mimeType = response.mimeType {
                            resource[kWebResourceMIMEType] = mimeType
                        }
                        if let data = data {
                            resource[kWebResourceData] = data
                        }

                        assembleQueue.sync(execute: {
                            resourceInfo[path] = resource
                        })

                        printLog("url : <\(path)> downloaded")
                        semapore.signal()
                    })
                    task.resume()
                    let _ = semapore.wait(timeout: DispatchTime.distantFuture)
                    printLog("dispatch task : <\(path)> completed")
                })
            }

            downloadGroup.notify(queue: assembleQueue, execute: {
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
                    let webarchiveData = try PropertyListSerialization.data(fromPropertyList: webarchive, format: .binary, options: 0)
                    completionHandler(webarchiveData, metaData, nil)
                } catch let error {
                    printLog("plist serialize error : \(error)")
                    completionHandler(nil, metaData, .plistSerializeFailed)
                }
            })
        }
    }

    /**
     Log all resources within html from url

     - parameter url: Destination url
     */
    public static func logHTMLResources(fromUrl url: URL) {

        self.resourcePathsFromUrl(url, fetchOptions: [.FetchImage, .FetchJs, .FetchCss]) { (data, metaData, resources, error) in
            guard let resources = resources else {
                printLog("resource fetch error : \(error?.localizedDescription ?? "")")
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
    public static func resourcePathsFromUrl(_ url: URL, fetchOptions: ResourceFetchOptions, completionHandler: @escaping FetchResourcePathCompletionHandler) {
        guard let scheme = url.scheme else {
            printLog("url invalid!")
            completionHandler(nil, nil, nil, ArchiveErrorType.urlInvalid)
            return
        }

        let session = URLSession.shared
        let task = session.dataTask(with: url, completionHandler: { (data, response, error) in

            guard let htmlData = data else {
                printLog("fetch html error : \(error?.localizedDescription ?? "")")
                completionHandler(data, nil, nil, ArchiveErrorType.fetchHTMLError)
                return
            }

            guard let html = String(data: htmlData, encoding: .utf8) else {
                printLog("html invalid")
                completionHandler(data, nil, nil, ArchiveErrorType.htmlInvalid)
                return
            }

            guard let doc = try? HTMLDocument(string: html, encoding: String.Encoding.utf8) else {
                printLog("init html doc error, html : \(html)")
                completionHandler(data, nil, nil, ArchiveErrorType.failToInitHTMLDocument)
                return
            }

            printLog("html --> \(html)")
            
            var metaData = [String: String?]()
            if let htmlTitle = doc.title {
                metaData[ArchivedWebpageMetaKeyTitle] = htmlTitle
            }

            var resources: [String] = []

            let resoucePathFilter: (_ base: String?) -> String? = { base in
                guard let base = base else {
                    return nil
                }
                if base.hasPrefix("http") {
                    return base
                } else if base.hasPrefix("//") {
                    return "https:\(base)"
                } else if base.hasPrefix("/"), let host = url.host {
                    return "\(scheme)://\(host)\(base)"
                }
                return nil
            }

            // images
            if fetchOptions.contains(.FetchImage) {
                let imagePaths = doc.xpath("//img[@src]").compactMap({ (node: XMLElement) -> String? in

                    return resoucePathFilter(node["src"])
                })
                resources += imagePaths
            }

            // js
            if fetchOptions.contains(.FetchJs) {
                let jsPaths = doc.xpath("//script[@src]").compactMap({ node in

                    return resoucePathFilter(node["src"])
                })
                resources += jsPaths
            }

            // css
            if fetchOptions.contains(.FetchCss) {
                let cssPaths = doc.xpath("//link[@rel='stylesheet'][@href]").compactMap({ node in

                    return resoucePathFilter(node["href"])
                })
                resources += cssPaths
            }

            completionHandler(data, metaData, resources, nil)
        }) 
        task.resume()
    }
}

extension Archiver {
    static func printLog<T>(_ message: T, file: String = #file, method: String = #function, line: Int = #line) {
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
    public func ba_description(_ depth: Int) -> String {
        let tabs = String.ba_tabsWithCount(depth)
        var description = "{\n"
        let contentTabs = depth == 0 ? "  " : "\(tabs)\(tabs)"
        self.enumerateKeysAndObjects({ (key, obj, stop) in
            var subdescription = obj
            if let obj = obj as? NSDictionary {
                subdescription = obj.ba_description(depth + 1)
            }
            if let obj = obj as? NSArray {
                subdescription = obj.ba_description(depth + 1)
            }
            if (obj as AnyObject).isKind(of: NSData.self) {
                subdescription = "NSData"
            }
            description += "\(contentTabs)\(key): \(subdescription),\n"
        })
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
    public func ba_description(_ depth: Int) -> String {
        let tabs = String.ba_tabsWithCount(depth)
        var description = "[\n"
        let contentTabs = depth == 0 ? "  " : "\(tabs)\(tabs)"
        self.enumerateObjects({ (obj, idx, stop) in
            var subdescription = obj
            if let obj = obj as? NSDictionary {
                subdescription = obj.ba_description(depth + 1)
            }
            if let obj = obj as? NSArray {
                subdescription = obj.ba_description(depth + 1)
            }
            if (obj as AnyObject).isKind(of: NSData.self) {
                subdescription = "NSData"
            }
            description += "\(contentTabs)\(subdescription),\n"
        })
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
    public static func ba_tabsWithCount(_ count: Int) -> String {
        var tabs = ""
        var index = count
        while index > 0 {
            tabs += "  "
            index -= 1
        }
        return tabs
    }
}
