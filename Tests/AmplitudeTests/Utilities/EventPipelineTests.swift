//
//  EventPipelineTests.swift
//
//
//  Created by Marvin Liu on 11/30/22.
//

import XCTest

@testable import AmplitudeSwift

final class EventPipelineTests: XCTestCase {
    private static let FLUSH_INTERVAL_SECONDS = 10.0

    // Wait budgets here are deliberately loose (10 s; 15 s where the SDK's own 1 s + 2 s retry
    // backoff is being waited out). Everything goes through FakeHttpClient in-process, so a
    // green run returns as soon as the expectation fires; the budget only decides how long a
    // genuinely broken run takes to report. The original 1-2 s budgets were exceeded on a
    // 3-vCPU CI simulator, and the indexing that followed turned that into a bundle crash.

    private var configuration: Configuration!
    private var pipeline: EventPipeline!
    private var httpClient: FakeHttpClient!
    private var storage: PersistentStorage!

    override func setUp() {
        super.setUp()
        storage = PersistentStorage(
            storagePrefix: "event-pipeline-tests",
            logger: nil,
            diagonostics: Diagnostics(),
            diagnosticsClient: FakeDiagnosticsClient())
        configuration = Configuration(
            apiKey: "testApiKey",
            flushIntervalMillis: Int(Self.FLUSH_INTERVAL_SECONDS * 1000),
            instanceName: UUID().uuidString,
            storageProvider: storage,
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            httpClient: RemoteConfigMockServer()
        )
        let amplitude = Amplitude(configuration: configuration)
        httpClient = FakeHttpClient(configuration: configuration, diagnostics: configuration.diagonostics)
        pipeline = EventPipeline(amplitude: amplitude)
        pipeline.httpClient = httpClient
        pipeline.flushTimer?.suspend()

    }

    override func tearDown() {
        super.tearDown()
        storage.reset()
    }

    func testRecoveryDoesNotRequirePersistentEventStorage() {
        let name = UUID().uuidString
        class StateStorage: InMemoryStorage, UploadRequestStateStorage {
            var uploadRequestPending = true
        }
        let stateStorage = StateStorage()
        let amplitude = Amplitude(configuration: Configuration(
            apiKey: "test", instanceName: name, storageProvider: stateStorage,
            identifyStorageProvider: InMemoryStorage(), autocapture: [],
            offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false, httpClient: RemoteConfigMockServer()))
        let pipeline = EventPipeline(amplitude: amplitude)
        pipeline.flushTimer?.suspend()
        let firstScan = expectation(description: "recover previous request")
        pipeline.flush { firstScan.fulfill() }
        wait(for: [firstScan], timeout: 10)
        XCTAssertFalse(stateStorage.uploadRequestPending)

        stateStorage.uploadRequestPending = true
        let secondScan = expectation(description: "do not recover again")
        pipeline.flush { secondScan.fulfill() }
        wait(for: [secondScan], timeout: 10)
        XCTAssertTrue(stateStorage.uploadRequestPending)
    }

    func testDisabledDiagnosticsLeavesPendingMarkerUntouched() {
        configuration.enableDiagnostics = false
        storage.uploadRequestPending = true
        let scanned = expectation(description: "scan without recovery")
        pipeline.flush { scanned.fulfill() }
        wait(for: [scanned], timeout: 10)
        XCTAssertTrue(storage.uploadRequestPending)
    }

    func testPendingMarkerClearsOnSuccessAndErrorCallbacks() throws {
        class ObservingHttpClient: FakeHttpClient {
            var onRequest: (() -> Void)?
            override func upload(events: String, completion: @escaping (Result<Int, Error>) -> Void) -> (@Sendable () -> Void)? {
                onRequest?()
                return super.upload(events: events, completion: completion)
            }
        }
        for result: Result<Int, Error> in [.success(200), .failure(AnalyticsHttpClient.Exception.httpError(code: 500, data: nil))] {
            let completed = expectation(description: "response callback completed")
            let client = ObservingHttpClient(configuration: configuration, diagnostics: configuration.diagonostics)
            client.onRequest = { [storage] in
                XCTAssertTrue(storage?.uploadRequestPending == true)
            }
            client.uploadResults = [result]
            client.uploadExpectations = [completed]
            pipeline.httpClient = client
            configuration.flushMaxRetries = 0
            configuration.offline = false
            try storage.write(key: .EVENTS, value: BaseEvent(eventType: "test"))
            pipeline.flush()
            wait(for: [completed], timeout: 10)
            XCTAssertFalse(storage.uploadRequestPending)
        }
    }

