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

import Atomics
import HummingbirdJobs
import ServiceLifecycle
import XCTest

final class HummingbirdJobsTests: XCTestCase {
    /// Helper function for test a server
    ///
    /// Creates test client, runs test function abd ensures everything is
    /// shutdown correctly
    public func testJobQueue<JobQueue: HBJobQueue>(
        _ jobQueueHandler: HBJobQueueHandler<JobQueue>,
        _ test: () async throws -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            let serviceGroup = ServiceGroup(
                configuration: .init(
                    services: [jobQueueHandler],
                    gracefulShutdownSignals: [.sigterm, .sigint],
                    logger: Logger(label: "JobQueueService")
                )
            )
            group.addTask {
                try await serviceGroup.run()
            }
            try await test()
            await serviceGroup.triggerGracefulShutdown()
        }
    }

    func testBasic() async throws {
        struct TestJob: HBJob {
            static let name = "testBasic"
            static let expectation = XCTestExpectation(description: "Jobs Completed")

            let value: Int
            func execute(logger: Logger) async throws {
                print(self.value)
                try await Task.sleep(for: .milliseconds(Int.random(in: 10..<50)))
                Self.expectation.fulfill()
            }
        }
        TestJob.register()
        TestJob.expectation.expectedFulfillmentCount = 10

        let jobQueueHandler = HBJobQueueHandler(
            queue: HBMemoryJobQueue(),
            numWorkers: 1,
            logger: Logger(label: "HummingbirdJobsTests")
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueueHandler.enqueue(TestJob(value: 1))
            try await jobQueueHandler.enqueue(TestJob(value: 2))
            try await jobQueueHandler.enqueue(TestJob(value: 3))
            try await jobQueueHandler.enqueue(TestJob(value: 4))
            try await jobQueueHandler.enqueue(TestJob(value: 5))
            try await jobQueueHandler.enqueue(TestJob(value: 6))
            try await jobQueueHandler.enqueue(TestJob(value: 7))
            try await jobQueueHandler.enqueue(TestJob(value: 8))
            try await jobQueueHandler.enqueue(TestJob(value: 9))
            try await jobQueueHandler.enqueue(TestJob(value: 10))

            wait(for: [TestJob.expectation], timeout: 5)
        }
    }

    func testMultipleWorkers() async throws {
        struct TestJob: HBJob {
            static let name = "testBasic"
            static let runningJobCounter = ManagedAtomic(0)
            static let maxRunningJobCounter = ManagedAtomic(0)
            static let expectation = XCTestExpectation(description: "Jobs Completed")

            let value: Int
            func execute(logger: Logger) async throws {
                let runningJobs = Self.runningJobCounter.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)
                if runningJobs > Self.maxRunningJobCounter.load(ordering: .relaxed) {
                    Self.maxRunningJobCounter.store(runningJobs, ordering: .relaxed)
                }
                try await Task.sleep(for: .milliseconds(Int.random(in: 10..<50)))
                print(self.value)
                Self.expectation.fulfill()
                Self.runningJobCounter.wrappingDecrement(by: 1, ordering: .relaxed)
            }
        }
        TestJob.register()
        TestJob.expectation.expectedFulfillmentCount = 10

        let jobQueueHandler = HBJobQueueHandler(
            queue: HBMemoryJobQueue(),
            numWorkers: 4,
            logger: Logger(label: "HummingbirdJobsTests")
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueueHandler.enqueue(TestJob(value: 1))
            try await jobQueueHandler.enqueue(TestJob(value: 2))
            try await jobQueueHandler.enqueue(TestJob(value: 3))
            try await jobQueueHandler.enqueue(TestJob(value: 4))
            try await jobQueueHandler.enqueue(TestJob(value: 5))
            try await jobQueueHandler.enqueue(TestJob(value: 6))
            try await jobQueueHandler.enqueue(TestJob(value: 7))
            try await jobQueueHandler.enqueue(TestJob(value: 8))
            try await jobQueueHandler.enqueue(TestJob(value: 9))
            try await jobQueueHandler.enqueue(TestJob(value: 10))

            wait(for: [TestJob.expectation], timeout: 5)
            XCTAssertGreaterThan(TestJob.maxRunningJobCounter.load(ordering: .relaxed), 1)
            XCTAssertLessThanOrEqual(TestJob.maxRunningJobCounter.load(ordering: .relaxed), 4)
        }
    }

    func testErrorRetryCount() async throws {
        let failedJobCount = ManagedAtomic(0)
        struct FailedError: Error {}

        struct TestJob: HBJob {
            static let name = "testErrorRetryCount"
            static let maxRetryCount = 3
            static let expectation = XCTestExpectation(description: "Jobs Completed")
            func execute(logger: Logger) async throws {
                Self.expectation.fulfill()
                throw FailedError()
            }
        }
        TestJob.register()
        TestJob.expectation.expectedFulfillmentCount = 4
        var logger = Logger(label: "HummingbirdJobsTests")
        logger.logLevel = .trace
        let jobQueueHandler = HBJobQueueHandler(
            queue: HBMemoryJobQueue { _, _ in failedJobCount.wrappingIncrement(by: 1, ordering: .relaxed) },
            numWorkers: 4,
            logger: logger
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueueHandler.enqueue(TestJob())

            wait(for: [TestJob.expectation], timeout: 5)
        }
        XCTAssertEqual(failedJobCount.load(ordering: .relaxed), 1)
    }
    /*
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

         try app.XCTExecute(uri: "/job", method: .GET) { response in
             XCTAssertEqual(response.status, .ok)
         }

         wait(for: [TestJob.expectation], timeout: 5)
     }

     @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
     func testAsyncJob() throws {
         #if os(macOS)
         // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
         guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
         #endif
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
     */
}
