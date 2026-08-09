//
//  SMC.swift
//  Tests
//
//  Created by Serhiy Mytrovtsiy on 09/08/2026.
//  Using Swift 6.0.
//  Running on macOS 26.5.
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import XCTest
@testable import Kit

class SMCTests: XCTestCase {
    /// Build an `SMCVal_t` of the given type with its first two payload bytes set.
    private func value(_ type: SMCDataType, _ b0: UInt8, _ b1: UInt8) -> SMCVal_t {
        var val = SMCVal_t("TEST")
        val.dataSize = 2
        val.dataType = type.rawValue
        val.bytes[0] = b0
        val.bytes[1] = b1
        return val
    }

    /// Decode `value(...)` and assert it succeeded (these types always return a value).
    private func decoded(_ type: SMCDataType, _ b0: UInt8, _ b1: UInt8) -> Double {
        // swiftlint:disable:next force_unwrapping
        return SMC.decode(value(type, b0, b1))!
    }

    func testSP78_negativeTemperature() throws {
        // -5.0 C is stored as round(-5 * 256) = -1280 = 0xFB00 (bytes 0xFB, 0x00).
        // The old unsigned decode returned 251.0; the signed decode must return -5.0.
        XCTAssertEqual(decoded(.SP78, 0xFB, 0x00), -5.0)
    }

    func testSP78_positiveControl() throws {
        // 0x0080 as signed Int16 = 128; 128 / 256 = 0.5 (unchanged by the fix).
        XCTAssertEqual(decoded(.SP78, 0x00, 0x80), 0.5)
    }

    func testSP78_zeroAndPositiveMax() throws {
        XCTAssertEqual(decoded(.SP78, 0x00, 0x00), 0.0)
        // 0x7FFF / 256 = 127.99609375 — the max sp78 value, unchanged by the fix.
        XCTAssertEqual(decoded(.SP78, 0x7F, 0xFF), 127.99609375)
    }

    func testSignedFixedPointTypes_decodeNegatives() throws {
        // For every signed SP type, the value one LSB below zero (0xFFFF) must
        // decode to a small negative number, not a large positive one.
        XCTAssertEqual(decoded(.SP1E, 0xFF, 0xFF), -1.0 / 16384)
        XCTAssertEqual(decoded(.SP3C, 0xFF, 0xFF), -1.0 / 4096)
        XCTAssertEqual(decoded(.SP4B, 0xFF, 0xFF), -1.0 / 2048)
        XCTAssertEqual(decoded(.SP5A, 0xFF, 0xFF), -1.0 / 1024)
        XCTAssertEqual(decoded(.SP69, 0xFF, 0xFF), -1.0 / 512)
        XCTAssertEqual(decoded(.SP87, 0xFF, 0xFF), -1.0 / 128)
        XCTAssertEqual(decoded(.SP96, 0xFF, 0xFF), -1.0 / 64)
        XCTAssertEqual(decoded(.SPA5, 0xFF, 0xFF), -1.0 / 32)
        XCTAssertEqual(decoded(.SPB4, 0xFF, 0xFF), -1.0 / 16)
    }

    func testSignedFixedPointTypes_positivesUnchanged() throws {
        // Positive readings must match the old unsigned decode.
        XCTAssertEqual(decoded(.SP78, 0x19, 0x00), 25.0)
        XCTAssertEqual(decoded(.SP87, 0x01, 0x40), 2.5)
    }

    func testUnsignedTypes_unaffected() throws {
        // UI8 / UI16 stay unsigned — the fix only touches signed SP types.
        XCTAssertEqual(decoded(.UI8, 0xFF, 0x00), 255.0)
        XCTAssertEqual(decoded(.UI16, 0xFF, 0x00), 65280.0)
    }
}
