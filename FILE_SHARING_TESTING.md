# Testing readable export filenames

Branch: `fix/readable-shared-filenames` in <https://github.com/aw-0/canvas-ios>.

Sharing from the file details screen now copies the current local file into an
isolated temporary directory using Canvas's `display_name`. The download and
annotation paths stay the same. Export copies are removed when sharing completes
or the share controller releases its completion handler.

## Build the test app on a Mac

You need a Mac with Xcode and an iPhone or iPad running iOS/iPadOS 18 or later.
The repository's CI currently selects Xcode 26.4. You cannot apply this patch to
the App Store installation; testing the share sheet requires a custom build.

```sh
git clone --branch fix/readable-shared-filenames https://github.com/aw-0/canvas-ios.git
cd canvas-ios
make provision
make sync
open Canvas.xcworkspace
```

`make provision` installs the Homebrew dependencies and creates placeholder
Firebase configuration files. Let Xcode resolve the Swift packages. Select the
`Student` scheme and your connected device.

For a personal device build, configure Signing & Capabilities with your own
development team and unique bundle identifiers for `Student`, `SubmitAssignment`,
and `Widgets`. The checked-in signing settings and entitlements belong to
Instructure. App Groups, iCloud, push notifications, associated domains, and Siri
may require provisioning changes or removal in your local test build. Any groups
you retain must use identifiers registered to your team and match the app and
extensions. These local signing changes are separate from the filename fix.
Enable Developer Mode on the device if Xcode requests it, then build and run.

PDF annotation uses the commercial PSPDFKit/Nutrient SDK. Instructure's license
is not included. Without a configured license, the file details code falls back
to a web preview for PDFs; basic file sharing can still be tested. Testing saved
annotations requires an appropriate SDK license for your test bundle identifier.
The repository documents generating the license asset with
`yarn build-secrets studentPSPDFKitLicense=<your-license>`.

## Run the automated regression tests

In Xcode, select the `CITests` scheme, choose the newest installed iOS simulator,
and run these test classes from the Test navigator:

- `CoreTests/FileShareItemTests`
- `CoreTests/FileDetailsViewControllerTests`

Alternatively, substitute an installed simulator's identifier below:

```sh
xcrun simctl list devices available
xcodebuild \
  -workspace Canvas.xcworkspace \
  -scheme CITests \
  -destination 'platform=iOS Simulator,id=YOUR-SIMULATOR-UUID' \
  -only-testing:CoreTests/FileShareItemTests \
  -only-testing:CoreTests/FileDetailsViewControllerTests \
  test
```

The tests cover readable names, literal percent escapes, missing names and
extensions, Unicode byte limits, unsafe path characters, independent repeated
exports, copy failures, cleanup, and preserving the original file's bytes.

### Run the filename tests without the iOS app

With a Swift toolchain installed on Linux or macOS, run the following from the
repository root. It creates a temporary Swift package containing the unchanged
production helper and its XCTest file. This verifies file creation and naming;
it does not build the iOS controller or test another app's share extension.

```sh
(
  set -eu
  verification_dir="$(mktemp -d)"
  trap 'rm -rf "$verification_dir"' EXIT
  mkdir -p "$verification_dir/Sources/Core" "$verification_dir/Tests/CoreTests"
  cp Core/Core/Features/Files/Model/FileShareItem.swift "$verification_dir/Sources/Core/"
  cp Core/CoreTests/Features/Files/Model/FileShareItemTests.swift "$verification_dir/Tests/CoreTests/"
  cat > "$verification_dir/Package.swift" <<'EOF'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "CanvasFileShareVerification",
    targets: [
        .target(name: "Core"),
        .testTarget(name: "CoreTests", dependencies: ["Core"])
    ]
)
EOF
  swift test --package-path "$verification_dir"
)
```

## Test the share sheet on your device

1. Install Notability and sign into Canvas in the custom Student build.
2. Upload a valid PDF to a Canvas course where you can access Files. Name it
   `Lecture 1 (review).pdf`. Use Canvas's file rename control if necessary so
   this is the name shown in the app.
3. Open the PDF from the course's Files screen. Wait for loading to finish, tap
   the share button, and choose **Save to Files**. Confirm the resulting filename
   is `Lecture 1 (review).pdf`, with readable spaces and parentheses.
4. Share the same file directly to **Notability**. Confirm its import preview and
   resulting note have a readable name, and confirm the document opens correctly.
   Notability may omit the `.pdf` suffix in the note title.
5. Repeat with `100% + café (2).pdf` and `Literal %20 and %28.pdf`. Literal `%20`
   and `%28` in the second name must stay literal rather than turn into spaces
   and parentheses. This distinguishes using the display name from blindly
   decoding a filename.
6. Rename a file in Canvas and share it again. The export should reflect the name
   currently displayed after refreshing the file details screen. Repeat with a
   PNG or PPTX to check that file types and extensions remain usable.
7. Cancel the share sheet, reopen it, and export the same file twice. Both imports
   should work; the receiving app may apply its own duplicate-name suffix.
8. With a licensed annotation build, add an annotation in Canvas, export to
   Notability and Files, and confirm the annotation appears. Reopen the original
   in Canvas and confirm the saved annotation is still present.

For comparison, repeat steps 2–4 in the App Store version with a file that
currently exhibits the problem. If Files receives a readable name but only
Notability displays escapes in the patched build, record the two apps' versions
and the exact names: that would indicate additional receiving-app handling.

## Validation performed for this change

The unchanged `FileShareItem.swift` and `FileShareItemTests.swift` files compiled
in a temporary standalone Swift package with Swift 6.1.3 on Linux. All 12 XCTest
tests passed with zero failures. All four changed Swift files also passed a
Tree-sitter Swift syntax parse; `git diff --check` and the repository's copyright
check passed.

Xcode, the iOS SDK, XcodeGen, and SwiftLint are not installed on the development
machine. `make sync` was attempted and stopped because `xcodegen` was unavailable.
The full iOS build, `FileDetailsViewControllerTests`, and physical-device
share-sheet checks still need to run on a Mac/device before treating this as
verified for release. The standalone tests do not establish compatibility with
Notability's share extension or verify PDF annotation integration.
