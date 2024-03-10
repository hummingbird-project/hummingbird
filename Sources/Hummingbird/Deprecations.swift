//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// Below is a list of deprecated symbols with the "HB" prefix. These are available
// temporarily to ease transition from the old symbols that included the "HB"
// prefix to the new ones.
//
// This file will be removed before we do a 2.0 release

@_documentation(visibility: internal) @available(*, deprecated, renamed: "Application")
public typealias HBApplication = Application
@_documentation(visibility: internal) @available(*, deprecated, renamed: "ApplicationConfiguration")
public typealias HBApplicationConfiguration = ApplicationConfiguration
@_documentation(visibility: internal) @available(*, deprecated, renamed: "ApplicationProtocol")
public typealias HBApplicationProtocol = ApplicationProtocol
@_documentation(visibility: internal) @available(*, deprecated, renamed: "Environment")
public typealias HBEnvironment = Environment
@_documentation(visibility: internal) @available(*, deprecated, renamed: "FileIO")
public typealias HBFileIO = FileIO

@_documentation(visibility: internal) @available(*, deprecated, renamed: "BaseRequestContext")
public typealias HBBaseRequestContext = BaseRequestContext
@_documentation(visibility: internal) @available(*, deprecated, renamed: "BasicRequestContext")
public typealias HBBasicRequestContext = BasicRequestContext
@_documentation(visibility: internal) @available(*, deprecated, renamed: "CoreRequestContext")
public typealias HBCoreRequestContext = CoreRequestContext
@_documentation(visibility: internal) @available(*, deprecated, renamed: "RequestContext")
public typealias HBRequestContext = RequestContext
@_documentation(visibility: internal) @available(*, deprecated, renamed: "RequestDecoder")
public typealias HBRequestDecoder = RequestDecoder
@_documentation(visibility: internal) @available(*, deprecated, renamed: "ResponseEncodable")
public typealias HBResponseEncodable = ResponseEncodable
@_documentation(visibility: internal) @available(*, deprecated, renamed: "ResponseEncoder")
public typealias HBResponseEncoder = ResponseEncoder
@_documentation(visibility: internal) @available(*, deprecated, renamed: "ResponseGenerator")
public typealias HBResponseGenerator = ResponseGenerator
@_documentation(visibility: internal) @available(*, deprecated, renamed: "Router")
public typealias HBRouter = Router
@_documentation(visibility: internal) @available(*, deprecated, renamed: "RouterGroup")
public typealias HBRouterGroup = RouterGroup
@_documentation(visibility: internal) @available(*, deprecated, renamed: "RouterMethods")
public typealias HBRouterMethods = RouterMethods
@_documentation(visibility: internal) @available(*, deprecated, renamed: "RouterOptions")
public typealias HBRouterOptions = RouterOptions
@_documentation(visibility: internal) @available(*, deprecated, renamed: "RouterPath")
public typealias HBRouterPath = RouterPath
@_documentation(visibility: internal) @available(*, deprecated, renamed: "RouterResponder")
public typealias HBRouterResponder = RouterResponder

@_documentation(visibility: internal) @available(*, deprecated, renamed: "CORSMiddleware")
public typealias HBCORSMiddleware = CORSMiddleware
@_documentation(visibility: internal) @available(*, deprecated, renamed: "FileMiddleware")
public typealias HBFileMiddleware = FileMiddleware
@_documentation(visibility: internal) @available(*, deprecated, renamed: "LogRequestsMiddleware")
public typealias HBLogRequestsMiddleware = LogRequestsMiddleware
@_documentation(visibility: internal) @available(*, deprecated, renamed: "MetricsMiddleware")
public typealias HBMetricsMiddleware = MetricsMiddleware
@_documentation(visibility: internal) @available(*, deprecated, renamed: "MiddlewareGroup")
public typealias HBMiddlewareGroup = MiddlewareGroup
@_documentation(visibility: internal) @available(*, deprecated, renamed: "TracingMiddleware")
public typealias HBTracingMiddleware = TracingMiddleware
@_documentation(visibility: internal) @available(*, deprecated, renamed: "RouterMiddleware")
public typealias HBMiddlewareProtocol = RouterMiddleware

@_documentation(visibility: internal) @available(*, deprecated, renamed: "CacheControl")
public typealias HBCacheControl = CacheControl
@_documentation(visibility: internal) @available(*, deprecated, renamed: "Cookie")
public typealias HBCookie = Cookie
@_documentation(visibility: internal) @available(*, deprecated, renamed: "Cookies")
public typealias HBCookies = Cookies
@_documentation(visibility: internal) @available(*, deprecated, renamed: "MediaType")
public typealias HBMediaType = MediaType

@_documentation(visibility: internal) @available(*, deprecated, renamed: "HTTPResponder")
public typealias HBResponder = HTTPResponder
@_documentation(visibility: internal) @available(*, deprecated, renamed: "HTTPResponderBuilder")
public typealias HBResponderBuilder = HTTPResponderBuilder
@_documentation(visibility: internal) @available(*, deprecated, renamed: "CallbackResponder")
public typealias HBCallbackResponder = CallbackResponder
@_documentation(visibility: internal) @available(*, deprecated, renamed: "EditedResponse")
public typealias HBEditedResponse = EditedResponse

@_documentation(visibility: internal) @available(*, deprecated, renamed: "MemoryPersistDriver")
public typealias HBMemoryPersistDriver = MemoryPersistDriver
@_documentation(visibility: internal) @available(*, deprecated, renamed: "PersistDriver")
public typealias HBPersistDriver = PersistDriver
@_documentation(visibility: internal) @available(*, deprecated, renamed: "PersistError")
public typealias HBPersistError = PersistError
