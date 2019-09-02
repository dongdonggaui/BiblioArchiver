// Helpers.swift
// Copyright (c) 2015 Ce Zheng
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import libxml2

// Public Helpers

/// For printing an `XMLNode`
extension XMLNode: CustomStringConvertible, CustomDebugStringConvertible {
  /// String printed by `print` function
  public var description: String {
    return self.rawXML
  }
  
  /// String printed by `debugPrint` function
  public var debugDescription: String {
    return self.rawXML
  }
}

/// For printing an `XMLDocument`
extension XMLDocument: CustomStringConvertible, CustomDebugStringConvertible {
  /// String printed by `print` function
  public var description: String {
    return self.root?.rawXML ?? ""
  }
  
  /// String printed by `debugPrint` function
  public var debugDescription: String {
    return self.root?.rawXML ?? ""
  }
}

// Internal Helpers

internal extension String {
  subscript (nsrange: NSRange) -> String {
    let start = characters.index(startIndex, offsetBy: nsrange.location)
    let end = <#T##String.CharacterView corresponding to `start`##String.CharacterView#>.index(start, offsetBy: nsrange.length)
    return self[start..<end]
  }
}

// Just a smiling helper operator making frequent UnsafePointer -> String cast

prefix operator ^-^
internal prefix func ^-^ <T> (ptr: UnsafePointer<T>) -> String? {
  return String(cString: UnsafePointer(ptr))
}

internal prefix func ^-^ <T> (ptr: UnsafeMutablePointer<T>) -> String? {
  return String(cString: UnsafeMutablePointer(ptr))
}

internal struct LinkedCNodes: Sequence {
  typealias Iterator = AnyIterator<xmlNodePtr>
  static let end: xmlNodePtr? = nil
  internal var types: [xmlElementType]
  func makeIterator() -> Iterator {
    var node = head
    // TODO: change to AnyGenerator when swift 2.1 gets out of the way
    return AnyIterator {
      var ret = node
      while ret != nil && !self.types.contains(where: { $0 == ret.pointee.type }) {
        ret = ret.pointee.next
      }
      node = (ret != nil ?ret.pointee.next :nil)!
      return ret != nil ?ret :LinkedCNodes.end
    }
  }
  
  let head: xmlNodePtr
  init(head: xmlNodePtr, types: [xmlElementType] = [XML_ELEMENT_NODE]) {
    self.head = head
    self.types = types
  }
}

internal func cXMLNodeMatchesTagInNamespace(_ node: xmlNodePtr, tag: String, ns: String?) -> Bool {
  let name = ^-^node.pointee.name
  var matches = name?.compare(tag, options: .caseInsensitive) == .orderedSame
  
  if let ns = ns {
    let cNS = node.pointee.ns
    if cNS != nil && cNS?.pointee.prefix != nil {
      let prefix = ^-^cNS?.pointee.prefix
      matches = matches && (prefix?.compare(ns, options: .caseInsensitive) == .orderedSame)
    }
  }
  return matches
}
