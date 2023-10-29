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
            func execute(logger: Logger) async throws {
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        TestJob.register()

        let cancelledJobCount = ManagedAtomic(0)
        var logger = Logger(label: "HummingbirdJobsTests")
        logger.logLevel = .trace
        let jobQueueHandler = HBJobQueueHandler(
            queue: HBMemoryJobQueue { _, error in
                if error is CancellationError {
                    cancelledJobCount.wrappingIncrement(by: 1, ordering: .relaxed)
                }
            },
            numWorkers: 4,
            logger: logger
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueueHandler.enqueue(TestJob())
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

        let jobQueueHandler = HBJobQueueHandler(
            queue: HBMemoryJobQueue(),
            numWorkers: 1,
            logger: Logger(label: "HummingbirdJobsTests")
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueueHandler.enqueue(TestJob1())
            try await jobQueueHandler.enqueue(TestJob2(value: "test"))
            // stall to give job chance to start running
            try await Task.sleep(for: .milliseconds(500))
        }

        XCTAssertEqual(TestJob2.value, "test")
    }
}