    func testExpirationStopsTheChainAndAllowsAnotherFlush() throws {
        class ExpiringVendor: VendorSystem {
            var expire: (() -> Void)?
            override func beginBackgroundTask(expirationHandler: @escaping () -> Void) -> BackgroundTaskCompletionCallback? {
                expire = expirationHandler
                return {}
            }
        }
        class ControlledClient: AnalyticsHttpClient {
            var onUpload: (() -> Void)?
            var onCancel: (() -> Void)?
            var response: ((Result<Int, Error>) -> Void)?
            var uploadCount = 0
            override func upload(events: String, completion: @escaping (Result<Int, Error>) -> Void) -> (@Sendable () -> Void)? {
                uploadCount += 1
                response = { result in self.callbackQueue.async { completion(result) } }
                onUpload?()
                return { self.onCancel?() }
            }
        }
        for expireDuringStart in [false, true] {
            for succeeds in [false, true] {
                let storage = PersistentStorage(storagePrefix: UUID().uuidString, logger: nil,
                    diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
                defer { storage.reset() }
                let config = Configuration(apiKey: "test", flushIntervalMillis: 3_600_000,
                    instanceName: UUID().uuidString, storageProvider: storage, autocapture: [],
                    offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false,
                    httpClient: RemoteConfigMockServer())
                config.flushMaxRetries = 0
                let amplitude = Amplitude(configuration: config)
                let vendor = ExpiringVendor()
                let pipeline = EventPipeline(amplitude: amplitude, vendorSystem: vendor)
                pipeline.stop()
                let client = ControlledClient(configuration: config, diagnostics: config.diagonostics,
                    callbackQueue: pipeline.httpClient.callbackQueue)
                pipeline.httpClient = client
                for _ in 0..<2 {
                    try storage.write(key: .EVENTS, value: BaseEvent(eventType: "expiration"))
                    storage.rollover()
                }
                let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
                XCTAssertEqual(files.count, 2)
                let started = expectation(description: "upload started")
                let cancelled = expectation(description: "upload cancelled without tracking queue")
                let stopped = expectation(description: "expired chain stopped")
                client.onUpload = {
                    if expireDuringStart { vendor.expire?() }
                    started.fulfill()
                }
                client.onCancel = { cancelled.fulfill() }
                amplitude.trackingQueue.sync {}
                amplitude.trackingQueue.suspend()
                pipeline.flush { stopped.fulfill() }
                wait(for: [started], timeout: 10)
                if !expireDuringStart { vendor.expire?() }
                wait(for: [cancelled], timeout: 10)
                client.response?(succeeds ? .success(200) : .failure(URLError(.cancelled)))
                wait(for: [stopped], timeout: 10)
                amplitude.trackingQueue.resume()
                XCTAssertEqual(client.uploadCount, 1)
                XCTAssertFalse(config.offline == true)
                XCTAssertFalse(storage.uploadRequestPending)
                XCTAssertEqual(FileManager.default.fileExists(atPath: files[0].path), !succeeds)
                XCTAssertTrue(FileManager.default.fileExists(atPath: files[1].path))

                let drained = expectation(description: "another flush drains the remaining batches")
                client.onUpload = { client.response?(.success(200)) }
                pipeline.flush { drained.fulfill() }
                wait(for: [drained], timeout: 10)
                XCTAssertEqual(client.uploadCount, succeeds ? 2 : 3)
                XCTAssertFalse(storage.uploadRequestPending)
                let remainingFiles: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
                XCTAssertTrue(remainingFiles.isEmpty)
                client.onUpload = nil
                client.response = nil
            }
        }
    }

    func testCustomClientCancellationUsesNormalRetryPolicy() throws {
        actor CancellingClient {
            var firstRequest = true
            let requests: XCTestExpectation
            init(requests: XCTestExpectation) { self.requests = requests }
            func send(_ request: URLRequest) throws -> (Data, URLResponse) {
                requests.fulfill()
                if firstRequest {
                    firstRequest = false
                    throw URLError(.cancelled)
                }
                return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
        }
        let requests = expectation(description: "custom cancellation is retried")
        requests.expectedFulfillmentCount = 2
        let client = CancellingClient(requests: requests)
        let transport = ClosureHttpClient { request in
            if request.httpMethod != "POST" { return try await RemoteConfigMockServer().send(request) }
            return try await client.send(request)
        }
        let storage = PersistentStorage(storagePrefix: UUID().uuidString, logger: nil,
            diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
        defer { storage.reset() }
        let config = Configuration(apiKey: "test", flushIntervalMillis: 3_600_000,
            instanceName: UUID().uuidString, storageProvider: storage, autocapture: [],
            offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false,
            httpClient: transport)
        config.flushMaxRetries = 1
        let amplitude = Amplitude(configuration: config)
        let pipeline = EventPipeline(amplitude: amplitude)
        pipeline.stop()
        try storage.write(key: .EVENTS, value: BaseEvent(eventType: "custom-cancellation"))
        let flushed = expectation(description: "flush completes after retry")
        pipeline.flush { flushed.fulfill() }
        wait(for: [requests, flushed], timeout: 10)
        XCTAssertFalse(config.offline == true)
        XCTAssertFalse(storage.uploadRequestPending)
        let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
        XCTAssertTrue(files.isEmpty)
    }

    func testCancellationCleanupFinishesWhileTrackingIsSuspended() throws {
        class ExpiringVendor: VendorSystem {
            var expire: (() -> Void)?
            var onEnd: (() -> Void)?
            override func beginBackgroundTask(expirationHandler: @escaping () -> Void) -> BackgroundTaskCompletionCallback? {
                expire = expirationHandler
                return { self.onEnd?() }
            }
        }
        let started = expectation(description: "transport started")
        let cancelled = expectation(description: "transport cancellation requested")
        let ended = expectation(description: "assertion ended after cancellation cleanup")
        let stopped = expectation(description: "flush chain stopped without tracking")
        var response: CheckedContinuation<(Data, URLResponse), Error>!
        let transport = ClosureHttpClient { request in
            if request.httpMethod != "POST" { return try await RemoteConfigMockServer().send(request) }
            return try await withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation {
                    response = $0
                    started.fulfill()
                }
            }, onCancel: { cancelled.fulfill() })
        }
        let storage = PersistentStorage(storagePrefix: UUID().uuidString, logger: nil,
            diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
        defer { storage.reset() }
        let config = Configuration(apiKey: "test", flushIntervalMillis: 3_600_000,
            instanceName: UUID().uuidString, storageProvider: storage, autocapture: [],
            offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false,
            httpClient: transport)
        config.flushMaxRetries = 0
        let amplitude = Amplitude(configuration: config)
        let vendor = ExpiringVendor()
        let pipeline = EventPipeline(amplitude: amplitude, vendorSystem: vendor)
        pipeline.stop()
        var endCount = 0
        vendor.onEnd = {
            endCount += 1
            XCTAssertFalse(storage.uploadRequestPending)
            ended.fulfill()
        }
        try storage.write(key: .EVENTS, value: BaseEvent(eventType: "cancel"))
        storage.rollover()
        let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
        amplitude.trackingQueue.sync {}
        amplitude.trackingQueue.suspend()
        defer { amplitude.trackingQueue.resume() }
        pipeline.flush { stopped.fulfill() }
        wait(for: [started], timeout: 10)
        vendor.expire?()
        wait(for: [cancelled], timeout: 10)
        XCTAssertEqual(endCount, 0, "Cancellation alone must not release the assertion")
        XCTAssertTrue(storage.uploadRequestPending)
        response.resume(throwing: URLError(.cancelled))
        wait(for: [ended, stopped], timeout: 10)
        XCTAssertEqual(endCount, 1)
        XCTAssertFalse(config.offline == true)
        XCTAssertFalse(storage.uploadRequestPending)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(files.first).path))
    }

