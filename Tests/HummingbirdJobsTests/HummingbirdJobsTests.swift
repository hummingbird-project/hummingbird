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

import Hummingbird
@testable import HummingbirdJobs
import HummingbirdXCT
import XCTest

final class HummingbirdJobsTests: XCTestCase {
    func testBasic() throws {
        struct TestJob: HBJob {
            static let name = "testBasic"
            static let expectation = XCTestExpectation(description: "Jobs Completed")

            let value: Int
            func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
                print(self.value)
                return eventLoop.scheduleTask(in: .milliseconds(Int64.random(in: 10..<50))) {
                    Self.expectation.fulfill()
                }.futureResult
            }
        }
        TestJob.register()
        TestJob.expectation.expectedFulfillmentCount = 10

        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory, numWorkers: 1)

        try app.start()
        defer { app.stop() }

        app.jobs.queue.enqueue(TestJob(value: 1), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 2), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 3), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 4), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 5), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 6), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 7), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 8), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 9), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 0), on: app.eventLoopGroup.next())

        wait(for: [TestJob.expectation], timeout: 5)
    }

    func testMultipleWorkers() throws {
        struct TestJob: HBJob {
            static let name = "testMultipleWorkers"
            static let expectation = XCTestExpectation(description: "Jobs Completed")

            let value: Int
            func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
                print(self.value)
                return eventLoop.scheduleTask(in: .milliseconds(Int64.random(in: 10..<50))) {
                    Self.expectation.fulfill()
                }.futureResult
            }
        }
        TestJob.register()
        TestJob.expectation.expectedFulfillmentCount = 10

        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory, numWorkers: 4)

        try app.start()
        defer { app.stop() }

        app.jobs.queue.enqueue(TestJob(value: 1), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 2), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 3), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 4), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 5), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 6), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 7), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 8), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 9), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob(value: 0), on: app.eventLoopGroup.next())

        wait(for: [TestJob.expectation], timeout: 5)
    }

    func testErrorRetryCount() throws {
        struct FailedError: Error {}

        struct TestJob: HBJob {
            static let name = "testErrorRetryCount"
            static let maxRetryCount = 3
            static let expectation = XCTestExpectation(description: "Jobs Completed")
            func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
                Self.expectation.fulfill()
                return eventLoop.makeFailedFuture(FailedError())
            }
        }
        TestJob.register()
        TestJob.expectation.expectedFulfillmentCount = 4
        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory, numWorkers: 1)

        try app.start()
        defer { app.stop() }

        app.jobs.queue.enqueue(TestJob(), on: app.eventLoopGroup.next())

        wait(for: [TestJob.expectation], timeout: 1)
    }

    func testSecondQueue() throws {
        struct TestJob: HBJob {
            static let name = "testSecondQueue"
            static let expectation = XCTestExpectation(description: "Jobs Completed")
            func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
                Self.expectation.fulfill()
                return eventLoop.makeSucceededVoidFuture()
            }
        }
        TestJob.register()
        TestJob.expectation.expectedFulfillmentCount = 1
        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory, numWorkers: 1)
        app.jobs.registerQueue(.test, queue: .memory, numWorkers: 1)

        try app.start()
        defer { app.stop() }

        app.jobs.queues(.test).enqueue(TestJob(), on: app.eventLoopGroup.next())

        wait(for: [TestJob.expectation], timeout: 1)
    }

    func testShutdown() throws {
        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory, numWorkers: 1)
        try app.start()
        app.stop()
        app.wait()
    }

    func testShutdownJob() throws {
        struct TestJob: HBJob {
            static let name = "testShutdownJob"
            static var started: Bool = false
            static var finished: Bool = false
            func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
                Self.started = true
                let job = eventLoop.scheduleTask(in: .milliseconds(500)) {
                    Self.finished = true
                }
                return job.futureResult
            }
        }
        TestJob.register()

        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory, numWorkers: 1)
        try app.start()
        let job = TestJob()
        app.jobs.queue.enqueue(job, on: app.eventLoopGroup.next())
        // stall to give job chance to start running
        Thread.sleep(forTimeInterval: 0.1)
        app.stop()
        app.wait()

        XCTAssertTrue(TestJob.started)
        XCTAssertTrue(TestJob.finished)
    }

    func testJobSerialization() throws {
        struct TestJob: HBJob, Equatable {
            static let name = "testJobSerialization"
            let value: Int
            func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
                return eventLoop.makeSucceededVoidFuture()
            }
        }
        TestJob.register()
        let job = TestJob(value: 2)
        let queuedJob = HBJobContainer(job)
        let data = try JSONEncoder().encode(queuedJob)
        let queuedJob2 = try JSONDecoder().decode(HBJobContainer.self, from: data)
        XCTAssertEqual(queuedJob2.job as? TestJob, job)
    }

    /// test job fails to decode but queue continues to process
    func testFailToDecode() throws {
        struct TestJob1: HBJob {
            static let name = "testFailToDecode"
            func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
                return eventLoop.makeSucceededVoidFuture()
            }
        }
        struct TestJob2: HBJob {
            static let name = "testFailToDecode"
            static var value: String?
            let value: String
            func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
                Self.value = self.value
                return eventLoop.makeSucceededVoidFuture()
            }
        }
        TestJob2.register()

        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory, numWorkers: 1)

        try app.start()

        app.jobs.queue.enqueue(TestJob1(), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestJob2(value: "test"), on: app.eventLoopGroup.next())

        // stall to give job chance to start running
        Thread.sleep(forTimeInterval: 0.1)

        app.stop()
        app.wait()

        XCTAssertEqual(TestJob2.value, "test")
    }


    /// test access via `HBRequest`
    func testAccessViaRequest() throws {
        struct TestJob: HBJob {
            static let name = "testBasic"
            static let expectation = XCTestExpectation(description: "Jobs Completed")

            func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
                Self.expectation.fulfill()
                return eventLoop.makeSucceededVoidFuture()
            }
        }
        TestJob.register()
        TestJob.expectation.expectedFulfillmentCount = 1

        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory, numWorkers: 1)

        app.router.get("/job") { request -> EventLoopFuture<HTTPResponseStatus> in
            return request.jobs.enqueue(job: TestJob()).map { _ in .ok }
        }

        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/job", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
        }

        wait(for: [TestJob.expectation], timeout: 5)
    }

    #if compiler(>=5.5) && canImport(_Concurrency)

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func testAsyncJob() throws {
        struct TestAsyncJob: HBAsyncJob {
            static let name = "testAsyncJob"
            static let expectation = XCTestExpectation(description: "Jobs Completed")

            func execute(logger: Logger) async throws {
                try await Task.sleep(nanoseconds: 1_000_000)
                Self.expectation.fulfill()
            }
        }

        TestAsyncJob.register()
        TestAsyncJob.expectation.expectedFulfillmentCount = 3

        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory, numWorkers: 2)

        try app.start()
        defer { app.stop() }

        app.jobs.queue.enqueue(TestAsyncJob(), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestAsyncJob(), on: app.eventLoopGroup.next())
        app.jobs.queue.enqueue(TestAsyncJob(), on: app.eventLoopGroup.next())

        wait(for: [TestAsyncJob.expectation], timeout: 5)
    }

    #endif // compiler(>=5.5) && canImport(_Concurrency)
}

extension HBJobQueueId {
    static var test: HBJobQueueId { "test" }
}
