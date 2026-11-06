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

/// Sends one weaving pass to the ESP32 over HTTP (POST /run) and blocks until
/// the firmware replies "READY" (carriage has fired the solenoids and returned home).
///
/// The caller still passes the bit string from DrawdownData.bitString():
/// one character per solenoid switch, "1" = fire that switch on this pass.
class StepperClient {
    /// Loom geometry. Keep numSwitches in sync with NUM_SWITCHES in main.cpp.
    struct Loom {
        var numSwitches: Int = 30      // raise to 50+ as switches are added
        var pitchMM: Double = 10.0     // spacing between adjacent switches
        var originMM: Double = 10.0    // carriage position of switch 1 (ASSUMED = one pitch; adjust)
    }

    var loom = Loom()
    /// Seconds to wait for the whole pass (forward + return). The response only
    /// arrives when the carriage is home, so this must exceed the longest pass.
    var timeout: TimeInterval = 120

    private var host: String
    private var port: Int

    init(host: String, port: Int = 80) {
        self.host = host
        self.port = port
    }

    func setHost(_ host: String, port: Int = 80) {
        self.host = host
        self.port = port
    }

    /// Convert a bit string to ascending carriage positions in mm.
    /// Returns nil if the string is longer than the number of switches.
    func positions(from bits: String) -> [Double]? {
        let chars = Array(bits)
        guard chars.count <= loom.numSwitches else {
            print("StepperClient: \(chars.count) columns but loom has \(loom.numSwitches) switches")
            return nil
        }
        var result: [Double] = []
        for (i, c) in chars.enumerated() where c == "1" {
            result.append(loom.originMM + Double(i) * loom.pitchMM)
        }
        return result
    }

    /// Send one pass and block until it completes. Call from a background thread.
    /// `command` is the 0/1 bit string (name kept so DrawdownModel needs no change).
    func sendSync(command bits: String) -> Bool {
        guard let positions = positions(from: bits) else { return false }

        // Nothing to pull for this color on this row: no carriage pass needed.
        if positions.isEmpty { return true }

        guard let url = URL(string: "http://\(host):\(port)/run") else { return false }
        let body = positions.map { String(format: "%.1f", $0) }.joined(separator: ",")

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = false   // fail fast if unreachable / local network denied
        let session = URLSession(configuration: config)

        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error = error {
                print("StepperClient error: \(error)")
                return
            }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let data = data,
                  String(data: data, encoding: .utf8)?.contains("READY") == true
            else {
                print("StepperClient: unexpected response")
                return
            }
            ok = true
        }.resume()
        semaphore.wait()
        session.finishTasksAndInvalidate()
        return ok
    }
}
