/*
 * SPDX-License-Identifier: Apache-2.0
 */
//
//  StepperClient.swift
//  drawloom
//
//  Created by Kevin O'Brien
//
// Copyright 2024 Kevin O'Brien.
// =============================================================================

import Foundation
import Network

/// Sends TCP commands to the ESP32 stepper server and waits for "READY\n"
class StepperClient {
    private var host: String
    private var port: Int

    init(host: String, port: Int = 9000) {
        self.host = host
        self.port = port
    }

    func setHost(_ host: String, port: Int = 9000) {
        self.host = host
        self.port = port
    }

    /// Send a command string and wait for "READY" response.
    /// Calls completion on main thread with success/failure.
    func send(command: String, completion: @escaping (Bool) -> Void) {
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port)),
            using: .tcp
        )

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                // Send command with newline
                let data = (command + "\n").data(using: .utf8)!
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        print("StepperClient send error: \(error)")
                        connection.cancel()
                        DispatchQueue.main.async { completion(false) }
                        return
                    }
                    // Wait for READY response
                    self.waitForReady(connection: connection, completion: completion)
                })
            case .failed(let error):
                print("StepperClient connection failed: \(error)")
                DispatchQueue.main.async { completion(false) }
            default:
                break
            }
        }
        connection.start(queue: .global())
    }

    private func waitForReady(connection: NWConnection, accumulated: String = "",
                              completion: @escaping (Bool) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64) { data, _, isComplete, error in
            if let error = error {
                print("StepperClient receive error: \(error)")
                connection.cancel()
                DispatchQueue.main.async { completion(false) }
                return
            }

            var text = accumulated
            if let data = data, let str = String(data: data, encoding: .utf8) {
                text += str
            }

            if text.contains("READY") {
                connection.cancel()
                DispatchQueue.main.async { completion(true) }
            } else if isComplete {
                connection.cancel()
                DispatchQueue.main.async { completion(false) }
            } else {
                // Keep reading
                self.waitForReady(connection: connection, accumulated: text, completion: completion)
            }
        }
    }

    /// Send command synchronously (blocking) — call from background thread only
    func sendSync(command: String) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        send(command: command) { success in
            result = success
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
}