    func testResponsesAndCallbacksCompleteWhileTrackingIsSuspended() throws {
        actor Responses {
            var firstStatus: Int?
            let requests: XCTestExpectation
            init(status: Int, requests: XCTestExpectation) {
                firstStatus = status
                self.requests = requests
            }
            func send(_ request: URLRequest) -> (Data, URLResponse) {
                let status = firstStatus ?? 200
                firstStatus = nil
                requests.fulfill()
                let body = status == 400 ? #"{"events_with_invalid_fields":{"event_type":[0]}}"# : "{}"
                return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
            }
        }
        for status in [200, 400, 413] {
            let requests = expectation(description: "all batches uploaded after \(status)")
            requests.expectedFulfillmentCount = status == 200 ? 1 : (status == 400 ? 2 : 3)
            let responses = Responses(status: status, requests: requests)
            let transport = ClosureHttpClient { request in
                if request.url?.absoluteString != Constants.DEFAULT_API_HOST {
                    return try await RemoteConfigMockServer().send(request)
                }
                return await responses.send(request)
            }
            let storage = PersistentStorage(storagePrefix: UUID().uuidString, logger: nil,
                diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
            defer { storage.reset() }
            let config = Configuration(apiKey: "test", flushQueueSize: 1, flushIntervalMillis: 3_600_000,
                instanceName: UUID().uuidString, storageProvider: storage, autocapture: [],
                offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false,
                httpClient: transport)
            let amplitude = Amplitude(configuration: config)
            let pipeline = EventPipeline(amplitude: amplitude)
            pipeline.stop()
            let key = DispatchSpecificKey<Bool>()
            pipeline.httpClient.callbackQueue.setSpecific(key: key, value: true)
            let globalCallbacks = expectation(description: "global callbacks on upload queue")
            let eventCallbacks = expectation(description: "event callbacks on upload queue")
            globalCallbacks.expectedFulfillmentCount = 2
            eventCallbacks.expectedFulfillmentCount = 2
            var callbackCount = 0
            config.callback = { _, _, _ in
                XCTAssertEqual(DispatchQueue.getSpecific(key: key), true)
                callbackCount += 1
                globalCallbacks.fulfill()
            }
            let ids = [UUID().uuidString, UUID().uuidString]
            for id in ids {
                let event = BaseEvent(eventType: "response-queue")
                event.insertId = id
                event.callback = { _, _, _ in
                    XCTAssertEqual(DispatchQueue.getSpecific(key: key), true)
                    eventCallbacks.fulfill()
                }
                try storage.write(key: .EVENTS, value: event)
            }
            amplitude.trackingQueue.sync {}
            amplitude.trackingQueue.suspend()
            defer { amplitude.trackingQueue.resume() }
            let drained = expectation(description: "response processing completed without tracking")
            pipeline.flush { drained.fulfill() }
            wait(for: [requests, drained, globalCallbacks, eventCallbacks], timeout: 10)
            XCTAssertFalse(storage.uploadRequestPending)
            let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
            XCTAssertTrue(files.isEmpty)
            XCTAssertEqual(callbackCount, 2)
            for id in ids { XCTAssertNil(storage.getEventCallback(insertId: id)) }
        }
    }

    func testInit() {
        XCTAssertEqual(pipeline.configuration.apiKey, configuration.apiKey)
    }

    func testPutEvent() {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")

        let eventExpectation = expectation(description: "Async function")
        pipeline.put(event: testEvent) {
            eventExpectation.fulfill()
        }
        XCTAssertEqual(testEvent.attempts, 1)

        let waitResult = XCTWaiter.wait(for: [eventExpectation], timeout: 10)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(pipeline.eventCount, 1)
    }

    func testFlush() throws {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        let flushExpectation = expectation(description: "Async function")
        pipeline.flush {
            flushExpectation.fulfill()
        }
        let waitResult = XCTWaiter.wait(for: [flushExpectation], timeout: 10)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(httpClient.uploadCount, 1)
        let uploadedEvents = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(httpClient.uploadedEvents.first))
        XCTAssertEqual(uploadedEvents?.count, 1)
        XCTAssertEqual(uploadedEvents?.first?.eventType, "testEvent")
    }

