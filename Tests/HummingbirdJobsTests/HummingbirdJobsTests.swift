//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
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
import Logging
import NIOConcurrencyHelpers
import ServiceLifecycle
import XCTest

extension XCTestExpectation {
    convenience init(description: String, expectedFulfillmentCount: Int) {
        self.init(description: description)
        self.expectedFulfillmentCount = expectedFulfillmentCount
    }
}

final class HummingbirdJobsTests: XCTestCase {
    func wait(for expectations: [XCTestExpectation], timeout: TimeInterval) async {
        #if (os(Linux) && swift(<5.10)) || swift(<5.8)
        super.wait(for: expectations, timeout: timeout)
        #else
        await fulfillment(of: expectations, timeout: timeout)
        #endif
    }

    /// Helper function for test a server
    ///
    /// Creates test client, runs test function abd ensures everything is
    /// shutdown correctly
    public func testJobQueue(
        _ jobQueueHandler: HBJobQueueHandler<some HBJobQueue>,
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
        let expectation = XCTestExpectation(description: "TestJob.execute was called", expectedFulfillmentCount: 10)
        let jobIdentifer = HBJobIdentifier<Int>(#function)
        HBJobRegister.registerJob(jobIdentifer) { parameters, context in
            context.logger.info("Parameters=\(parameters)")
            try await Task.sleep(for: .milliseconds(Int.random(in: 10..<50)))
            expectation.fulfill()
        }
        let jobQueue = HBMemoryJobQueue()
        let jobQueueHandler = HBJobQueueHandler(
            queue: jobQueue,
            numWorkers: 1,
            logger: Logger(label: "HummingbirdJobsTests")
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueue.push(id: jobIdentifer, parameters: 1)
            try await jobQueue.push(id: jobIdentifer, parameters: 2)
            try await jobQueue.push(id: jobIdentifer, parameters: 3)
            try await jobQueue.push(id: jobIdentifer, parameters: 4)
            try await jobQueue.push(id: jobIdentifer, parameters: 5)
            try await jobQueue.push(id: jobIdentifer, parameters: 6)
            try await jobQueue.push(id: jobIdentifer, parameters: 7)
            try await jobQueue.push(id: jobIdentifer, parameters: 8)
            try await jobQueue.push(id: jobIdentifer, parameters: 9)
            try await jobQueue.push(id: jobIdentifer, parameters: 10)

            await self.wait(for: [expectation], timeout: 5)
        }
    }

    func testMultipleWorkers() async throws {
        let jobIdentifer = HBJobIdentifier<Int>(#function)
        let runningJobCounter = ManagedAtomic(0)
        let maxRunningJobCounter = ManagedAtomic(0)
        let expectation = XCTestExpectation(description: "TestJob.execute was called", expectedFulfillmentCount: 10)
        HBJobRegister.registerJob(jobIdentifer) { parameters, context in
            let runningJobs = runningJobCounter.wrappingIncrementThenLoad(by: 1, ordering: .relaxed)
            if runningJobs > maxRunningJobCounter.load(ordering: .relaxed) {
                maxRunningJobCounter.store(runningJobs, ordering: .relaxed)
            }
            try await Task.sleep(for: .milliseconds(Int.random(in: 10..<50)))
            context.logger.info("Parameters=\(parameters)")
            expectation.fulfill()
            runningJobCounter.wrappingDecrement(by: 1, ordering: .relaxed)
        }

        let jobQueue = HBMemoryJobQueue()
        let jobQueueHandler = HBJobQueueHandler(
            queue: jobQueue,
            numWorkers: 4,
            logger: Logger(label: "HummingbirdJobsTests")
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueue.push(id: jobIdentifer, parameters: 1)
            try await jobQueue.push(id: jobIdentifer, parameters: 2)
            try await jobQueue.push(id: jobIdentifer, parameters: 3)
            try await jobQueue.push(id: jobIdentifer, parameters: 4)
            try await jobQueue.push(id: jobIdentifer, parameters: 5)
            try await jobQueue.push(id: jobIdentifer, parameters: 6)
            try await jobQueue.push(id: jobIdentifer, parameters: 7)
            try await jobQueue.push(id: jobIdentifer, parameters: 8)
            try await jobQueue.push(id: jobIdentifer, parameters: 9)
            try await jobQueue.push(id: jobIdentifer, parameters: 10)

            await self.wait(for: [expectation], timeout: 5)

            XCTAssertGreaterThan(maxRunningJobCounter.load(ordering: .relaxed), 1)
            XCTAssertLessThanOrEqual(maxRunningJobCounter.load(ordering: .relaxed), 4)
        }
    }

    func testErrorRetryCount() async throws {
        let jobIdentifer = HBJobIdentifier<Int>(#function)
        let expectation = XCTestExpectation(description: "TestJob.execute was called", expectedFulfillmentCount: 4)
        let failedJobCount = ManagedAtomic(0)
        struct FailedError: Error {}
        HBJobRegister.registerJob(jobIdentifer, maxRetryCount: 3) { _, _ in
            expectation.fulfill()
            throw FailedError()
        }
        var logger = Logger(label: "HummingbirdJobsTests")
        logger.logLevel = .trace
        let jobQueue = HBMemoryJobQueue { _, _ in failedJobCount.wrappingIncrement(by: 1, ordering: .relaxed) }
        let jobQueueHandler = HBJobQueueHandler(
            queue: jobQueue,
            numWorkers: 4,
            logger: logger
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueue.push(id: jobIdentifer, parameters: 0)

            await self.wait(for: [expectation], timeout: 5)
        }
        XCTAssertEqual(failedJobCount.load(ordering: .relaxed), 1)
    }

    func testJobSerialization() async throws {
        struct TestJobParameters: Codable {
            let id: Int
            let message: String
        }
        let expectation = XCTestExpectation(description: "TestJob.execute was called")
        let jobIdentifer = HBJobIdentifier<TestJobParameters>(#function)
        HBJobRegister.registerJob(jobIdentifer) { parameters, _ in
            XCTAssertEqual(parameters.id, 23)
            XCTAssertEqual(parameters.message, "Hello!")
            expectation.fulfill()
        }
        let jobQueue = HBMemoryJobQueue()
        let jobQueueHandler = HBJobQueueHandler(
            queue: jobQueue,
            numWorkers: 1,
            logger: Logger(label: "HummingbirdJobsTests")
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueue.push(id: jobIdentifer, parameters: .init(id: 23, message: "Hello!"))

            await self.wait(for: [expectation], timeout: 5)
        }
    }

    /// Test job is cancelled on shutdown
    func testShutdownJob() async throws {
        let jobIdentifer = HBJobIdentifier<Int>(#function)
        let expectation = XCTestExpectation(description: "TestJob.execute was called", expectedFulfillmentCount: 1)
        HBJobRegister.registerJob(jobIdentifer) { _, _ in
            expectation.fulfill()
            try await Task.sleep(for: .milliseconds(1000))
        }

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
            try await jobQueue.push(id: jobIdentifer, parameters: 0)
            await self.wait(for: [expectation], timeout: 5)
        }

        XCTAssertEqual(cancelledJobCount.load(ordering: .relaxed), 1)
    }

    /// test job fails to decode but queue continues to process
    func testFailToDecode() async throws {
        let string: NIOLockedValueBox<String> = .init("")
        let jobIdentifer1 = HBJobIdentifier<Int>(#function)
        let jobIdentifer2 = HBJobIdentifier<String>(#function)
        let expectation = XCTestExpectation(description: "job was called", expectedFulfillmentCount: 1)
        HBJobRegister.registerJob(jobIdentifer2) { parameters, _ in
            string.withLockedValue { $0 = parameters }
            expectation.fulfill()
        }

        let jobQueue = HBMemoryJobQueue()
        let jobQueueHandler = HBJobQueueHandler(
            queue: jobQueue,
            numWorkers: 1,
            logger: Logger(label: "HummingbirdJobsTests")
        )
        try await testJobQueue(jobQueueHandler) {
            try await jobQueue.push(id: jobIdentifer1, parameters: 2)
            try await jobQueue.push(id: jobIdentifer2, parameters: "test")
            await self.wait(for: [expectation], timeout: 5)
        }
        string.withLockedValue {
            XCTAssertEqual($0, "test")
        }
    }

    func testMultipleJobQueueHandlers() async throws {
        let jobIdentifer = HBJobIdentifier<Int>(#function)
        let expectation = XCTestExpectation(description: "TestJob.execute was called", expectedFulfillmentCount: 200)
        HBJobRegister.registerJob(jobIdentifer) { parameters, context in
            context.logger.info("Parameters=\(parameters)")
            try await Task.sleep(for: .milliseconds(Int.random(in: 10..<50)))
            expectation.fulfill()
        }
        let logger = {
            var logger = Logger(label: "HummingbirdJobsTests")
            logger.logLevel = .debug
            return logger
        }()
        let jobQueue = HBMemoryJobQueue()
        let jobQueueHandler = HBJobQueueHandler(
            queue: jobQueue,
            numWorkers: 2,
            logger: logger
        )
        let jobQueue2 = HBMemoryJobQueue()
        let jobQueueHandler2 = HBJobQueueHandler(
            queue: jobQueue2,
            numWorkers: 2,
            logger: logger
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            let serviceGroup = ServiceGroup(
                configuration: .init(
                    services: [jobQueueHandler, jobQueueHandler2],
                    gracefulShutdownSignals: [.sigterm, .sigint],
                    logger: logger
                )
            )
            group.addTask {
                try await serviceGroup.run()
            }
            do {
                for i in 0..<200 {
                    try await jobQueue.push(id: jobIdentifer, parameters: i)
                }
                await self.wait(for: [expectation], timeout: 5)
                await serviceGroup.triggerGracefulShutdown()
            } catch {
                XCTFail("\(String(reflecting: error))")
                await serviceGroup.triggerGracefulShutdown()
                throw error
            }
        }
    }
}
