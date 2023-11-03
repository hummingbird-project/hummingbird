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
import HummingbirdXCT
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
            static let expectation = AsyncExpectation(10)

            let value: Int
            func execute(logger: Logger) async throws {
                print(self.value)
                try await Task.sleep(for: .milliseconds(Int.random(in: 10..<50)))
                await Self.expectation.fulfill()
            }
        }
        TestJob.register()
        let jobQueue = HBMemoryJobQueue()
        let jobQueueHandler = HBJobQueueHandler(
            queue: jobQueue,
            numWorkers: 1,
            logger: Logger(label: "HummingbirdJobsTests")
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueue.push(TestJob(value: 1))
            try await jobQueue.push(TestJob(value: 2))
            try await jobQueue.push(TestJob(value: 3))
            try await jobQueue.push(TestJob(value: 4))
            try await jobQueue.push(TestJob(value: 5))
            try await jobQueue.push(TestJob(value: 6))
            try await jobQueue.push(TestJob(value: 7))
            try await jobQueue.push(TestJob(value: 8))
            try await jobQueue.push(TestJob(value: 9))
            try await jobQueue.push(TestJob(value: 10))

            try await withTimeout(timeout: .seconds(5)) { try await TestJob.expectation.wait() }
        }
    }

    func testMultipleWorkers() async throws {
        struct TestJob: HBJob {
            static let name = "testBasic"
            static let runningJobCounter = ManagedAtomic(0)
            static let maxRunningJobCounter = ManagedAtomic(0)
            static let expectation = AsyncExpectation(10)

            let value: Int
            func execute(logger: Logger) async throws {
                let runningJobs = Self.runningJobCounter.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)
                if runningJobs > Self.maxRunningJobCounter.load(ordering: .relaxed) {
                    Self.maxRunningJobCounter.store(runningJobs, ordering: .relaxed)
                }
                try await Task.sleep(for: .milliseconds(Int.random(in: 10..<50)))
                print(self.value)
                await Self.expectation.fulfill()
                Self.runningJobCounter.wrappingDecrement(by: 1, ordering: .relaxed)
            }
        }
        TestJob.register()

        let jobQueue = HBMemoryJobQueue()
        let jobQueueHandler = HBJobQueueHandler(
            queue: jobQueue,
            numWorkers: 4,
            logger: Logger(label: "HummingbirdJobsTests")
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueue.push(TestJob(value: 1))
            try await jobQueue.push(TestJob(value: 2))
            try await jobQueue.push(TestJob(value: 3))
            try await jobQueue.push(TestJob(value: 4))
            try await jobQueue.push(TestJob(value: 5))
            try await jobQueue.push(TestJob(value: 6))
            try await jobQueue.push(TestJob(value: 7))
            try await jobQueue.push(TestJob(value: 8))
            try await jobQueue.push(TestJob(value: 9))
            try await jobQueue.push(TestJob(value: 10))

            try await withTimeout(timeout: .seconds(5)) { try await TestJob.expectation.wait() }

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
            static let expectation = AsyncExpectation(4)
            func execute(logger: Logger) async throws {
                await Self.expectation.fulfill()
                throw FailedError()
            }
        }
        TestJob.register()
        var logger = Logger(label: "HummingbirdJobsTests")
        logger.logLevel = .trace
        let jobQueue = HBMemoryJobQueue { _, _ in failedJobCount.wrappingIncrement(by: 1, ordering: .relaxed) }
        let jobQueueHandler = HBJobQueueHandler(
            queue: jobQueue,
            numWorkers: 4,
            logger: logger
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueue.push(TestJob())

            try await withTimeout(timeout: .seconds(5)) { try await TestJob.expectation.wait() }
        }
        XCTAssertEqual(failedJobCount.load(ordering: .relaxed), 1)
    }

    func testJobSerialization() throws {
        struct TestJob: HBJob, Equatable {
            static let name = "testJobSerialization"
            let value: Int
            func execute(logger: Logger) async throws {}
        }
        TestJob.register()
        let job = TestJob(value: 2)
        let jobInstance = HBJobInstance(job)
        let data = try JSONEncoder().encode(jobInstance)
        let jobInstance2 = try JSONDecoder().decode(HBJobInstance.self, from: data)
        XCTAssertEqual(jobInstance2.job as? TestJob, job)
    }

    /// Test job is cancelled on shutdown
    func testShutdownJob() async throws {
        struct TestJob: HBJob {
            static let name = "testShutdownJob"
            static let expectation = AsyncExpectation(1)
            func execute(logger: Logger) async throws {
                await Self.expectation.fulfill()
                try await Task.sleep(for: .milliseconds(1000))
            }
        }
        TestJob.register()

        let cancelledJobCount = ManagedAtomic(0)
        var logger = Logger(label: "HummingbirdJobsTests")
        logger.logLevel = .trace
        let jobQueue = HBMemoryJobQueue { _, error in
            if error is CancellationError {
                cancelledJobCount.wrappingIncrement(by: 1, ordering: .relaxed)
            }
        }
        let jobQueueHandler = HBJobQueueHandler(
            queue: jobQueue,
            numWorkers: 4,
            logger: logger
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueue.push(TestJob())
            try await TestJob.expectation.wait()
        }

        XCTAssertEqual(cancelledJobCount.load(ordering: .relaxed), 1)
    }

    /// test job fails to decode but queue continues to process
    func testFailToDecode() async throws {
        struct TestJob1: HBJob {
            static let name = "testFailToDecode"
            func execute(logger: Logger) async throws {}
        }
        struct TestJob2: HBJob {
            static let name = "testFailToDecode"
            static var value: String?
            let value: String
            func execute(logger: Logger) async throws {
                Self.value = self.value
            }
        }
        TestJob2.register()

        let jobQueue = HBMemoryJobQueue()
        let jobQueueHandler = HBJobQueueHandler(
            queue: jobQueue,
            numWorkers: 1,
            logger: Logger(label: "HummingbirdJobsTests")
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueue.push(TestJob1())
            try await jobQueue.push(TestJob2(value: "test"))
            // stall to give job chance to start running
            try await Task.sleep(for: .milliseconds(500))
        }

        XCTAssertEqual(TestJob2.value, "test")
    }
}