    func testFlushWhenOffline() {
        pipeline.configuration.offline = false

        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        XCTAssertEqual(httpClient.uploadCount, 0)
        XCTAssertEqual(pipeline.configuration.offline, false)

        pipeline.configuration.offline = true
        pipeline.flush()

        XCTAssertEqual(pipeline.configuration.offline, true)
        XCTAssertEqual(httpClient.uploadCount, 0, "There should be no uploads when offline")
    }

    func testConstructionFailureKeepsQueuedFlushFromStartingAnotherUpload() throws {
        class CountingClient: AnalyticsHttpClient {
            var uploadCount = 0
            var onUpload: (() -> Void)?
            var onResponse: (() -> Void)?
            override func upload(events: String, completion: @escaping (Result<Int, Error>) -> Void) -> (@Sendable () -> Void)? {
                uploadCount += 1
                onUpload?()
                return super.upload(events: events) { result in
                    completion(result)
                    self.onResponse?()
                }
            }
        }
        configuration.serverUrl = "local host"
        configuration.flushMaxRetries = 0
        let amplitude = Amplitude(configuration: configuration)
        let pipeline = EventPipeline(amplitude: amplitude)
        pipeline.stop()
        let client = CountingClient(configuration: configuration, diagnostics: configuration.diagonostics,
            callbackQueue: pipeline.httpClient.callbackQueue)
        pipeline.httpClient = client
        let failed = expectation(description: "construction failure processed")
        client.onResponse = { failed.fulfill() }
        client.onUpload = {
            // Queue a second flush before the first upload queues its failure callback.
            if client.uploadCount == 1 { pipeline.flush() }
        }
        try storage.write(key: .EVENTS, value: BaseEvent(eventType: "construction-failure"))
        pipeline.flush()
        wait(for: [failed], timeout: 10)
        XCTAssertEqual(client.uploadCount, 1)
        XCTAssertTrue(configuration.offline == true)

        // Failure processing releases the busy state so a later flush can proceed.
        client.onResponse = nil
        client.onUpload = nil
        configuration.serverUrl = Constants.DEFAULT_API_HOST
        configuration.offline = false
        let drained = expectation(description: "later flush completes")
        pipeline.flush { drained.fulfill() }
        wait(for: [drained], timeout: 10)
        XCTAssertEqual(client.uploadCount, 2)
    }

