//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

// Below is a list of unavailable symbols with the "HB" prefix. These are available
// temporarily to ease transition from the old symbols that included the "HB"
// prefix to the new ones.
//
// This file will be removed before we do a 2.0 release

@_documentation(visibility: internal) @available(*, unavailable, renamed: "Application")
public typealias HBApplication = Application
@_documentation(visibility: internal) @available(*, unavailable, renamed: "ApplicationConfiguration")
public typealias HBApplicationConfiguration = ApplicationConfiguration
@_documentation(visibility: internal) @available(*, unavailable, renamed: "ApplicationProtocol")
public typealias HBApplicationProtocol = ApplicationProtocol
@_documentation(visibility: internal) @available(*, unavailable, renamed: "Environment")
public typealias HBEnvironment = Environment
@_documentation(visibility: internal) @available(*, unavailable, renamed: "FileIO")
public typealias HBFileIO = FileIO

@_documentation(visibility: internal) @available(*, unavailable, renamed: "RequestContext")
public typealias HBBaseRequestContext = RequestContext
@_documentation(visibility: internal) @available(*, unavailable, renamed: "BasicRequestContext")
public typealias HBBasicRequestContext = BasicRequestContext
@_documentation(visibility: internal) @available(*, unavailable, renamed: "CoreRequestContextStorage")
public typealias HBCoreRequestContext = CoreRequestContextStorage
@_documentation(visibility: internal) @available(*, unavailable, renamed: "CoreRequestContextStorage")
public typealias CoreRequestContext = CoreRequestContextStorage
@_documentation(visibility: internal) @available(*, unavailable, renamed: "RequestContext")
public typealias HBRequestContext = RequestContext
@_documentation(visibility: internal) @available(*, unavailable, renamed: "RequestDecoder")
public typealias HBRequestDecoder = RequestDecoder
@_documentation(visibility: internal) @available(*, unavailable, renamed: "ResponseCodable")
public typealias HBResponseCodable = ResponseCodable
@_documentation(visibility: internal) @available(*, unavailable, renamed: "ResponseEncodable")
public typealias HBResponseEncodable = ResponseEncodable
@_documentation(visibility: internal) @available(*, unavailable, renamed: "ResponseEncoder")
public typealias HBResponseEncoder = ResponseEncoder
@_documentation(visibility: internal) @available(*, unavailable, renamed: "ResponseGenerator")
public typealias HBResponseGenerator = ResponseGenerator
@_documentation(visibility: internal) @available(*, unavailable, renamed: "Router")
public typealias HBRouter = Router
@_documentation(visibility: internal) @available(*, unavailable, renamed: "RouterGroup")
public typealias HBRouterGroup = RouterGroup
@_documentation(visibility: internal) @available(*, unavailable, renamed: "RouterMethods")
public typealias HBRouterMethods = RouterMethods
@_documentation(visibility: internal) @available(*, unavailable, renamed: "RouterOptions")
public typealias HBRouterOptions = RouterOptions
@_documentation(visibility: internal) @available(*, unavailable, renamed: "RouterPath")
public typealias HBRouterPath = RouterPath

@_documentation(visibility: internal) @available(*, unavailable, renamed: "CORSMiddleware")
public typealias HBCORSMiddleware = CORSMiddleware
@_documentation(visibility: internal) @available(*, unavailable, renamed: "FileMiddleware")
public typealias HBFileMiddleware = FileMiddleware
@_documentation(visibility: internal) @available(*, unavailable, renamed: "LogRequestsMiddleware")
public typealias HBLogRequestsMiddleware = LogRequestsMiddleware
@_documentation(visibility: internal) @available(*, unavailable, renamed: "MetricsMiddleware")
public typealias HBMetricsMiddleware = MetricsMiddleware
@_documentation(visibility: internal) @available(*, unavailable, renamed: "MiddlewareGroup")
public typealias HBMiddlewareGroup = MiddlewareGroup
@_documentation(visibility: internal) @available(*, unavailable, renamed: "TracingMiddleware")
public typealias HBTracingMiddleware = TracingMiddleware
@_documentation(visibility: internal) @available(*, unavailable, renamed: "RouterMiddleware")
public typealias HBMiddlewareProtocol = RouterMiddleware

@_documentation(visibility: internal) @available(*, unavailable, renamed: "CacheControl")
public typealias HBCacheControl = CacheControl
@_documentation(visibility: internal) @available(*, unavailable, renamed: "Cookie")
public typealias HBCookie = Cookie
@_documentation(visibility: internal) @available(*, unavailable, renamed: "Cookies")
public typealias HBCookies = Cookies
@_documentation(visibility: internal) @available(*, unavailable, renamed: "MediaType")
public typealias HBMediaType = MediaType

@_documentation(visibility: internal) @available(*, unavailable, renamed: "HTTPResponder")
public typealias HBResponder = HTTPResponder
@_documentation(visibility: internal) @available(*, unavailable, renamed: "HTTPResponderBuilder")
public typealias HBResponderBuilder = HTTPResponderBuilder
@_documentation(visibility: internal) @available(*, unavailable, renamed: "CallbackResponder")
public typealias HBCallbackResponder = CallbackResponder
@_documentation(visibility: internal) @available(*, unavailable, renamed: "EditedResponse")
public typealias HBEditedResponse = EditedResponse

@_documentation(visibility: internal) @available(*, unavailable, renamed: "MemoryPersistDriver")
public typealias HBMemoryPersistDriver = MemoryPersistDriver
@_documentation(visibility: internal) @available(*, unavailable, renamed: "PersistDriver")
public typealias HBPersistDriver = PersistDriver
@_documentation(visibility: internal) @available(*, unavailable, renamed: "PersistError")
public typealias HBPersistError = PersistError

@_documentation(visibility: internal) @available(*, unavailable, renamed: "HTTPError")
public typealias HBHTTPError = HTTPError
@_documentation(visibility: internal) @available(*, unavailable, renamed: "HTTPResponseError")
public typealias HBHTTPResponseError = HTTPResponseError
