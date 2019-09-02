//
//  BiblioArchiverTests.swift
//  BiblioArchiverTests
//
//  Created by huangluyang on 16/5/19.
//  Copyright © 2016年 huangluyang. All rights reserved.
//

import XCTest
import Mockingjay
@testable import BiblioArchiver

class BiblioArchiverTests: XCTestCase {
    
    let url = URL(string: "https://100.com/test.html")!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let path = Bundle(for: type(of: self)).path(forResource: "test", ofType: "html")!
        let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        stub(http(.get, uri: "https://100.com/test.html"), builder: http(200, headers: nil, data: data))
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testHTMLParse() {
        let exceptation = expectation(description: "Wait for downloading html")
        
        Archiver.resourcePathsFromUrl(URL(string: "https://100.com/test.html")!, fetchOptions: [.FetchImage, .FetchCss, .FetchJs]) { (data, metaData, resources, error) in
            
            guard let resources = resources else {
                XCTAssert(false, "Resources parse result should not be nil")
                return
            }
            let shouldBe = [
                "https://1.com/1/1.js",
                "http://2.com/2/2.js",
                "https://100.com/3/3.js",
                "https://100.com/1/1.css",
                "https://2.com/2/2.css",
                "http://3.com/3/3.css",
                "https://100.com/assets/images/avatar.jpg",
                "http://2.com/assets/images/avatar.jpg",
                "https://1.com/assets/images/avatar.jpg",
            ]
            XCTAssert(shouldBe.count == resources.count, "Result should be specific count")
            var count = 0
            for path in shouldBe {
                if resources.contains(path) {
                    count += 1
                }
            }
            XCTAssert(count == shouldBe.count, "Result should be intact")
            exceptation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testMetaDataTitle() {
        let expectation = self.expectation(description: "wait for downloading html")
        
        Archiver.resourcePathsFromUrl(url, fetchOptions: Archiver.defaultFetchOptions) { (data, metaData, resources, error) in
            let title = "This is a test"
            XCTAssert(metaData![ArchivedWebpageMetaKeyTitle]! == title, "Message should be fetched correctly")
            
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
}
