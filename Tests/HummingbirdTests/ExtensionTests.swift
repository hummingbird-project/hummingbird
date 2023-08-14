//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import Hummingbird
import XCTest
/*
 extension HBApplication {
     class ActiveTest {
         var active: Bool
         init() {
             self.active = true
         }
     }

     var ext: Int {
         get { return extensions.get(\.ext) }
         set { extensions.set(\.ext, value: newValue) }
     }

     var extWithDefault: Int {
         get { return extensions.get(\.ext) ?? 50 }
         set { extensions.set(\.ext, value: newValue) }
     }

     var optionalExt: Int? {
         get { return extensions.get(\.optionalExt) }
         set { extensions.set(\.optionalExt, value: newValue) }
     }

     var shutdownTest: ActiveTest? {
         get { return extensions.get(\.shutdownTest) }
         set {
             extensions.set(\.shutdownTest, value: newValue) { value in
                 value?.active = false
             }
         }
     }
 }

 extension HBRequest {
     var ext: Int {
         get { return extensions.get(\.ext) }
         set { extensions.set(\.ext, value: newValue) }
     }

     var extWithDefault: Int {
         get { return extensions.get(\.ext) ?? 50 }
         set { extensions.set(\.ext, value: newValue) }
     }

     var optionalExt: Int? {
         get { return extensions.get(\.optionalExt) }
         set { extensions.set(\.optionalExt, value: newValue) }
     }
 }

 class ExtensionTests: XCTestCase {
     func testExtension() {
         let app = HBApplication()
         app.ext = 56
         XCTAssertEqual(app.ext, 56)
     }

     func testExtensionWithDefault() {
         let app = HBApplication()
         XCTAssertEqual(app.extWithDefault, 50)
         app.ext = 23
         XCTAssertEqual(app.extWithDefault, 23)
     }

     func testOptionalExtension() {
         let app = HBApplication()
         app.optionalExt = 56
         XCTAssertEqual(app.optionalExt, 56)
     }

     func testExists() {
         let app = HBApplication()
         XCTAssertEqual(app.extensions.exists(\.ext), false)
         XCTAssertEqual(app.extensions.exists(\.optionalExt), false)
         app.optionalExt = 1
         app.ext = 2
         XCTAssertEqual(app.extensions.exists(\.ext), true)
         XCTAssertEqual(app.extensions.exists(\.optionalExt), true)
     }

     func testExtensionShutdown() throws {
         let app = HBApplication()
         let test = HBApplication.ActiveTest()
         app.shutdownTest = test
         try app.shutdownApplication()
         XCTAssertEqual(test.active, false)
     }
 }
 */
