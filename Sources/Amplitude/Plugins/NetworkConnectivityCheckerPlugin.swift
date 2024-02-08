//
//  NetworkConnectivityCheckerPlugin.swift
//  Amplitude-Swift
//
//  Created by Xinyi.Ye on 1/26/24.
//

import Foundation
import Network
import Combine

// Define a custom struct to represent network path status
public struct NetworkPath {
    public var status: NWPath.Status

    public init(status: NWPath.Status) {
        self.status = status
    }
}

// Protocol for creating network paths
protocol PathCreationProtocol {
    var networkPathPublisher: AnyPublisher<NetworkPath, Never>? { get }
    func start()
}

// Implementation of PathCreationProtocol using NWPathMonitor
final class PathCreation: PathCreationProtocol {
    public var networkPathPublisher: AnyPublisher<NetworkPath, Never>?
    private let subject = PassthroughSubject<NWPath, Never>()
    private let monitor = NWPathMonitor()

    func start() {
        monitor.pathUpdateHandler = subject.send
        networkPathPublisher = subject
            .map { NetworkPath(status: $0.status) }
            .eraseToAnyPublisher()
        monitor.start(queue: .main)
    }
}

open class NetworkConnectivityCheckerPlugin: BeforePlugin {
    public static let Disabled: Bool? = nil
    var pathCreation: PathCreationProtocol
    private var pathUpdateCancellable: AnyCancellable?

    init(pathCreation: PathCreationProtocol = PathCreation()) {
        self.pathCreation = pathCreation
        super.init()
    }

    open override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)
        amplitude.logger?.debug(message: "Installing NetworkConnectivityCheckerPlugin, offline feature should be supported.")

        pathCreation.start()
        pathUpdateCancellable = pathCreation.networkPathPublisher?
            .sink(receiveValue: { [weak self] networkPath in
                let isOnline = networkPath.status == .satisfied
                self?.amplitude?.logger?.debug(message: "Network connectivity changed to \(isOnline ? "online" : "offline").")
                self?.amplitude?.configuration.offline = !isOnline
                if isOnline {
                    amplitude.flush()
                }
            })
    }

    open override func teardown() {
        pathUpdateCancellable?.cancel()
    }
}
