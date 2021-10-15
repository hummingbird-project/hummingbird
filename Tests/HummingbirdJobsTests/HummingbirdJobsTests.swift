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
            static let name = "test"
            static let expectation = XCTestExpectation(description: "Jobs Completed")

            let value: Int
            func execute(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
                print(self.value)
                return eventLoop.scheduleTask(in: .milliseconds(Int64.random(in: 10..<50))) {
                    Self.expectation.fulfill()
                }.futureResult
            }
        }
        HBJobRegister.register(job: TestJob.self)
        TestJob.expectation.expectedFulfillmentCount = 10

        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory)

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
            static let name = "test"
            static let expectation = XCTestExpectation(description: "Jobs Completed")

            let value: Int
            func execute(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
                print(self.value)
                return eventLoop.scheduleTask(in: .milliseconds(Int64.random(in: 10..<50))) {
                    Self.expectation.fulfill()
                }.futureResult
            }
        }
        HBJobRegister.register(job: TestJob.self)
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
            static let name = "test"
            static let maxRetryCount = 3
            static let expectation = XCTestExpectation(description: "Jobs Completed")
            func execute(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
                Self.expectation.fulfill()
                return eventLoop.makeFailedFuture(FailedError())
            }
        }
        TestJob.expectation.expectedFulfillmentCount = 4
        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory)

        try app.start()
        defer { app.stop() }

        app.jobs.queue.enqueue(TestJob(), on: app.eventLoopGroup.next())

        wait(for: [TestJob.expectation], timeout: 1)
    }

    func testSecondQueue() throws {
        struct TestJob: HBJob {
            static let name = "test"
            static let expectation = XCTestExpectation(description: "Jobs Completed")
            func execute(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
                Self.expectation.fulfill()
                return eventLoop.makeSucceededVoidFuture()
            }
        }
        TestJob.expectation.expectedFulfillmentCount = 1
        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory)
        app.jobs.registerQueue(.test, queue: .memory)

        try app.start()
        defer { app.stop() }

        app.jobs.queues(.test).enqueue(TestJob(), on: app.eventLoopGroup.next())

        wait(for: [TestJob.expectation], timeout: 1)
    }

    func testOnError() throws {
        struct FailedError: Error {}

        struct TestJob: HBJob {
            static let name = "test"
            static let maxRetryCount: Int = 2
            static let expectation = XCTestExpectation(description: "Jobs Completed")
            static let errorExpectation = XCTestExpectation(description: "Jobs Errored")
            func execute(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
                Self.expectation.fulfill()
                return eventLoop.makeFailedFuture(FailedError())
            }

            func onError(_ error: Error, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
                Self.errorExpectation.fulfill()
                return eventLoop.makeFailedFuture(error)
            }
        }
        TestJob.expectation.expectedFulfillmentCount = 3
        TestJob.errorExpectation.expectedFulfillmentCount = 1

        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory)

        try app.start()
        defer { app.stop() }

        app.jobs.queue.enqueue(TestJob(), on: app.eventLoopGroup.next())

        wait(for: [TestJob.expectation, TestJob.errorExpectation], timeout: 1)
    }

    func testShutdown() throws {
        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory)
        try app.start()
        app.stop()
        app.wait()
    }

    func testShutdownJob() throws {
        class TestJob: HBJob {
            static let name = "test"
            var started: Bool = false
            var finished: Bool = false
            func execute(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
                self.started = true
                let job = eventLoop.scheduleTask(in: .milliseconds(500)) {
                    self.finished = true
                }
                return job.futureResult
            }
        }

        let app = HBApplication(testing: .live)
        app.logger.logLevel = .trace
        app.addJobs(using: .memory)
        try app.start()
        let job = TestJob()
        app.jobs.queue.enqueue(job, on: app.eventLoopGroup.next())
        // stall to give job chance to start running
        Thread.sleep(forTimeInterval: 0.1)
        app.stop()
        app.wait()

        XCTAssertTrue(job.started)
        XCTAssertTrue(job.finished)
    }

    func testJobSerialization() throws {
        struct TestJob: HBJob, Equatable {
            static let name = "test"
            let value: Int
            func execute(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
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
}

extension HBJobQueueId {
    static var test: HBJobQueueId { "test" }
}