    func testSimultaneousFlush() throws {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        let httpResponseExpectation = expectation(description: "httpresponse")
        httpClient.uploadExpectations = [httpResponseExpectation]

        let flushExpectations = (0..<2).map { _ in
            let expectation = expectation(description: "flush")
            pipeline.flush {
                expectation.fulfill()
            }
            return expectation
        }

        wait(for: flushExpectations, timeout: 10)
        wait(for: [httpResponseExpectation], timeout: 10)

        XCTAssertEqual(httpClient.uploadCount, 1)
        let uploadedEvents = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(httpClient.uploadedEvents.first))
        XCTAssertEqual(uploadedEvents?.count, 1)
        XCTAssertEqual(uploadedEvents?.first?.eventType, "testEvent")
    }

    func testOneUploadAtATime() {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)
        pipeline?.storage?.rollover()

        let testEvent2 = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent2")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent2)
        pipeline.storage?.rollover()

        let httpResponseExpectation1 = expectation(description: "httpresponse1")
        let httpResponseExpectation2 = expectation(description: "httpresponse2")
        httpClient.uploadExpectations = [httpResponseExpectation1, httpResponseExpectation2]

        httpResponseExpectation2.isInverted = true

        let flushExpectation = expectation(description: "flush")
        pipeline.flush {
            flushExpectation.fulfill()
        }

        wait(for: [httpResponseExpectation1], timeout: 10)

        httpResponseExpectation2.isInverted = false

        wait(for: [httpResponseExpectation2, flushExpectation], timeout: 10)

        XCTAssertEqual(httpClient.uploadCount, 2)
    }

    func testInvalidEventUpload() throws {
        let invalidResponseData = "{\"events_with_invalid_fields\": {\"user_id\": [0]}}".data(using: .utf8)!

        httpClient.uploadResults = [
            .failure(AnalyticsHttpClient.Exception.httpError(code: 400, data: invalidResponseData))
        ]

        let uploadExpectations = (0..<2).map { i in expectation(description: "httpresponse-\(i)") }
        httpClient.uploadExpectations = uploadExpectations

        (0..<2).forEach { i in
            let testEvent = BaseEvent(userId: "test", deviceId: "test-machine", eventType: "testEvent-\(i)")
            try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)
        }

        let flushExpectation1 = expectation(description: "flush-1")
        pipeline.flush {
            flushExpectation1.fulfill()
        }
        wait(for: [uploadExpectations[0], flushExpectation1], timeout: 10)

        let flushExpectation2 = expectation(description: "flush-2")
        pipeline.flush {
            flushExpectation2.fulfill()
        }
        wait(for: [uploadExpectations[1], flushExpectation2], timeout: 10)

        XCTAssertEqual(httpClient.uploadCount, 2)

        let uploadedEvents0 = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(httpClient.uploadedEvents[safe: 0]))
        XCTAssertEqual(uploadedEvents0?.count, 2)
        XCTAssertEqual(uploadedEvents0?[safe: 0]?.eventType, "testEvent-0")
        XCTAssertEqual(uploadedEvents0?[safe: 1]?.eventType, "testEvent-1")

        let uploadedEvents1 = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(httpClient.uploadedEvents[safe: 1]))
        XCTAssertEqual(uploadedEvents1?.count, 1)
        XCTAssertEqual(uploadedEvents1?[safe: 0]?.eventType, "testEvent-1")
    }

    // test continues to fail until the event is uploaded
    func testContinuousFailure() {
        pipeline.configuration.offline = false
        pipeline.configuration.flushMaxRetries = 2

        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        let uploadExpectations = (0..<4).map { i in expectation(description: "httpresponse-\(i)") }
        httpClient.uploadExpectations = uploadExpectations

        httpClient.uploadResults = [
            .failure(NSError(domain: "unknown", code: 0, userInfo: nil)), // instant failure
            .failure(NSError(domain: "unknown", code: 0, userInfo: nil)), // +1s failure
            .failure(NSError(domain: "unknown", code: 0, userInfo: nil)), // +2s failure, go offline
            .success(200)
        ]

        pipeline.flush()
        // Expected: upload 0 (instant) + upload 1 (1s retry delay)
        wait(for: [uploadExpectations[0], uploadExpectations[1]], timeout: 15)

        XCTAssertEqual(httpClient.uploadCount, 2)
        XCTAssertEqual(pipeline.configuration.offline, false)

        // Expected: upload 2 (2s retry delay)
        wait(for: [uploadExpectations[2]], timeout: 15)

        XCTAssertEqual(httpClient.uploadCount, 3)
        XCTAssertEqual(pipeline.configuration.offline, true)

        pipeline.configuration.offline = false
        let flushExpectation = expectation(description: "flush")
        pipeline.flush {
            flushExpectation.fulfill()
        }
        wait(for: [uploadExpectations[3], flushExpectation], timeout: 10)

        XCTAssertEqual(httpClient.uploadCount, 4)
    }

    func testFlushSkipsMultipleUnreadableFiles() throws {
        let storeDirectory = storage.getEventsStorageDirectory(createDirectory: false)

        // Clear anything written during Amplitude init (e.g. session_start)
        // so the files below are the only finalized event blocks on disk.
        storage.reset()

        // Create three finalized event files.
        for i in 0..<3 {
            try? pipeline.storage?.write(
                key: StorageKey.EVENTS,
                value: BaseEvent(userId: "u", deviceId: "d", eventType: "marker-\(i)")
            )
            pipeline.storage?.rollover()
        }

        let initialFiles = (try FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil))
            .filter { $0.pathExtension.isEmpty }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(initialFiles.count, 3)

        // Corrupt the first two files. The third remains a valid event block.
        let invalidUTF8 = Data([0xFF, 0xFE, 0xFD, 0xFC, 0xC0, 0xC1, 0xF5])
        try invalidUTF8.write(to: initialFiles[0])
        try invalidUTF8.write(to: initialFiles[1])

        let flushExpectation = expectation(description: "flush")
        pipeline.flush {
            flushExpectation.fulfill()
        }
        wait(for: [flushExpectation], timeout: 10)

        // Pipeline must have walked past the two corrupt files and uploaded the third.
        XCTAssertEqual(httpClient.uploadCount, 1, "Pipeline should not stall on corrupt files")
        let uploaded = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(httpClient.uploadedEvents.first))
        XCTAssertEqual(uploaded?.count, 1)
        XCTAssertEqual(uploaded?.first?.eventType, "marker-2")
    }

    func testFlushKeepsSkippingUnreadableFilesAfterUpload() throws {
        // Counts getEventsString invocations per URL so we can catch the
        // regression where skipFiles is dropped after a successful upload,
        // causing quarantine-failed corrupt files to be re-read on each
        // iteration (O(N×M) instead of O(N+M)).
        class CountingStorage: PersistentStorage {
            var readAttempts: [URL: Int] = [:]
            override func getEventsString(eventBlock: URL) -> String? {
                readAttempts[eventBlock, default: 0] += 1
                return super.getEventsString(eventBlock: eventBlock)
            }
        }

        let spyStorage = CountingStorage(
            storagePrefix: "event-pipeline-spy",
            logger: nil,
            diagonostics: Diagnostics(),
            diagnosticsClient: FakeDiagnosticsClient())
        let spyConfiguration = Configuration(
            apiKey: "testApiKey",
            flushIntervalMillis: Int(Self.FLUSH_INTERVAL_SECONDS * 1000),
            storageProvider: spyStorage,
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            httpClient: RemoteConfigMockServer()
        )
        let spyAmplitude = Amplitude(configuration: spyConfiguration)
        let spyHttp = FakeHttpClient(configuration: spyConfiguration, diagnostics: spyConfiguration.diagonostics)
        let spyPipeline = EventPipeline(amplitude: spyAmplitude)
        spyPipeline.httpClient = spyHttp
        spyPipeline.flushTimer?.suspend()

        let storeDirectory = spyStorage.getEventsStorageDirectory(createDirectory: false)
        // Clear anything written during Amplitude init (e.g. session_start) so
        // we have a clean slate for the interleaved layout below.
        spyStorage.reset()
        spyStorage.readAttempts.removeAll()

        // Layout: [corrupt, good, corrupt, good]. The earlier corrupt file lives
        // to the left of later good files, so if the upload path drops skipFiles
        // on recursion the pipeline re-reads the corrupt file after each good
        // upload.
        for i in 0..<4 {
            try? spyPipeline.storage?.write(
                key: StorageKey.EVENTS,
                value: BaseEvent(userId: "u", deviceId: "d", eventType: "marker-\(i)")
            )
            spyPipeline.storage?.rollover()
        }
        let allFiles = try FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
        let files = allFiles
            .filter { $0.pathExtension.isEmpty }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(files.count, 4)

        let invalidUTF8 = Data([0xFF, 0xFE, 0xFD, 0xFC, 0xC0, 0xC1, 0xF5])
        try invalidUTF8.write(to: files[0])
        try invalidUTF8.write(to: files[2])

        // Pre-create the quarantine targets for a window of timestamps around
        // "now" so PersistentStorage's moveItem throws NSFileWriteFileExistsError.
        // With quarantine failing, skipFiles must persist across upload recursions
        // or the pipeline re-reads corrupt files once per good upload.
        let quarantineDir = storeDirectory.appendingPathComponent(PersistentStorage.QUARANTINE_DIR_NAME)
        try FileManager.default.createDirectory(at: quarantineDir, withIntermediateDirectories: true)
        let now = Int(Date().timeIntervalSince1970)
        var precreated: [URL] = []
        for delta in -2...10 {
            for corrupt in [files[0], files[2]] {
                let blocker = quarantineDir.appendingPathComponent("\(corrupt.lastPathComponent).\(now + delta)")
                FileManager.default.createFile(atPath: blocker.path, contents: Data())
                precreated.append(blocker)
            }
        }

        let flushExpectation = expectation(description: "flush")
        spyPipeline.flush {
            flushExpectation.fulfill()
        }
        wait(for: [flushExpectation], timeout: 10)

        XCTAssertEqual(spyHttp.uploadCount, 2, "Both good files should upload exactly once")
        let uploaded0 = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(spyHttp.uploadedEvents[safe: 0]))
        let uploaded1 = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(spyHttp.uploadedEvents[safe: 1]))
        XCTAssertEqual(uploaded0?.first?.eventType, "marker-1")
        XCTAssertEqual(uploaded1?.first?.eventType, "marker-3")

        // Quarantine failed → corrupt files remain on disk with original names.
        XCTAssertTrue(FileManager.default.fileExists(atPath: files[0].path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: files[2].path))

        // The key regression assertion: each file is read at most once per flush,
        // regardless of how many good uploads happened between corrupt files.
        // Without skipFiles forwarding, the first corrupt file would be re-read
        // after each good upload (3x total for this layout).
        for (url, count) in spyStorage.readAttempts {
            XCTAssertEqual(count, 1, "File \(url.lastPathComponent) was read \(count) times; expected 1")
        }

        // reset() sweeps the quarantine directory, taking the pre-created blockers with it.
        spyStorage.reset()
        XCTAssertFalse(FileManager.default.fileExists(atPath: quarantineDir.path))
    }

    func testContinuesHandledFailure() {
        pipeline.configuration.offline = false
        pipeline.configuration.flushMaxRetries = 1

        let testEvent1 = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent1)
        pipeline.storage?.rollover()

        let testEvent2 = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent2)
        pipeline.storage?.rollover()

        let testEvent3 = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent3)
        pipeline.storage?.rollover()

        let uploadExpectations = (0..<3).map { i in expectation(description: "httpresponse-\(i)") }
        httpClient.uploadExpectations = uploadExpectations

        let invalidResponseData = "{\"events_with_invalid_fields\": {\"user_id\": [0]}}".data(using: .utf8)!
        httpClient.uploadResults = [
            .failure(AnalyticsHttpClient.Exception.httpError(code: AnalyticsHttpClient.HttpStatus.BAD_REQUEST.rawValue, data: invalidResponseData)),
            .failure(AnalyticsHttpClient.Exception.httpError(code: AnalyticsHttpClient.HttpStatus.PAYLOAD_TOO_LARGE.rawValue, data: nil)),
            .success(200),
        ]

        let flushExpectation = expectation(description: "flush")
        pipeline.flush {
            flushExpectation.fulfill()
        }

        wait(for: uploadExpectations + [flushExpectation], timeout: 10)

        XCTAssertEqual(httpClient.uploadCount, 3)
        XCTAssertEqual(pipeline.configuration.offline, false)
    }
}
