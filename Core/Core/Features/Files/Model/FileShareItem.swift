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

import Foundation

final class FileShareItem {
    let url: URL
    private let directory: URL

    init(sourceURL: URL, displayName: String?, temporaryDirectory: URL = FileManager.default.temporaryDirectory) throws {
        directory = temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        url = directory.appendingPathComponent(Self.fileName(displayName: displayName, sourceURL: sourceURL))

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: sourceURL, to: url)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    deinit {
        removeTemporaryFiles()
    }

    func removeTemporaryFiles() {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func fileName(displayName: String?, sourceURL: URL) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:").union(.controlCharacters)
        var name = (displayName ?? sourceURL.lastPathComponent)
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "." || name == ".." {
            name = sourceURL.lastPathComponent
        }

        let sourceExtension = sourceURL.pathExtension
        if !sourceExtension.isEmpty,
           (name as NSString).pathExtension.caseInsensitiveCompare(sourceExtension) != .orderedSame {
            name += "." + sourceExtension
        }

        let pathExtension = (name as NSString).pathExtension
        let suffix = sourceExtension.isEmpty || pathExtension.utf8.count >= 255 ? "" : "." + pathExtension
        var baseName = suffix.isEmpty ? name : (name as NSString).deletingPathExtension
        while baseName.utf8.count + suffix.utf8.count > 255 {
            baseName.removeLast()
        }
        return baseName + suffix
    }
}
