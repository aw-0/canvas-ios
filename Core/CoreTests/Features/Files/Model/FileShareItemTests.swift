//
// This file is part of Canvas.
// Copyright (C) 2026-present  Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import XCTest
@testable import Core

final class FileShareItemTests: XCTestCase {
    private var directory: URL!
    private var sourceURL: URL!
    private var sourceData: Data!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sourceURL = directory.appendingPathComponent("name+%287%29.pdf")
        sourceData = Data("some file contents".utf8)
        try sourceData.write(to: sourceURL)
    }

    override func tearDownWithError() throws {
        let directoryToRemove = directory!
        defer { try? FileManager.default.removeItem(at: directoryToRemove) }
        directory = nil
        sourceURL = nil
        sourceData = nil
        try super.tearDownWithError()
    }

    func test_init_withReadableDisplayName_shouldPreserveNameAndContents() throws {
        let name = "some name (7) + 100% café 📄.pdf"
        let testee = try makeShareItem(displayName: name)

        XCTAssertEqual(testee.url.lastPathComponent, name)
        XCTAssertEqual(try Data(contentsOf: testee.url), sourceData)
        XCTAssertEqual(try Data(contentsOf: sourceURL), sourceData)
        XCTAssertNotEqual(testee.url, sourceURL)
    }

    func test_init_withLiteralPercentEscapes_shouldNotDecodeDisplayName() throws {
        let name = "some %20 name %28 + %29.pdf"
        let testee = try makeShareItem(displayName: name)

        XCTAssertEqual(testee.url.lastPathComponent, name)
    }

    func test_init_withMissingOrInvalidDisplayName_shouldUseSourceName() throws {
        let names: [String?] = [nil, "", "  ", ".", ".."]
        for name in names {
            let testee = try makeShareItem(displayName: name)

            XCTAssertEqual(testee.url.lastPathComponent, sourceURL.lastPathComponent)
        }
    }

    func test_init_withMissingOrDifferentExtension_shouldPreserveSourceExtension() throws {
        for name in ["some name", "some name.txt"] {
            let testee = try makeShareItem(displayName: name)

            XCTAssertEqual(testee.url.lastPathComponent, name + ".pdf")
        }
    }

    func test_init_withUppercaseExtension_shouldNotAppendAnotherExtension() throws {
        let testee = try makeShareItem(displayName: "some name.PDF")

        XCTAssertEqual(testee.url.lastPathComponent, "some name.PDF")
    }

    func test_init_withPathSeparatorsAndControlCharacters_shouldKeepFileInExportDirectory() throws {
        let testee = try makeShareItem(displayName: "../some\\name:\u{0}\n.pdf")

        XCTAssertEqual(testee.url.lastPathComponent, ".._some_name___.pdf")
        XCTAssertEqual(testee.url.deletingLastPathComponent().deletingLastPathComponent(), directory)
        XCTAssertEqual(try Data(contentsOf: testee.url), sourceData)
    }

    func test_init_withLongUnicodeName_shouldLimitUTF8LengthAndPreserveExtension() throws {
        let testee = try makeShareItem(displayName: String(repeating: "📄", count: 100) + ".pdf")

        XCTAssertLessThanOrEqual(testee.url.lastPathComponent.utf8.count, 255)
        XCTAssertEqual(testee.url.pathExtension, "pdf")
        XCTAssertEqual(try Data(contentsOf: testee.url), sourceData)
    }

    func test_init_withExtensionlessSource_shouldPreserveDisplayName() throws {
        let source = directory.appendingPathComponent("some source")
        try sourceData.write(to: source)
        let testee = try FileShareItem(sourceURL: source, displayName: "some name (7)", temporaryDirectory: directory)

        XCTAssertEqual(testee.url.lastPathComponent, "some name (7)")
    }

    func test_init_withSameDisplayName_shouldCreateIndependentExports() throws {
        let testee = try makeShareItem(displayName: "some name.pdf")
        let anotherItem = try makeShareItem(displayName: "some name.pdf")

        XCTAssertNotEqual(testee.url, anotherItem.url)
        testee.removeTemporaryFiles()
        XCTAssertEqual(try Data(contentsOf: anotherItem.url), sourceData)
    }

    func test_init_withMissingSource_shouldThrowAndRemoveExportDirectory() throws {
        try FileManager.default.removeItem(at: sourceURL)

        XCTAssertThrowsError(try makeShareItem(displayName: "some name.pdf"))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }

    func test_removeTemporaryFiles_shouldRemoveExportAndPreserveSource() throws {
        let testee = try makeShareItem(displayName: "some name.pdf")
        let exportDirectory = testee.url.deletingLastPathComponent()

        testee.removeTemporaryFiles()
        testee.removeTemporaryFiles()

        XCTAssertEqual(FileManager.default.fileExists(atPath: exportDirectory.path), false)
        XCTAssertEqual(try Data(contentsOf: sourceURL), sourceData)
    }

    func test_deinit_shouldRemoveAbandonedExport() throws {
        var testee: FileShareItem? = try makeShareItem(displayName: "some name.pdf")
        let exportDirectory = try XCTUnwrap(testee?.url.deletingLastPathComponent())
        XCTAssertEqual(FileManager.default.fileExists(atPath: exportDirectory.path), true)

        testee = nil

        XCTAssertEqual(FileManager.default.fileExists(atPath: exportDirectory.path), false)
        XCTAssertEqual(try Data(contentsOf: sourceURL), sourceData)
    }

    // MARK: - Private helpers

    private func makeShareItem(displayName: String?) throws -> FileShareItem {
        try FileShareItem(sourceURL: sourceURL, displayName: displayName, temporaryDirectory: directory)
    }
}
