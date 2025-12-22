import Foundation
import SwiftSoup

struct Options {
    var fixturesPath: String
    var includeText: Bool
}

func parseOptions() -> Options {
    let args = ProcessInfo.processInfo.arguments
    var fixturesPath = ProcessInfo.processInfo.environment["READABILITY_FIXTURES"]
    var includeText = false

    var i = 1
    while i < args.count {
        let arg = args[i]
        if arg == "--fixtures", i + 1 < args.count {
            fixturesPath = args[i + 1]
            i += 2
            continue
        } else if arg == "--text" {
            includeText = true
        }
        i += 1
    }

    if fixturesPath == nil || fixturesPath!.isEmpty {
        fixturesPath = "/Users/alex/Code/lake-of-fire/swift-readability/Tests/SwiftReadabilityTests/Fixtures"
    }

    return Options(fixturesPath: fixturesPath!, includeText: includeText)
}

func findSourceHTMLFiles(fixturesPath: String) -> [URL] {
    let root = URL(fileURLWithPath: fixturesPath)
    let testPages = root.appendingPathComponent("test-pages", isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(
        at: testPages,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    var files: [URL] = []
    for case let url as URL in enumerator {
        if url.lastPathComponent == "source.html" {
            files.append(url)
        }
    }
    return files.sorted { $0.path < $1.path }
}

let options = parseOptions()
let files = findSourceHTMLFiles(fixturesPath: options.fixturesPath)

if files.isEmpty {
    fputs("No source.html files found under: \(options.fixturesPath)\n", stderr)
    exit(1)
}

Profiler.reset()

let start = CFAbsoluteTimeGetCurrent()
var totalBytes = 0
var parsedCount = 0

for url in files {
    autoreleasepool {
        do {
            let data = try Data(contentsOf: url)
            totalBytes += data.count
            let doc = try SwiftSoup.parse(data, "")
            if options.includeText {
                _ = try doc.text()
            }
            parsedCount += 1
        } catch {
            fputs("Error parsing \(url.path): \(error)\n", stderr)
        }
    }
}

let total = CFAbsoluteTimeGetCurrent() - start
let mb = Double(totalBytes) / (1024.0 * 1024.0)

print("Parsed \(parsedCount) files, \(String(format: "%.2f", mb)) MB in \(String(format: "%.2f", total)) s")
print(Profiler.report(top: 40))
