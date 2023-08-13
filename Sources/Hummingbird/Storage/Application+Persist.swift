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
/*
  extension HBApplication {
      /// Framework for storing persistent key/value pairs between mulitple requests
      public struct Persist {
          /// Initialise Persist struct
          /// - Parameters
          ///   - factory: Persist driver factory
          ///   - application: reference to application that can be used during persist driver creation
          public init(_ factory: HBPersistDriverFactory, application: HBApplication) {
              self.driver = factory.create(application)
          }

          // persist framework driver
          public let driver: HBPersistDriver
      }

      /// Accessor for persist framework
      public var persist: Persist {
          self.extensions.get(
              \.persist,
              error: "You need to setup the persistent memory driver with `HBApplication.addPersist` before using it."
          )
      }

      /// Add persist framework to `HBApplication`.
      /// - Parameter using: Factory struct that will create the persist driver when required
      public func addPersist(using: HBPersistDriverFactory) {
          self.extensions.set(\.persist, value: .init(using, application: self)) { persist in
              persist.driver.shutdown()
          }
      }
  }

  extension HBRequest {
      public struct Persist {
          /// Set value for key that will expire after a certain time.
          ///
          /// Doesn't check to see if key already exists. Some drivers may fail it key already exists
          /// - Parameters:
          ///   - key: key string
          ///   - value: value
          ///   - expires: time key/value pair will expire
          /// - Returns: EventLoopFuture for when value has been set
          public func create<Object: Codable>(key: String, value: Object, expires: TimeAmount? = nil) -> EventLoopFuture<Void> {
              return self.request.application.persist.driver.create(key: key, value: value, expires: expires, request: self.request)
          }

          /// Set value for key that will expire after a certain time
          /// - Parameters:
          ///   - key: key string
          ///   - value: value
          ///   - expires: time key/value pair will expire
          /// - Returns: EventLoopFuture for when value has been set
          public func set<Object: Codable>(key: String, value: Object, expires: TimeAmount? = nil) -> EventLoopFuture<Void> {
              return self.request.application.persist.driver.set(key: key, value: value, expires: expires, request: self.request)
          }

          /// Get value for key
          /// - Parameters:
          ///   - key: key string
          ///   - type: Type of value
          /// - Returns: EventLoopFuture that will be filled with value
          public func get<Object: Codable>(key: String, as type: Object.Type) -> EventLoopFuture<Object?> {
              return self.request.application.persist.driver.get(key: key, as: type, request: self.request)
          }

          /// Remove value for key
          /// - Parameter key: key string
          public func remove(key: String) -> EventLoopFuture<Void> {
              return self.request.application.persist.driver.remove(key: key, request: self.request)
          }

          let request: HBRequest
      }

      /// Accessor for persist framework
      public var persist: HBRequest.Persist { .init(request: self) }
  }

 /// Factory class for persist drivers
 public struct HBPersistDriverFactory {
     public let create: (HBApplication) -> HBPersistDriver

     /// Initialize HBPersistDriverFactory
     /// - Parameter create: HBPersistDriver factory function
     public init(create: @escaping (HBApplication) -> HBPersistDriver) {
         self.create = create
     }

     /// In memory driver for persist system
     public static var memory: HBPersistDriverFactory {
         .init(create: { app in HBMemoryPersistDriver(eventLoopGroup: app.eventLoopGroup) })
     }
 }

  */
