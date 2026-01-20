import Foundation
import SwiftSoup

func writeStderr(_ message: String) {
    if let data = message.data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

#if canImport(Darwin)
func withAutoreleasepool(_ body: () throws -> Void) rethrows {
    try autoreleasepool {
        try body()
    }
}
#else
func withAutoreleasepool(_ body: () throws -> Void) rethrows {
    try body()
}
#endif

struct Options {
    var fixturesPath: String
    var includeText: Bool
    var includeInnerHtml: Bool
    var selectQuery: String?
    var selectQueries: [String]?
    var selectIterations: Int
    var backend: Parser.Backend
    var skipFallbacks: Bool
    var prettyPrint: Bool?
    var applyDefaultWorkload: Bool
    var applyLibxml2FastWorkload: Bool
    var applyLibxml2SimpleWorkload: Bool
}

func parseOptions() -> Options {
    let args = ProcessInfo.processInfo.arguments
    var fixturesPath = ProcessInfo.processInfo.environment["READABILITY_FIXTURES"]
    var includeText = false
    var includeInnerHtml = false
    var selectQuery: String? = nil
    var selectQueries: [String]? = nil
    var selectIterations = 1
    var backend: Parser.Backend = .swiftSoup
    var skipFallbacks = false
    var prettyPrint: Bool? = nil
    var applyDefaultWorkload = false
    var applyLibxml2FastWorkload = false
    var applyLibxml2SimpleWorkload = false

    var i = 1
    while i < args.count {
        let arg = args[i]
        if arg == "--fixtures", i + 1 < args.count {
            fixturesPath = args[i + 1]
            i += 2
            continue
        } else if arg == "--text" {
            includeText = true
        } else if arg == "--html" {
            includeInnerHtml = true
        } else if arg == "--backend", i + 1 < args.count {
            let value = args[i + 1].lowercased()
            switch value {
            case "swiftsoup", "default":
                backend = .swiftSoup
#if canImport(CLibxml2) || canImport(libxml2)
            case "libxml2":
                backend = .libxml2(
                    swiftSoupParityMode: skipFallbacks ? .libxml2Only : .swiftSoupParity
                )
#endif
            default:
                writeStderr("Unknown backend: \(value)\n")
                exit(1)
            }
            i += 2
            continue
        } else if arg == "--skip-fallbacks" {
            skipFallbacks = true
            if case .libxml2 = backend {
                backend = .libxml2(swiftSoupParityMode: .libxml2Only)
            }
            i += 1
            continue
        } else if arg == "--pretty-print" {
            prettyPrint = true
            i += 1
            continue
        } else if arg == "--no-pretty-print" {
            prettyPrint = false
            i += 1
            continue
        } else if arg == "--select", i + 1 < args.count {
            selectQuery = args[i + 1]
            i += 2
            continue
        } else if arg == "--select-queries", i + 1 < args.count {
            let raw = args[i + 1]
            let parsed = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            selectQueries = parsed.filter { !$0.isEmpty }
            i += 2
            continue
        } else if arg == "--select-iterations", i + 1 < args.count {
            if let parsed = Int(args[i + 1]), parsed > 0 {
                selectIterations = parsed
            }
            i += 2
            continue
        } else if arg == "--workload-defaults" {
            applyDefaultWorkload = true
            i += 1
            continue
        } else if arg == "--workload-libxml2-fast" {
            applyLibxml2FastWorkload = true
            i += 1
            continue
        } else if arg == "--workload-libxml2-simple" {
            applyLibxml2SimpleWorkload = true
            i += 1
            continue
        }
        i += 1
    }

    if fixturesPath == nil || fixturesPath!.isEmpty {
        fixturesPath = "/Users/alex/Code/lake-of-fire/swift-readability/Tests/SwiftReadabilityTests/Fixtures"
    }

    if applyDefaultWorkload {
        includeText = true
        includeInnerHtml = true
        if selectQuery == nil && selectQueries == nil {
            selectQuery = "article,main,div.content,p,a,span"
        }
        if selectIterations < 10 {
            selectIterations = 10
        }
    }

    if applyLibxml2FastWorkload {
        includeText = true
        includeInnerHtml = true
        if selectQuery == nil && selectQueries == nil {
            selectQueries = [
                "article,main,div.content",
                "a[href],img[src],link[rel],meta[name]",
                "div[class],span[class]",
                "p,li,td,th",
                "table td,table th",
                "ul li,ol li"
            ]
        }
        if selectIterations < 25 {
            selectIterations = 25
        }
    }

    if applyLibxml2SimpleWorkload {
        includeText = true
        includeInnerHtml = true
        if selectQuery == nil && selectQueries == nil {
            selectQueries = [
                "article",
                "main",
                "div.content",
                "#content",
                ".content",
                "a[href]",
                "img[src]"
            ]
        }
        if selectIterations < 50 {
            selectIterations = 50
        }
    }

    return Options(
        fixturesPath: fixturesPath!,
        includeText: includeText,
        includeInnerHtml: includeInnerHtml,
        selectQuery: selectQuery,
        selectQueries: selectQueries,
        selectIterations: selectIterations,
        backend: backend,
        skipFallbacks: skipFallbacks,
        prettyPrint: prettyPrint,
        applyDefaultWorkload: applyDefaultWorkload,
        applyLibxml2FastWorkload: applyLibxml2FastWorkload,
        applyLibxml2SimpleWorkload: applyLibxml2SimpleWorkload
    )
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
    writeStderr("No source.html files found under: \(options.fixturesPath)\n")
    exit(1)
}

Profiler.reset()

let start = Date()
var totalBytes = 0
var parsedCount = 0
var totalParseTime: TimeInterval = 0
var totalSelectTime: TimeInterval = 0
var totalTextTime: TimeInterval = 0
var totalHtmlTime: TimeInterval = 0

let resolvedSelectQueries: [String]? = {
    if let queries = options.selectQueries, !queries.isEmpty {
        return queries
    }
    if let query = options.selectQuery {
        return [query]
    }
    return nil
}()
var selectQueryTimes: [TimeInterval]? = resolvedSelectQueries?.map { _ in 0 }

for url in files {
    withAutoreleasepool {
        do {
            let data = try Data(contentsOf: url)
            totalBytes += data.count
            let parseStart = Date()
            let doc = try SwiftSoup.parse(data, "", backend: options.backend)
            if let prettyPrint = options.prettyPrint {
                doc.outputSettings().prettyPrint(pretty: prettyPrint)
            }
            totalParseTime += Date().timeIntervalSince(parseStart)
            if options.includeText {
                let textStart = Date()
                _ = try doc.text()
                totalTextTime += Date().timeIntervalSince(textStart)
            }
            if options.includeInnerHtml {
                let htmlStart = Date()
                _ = try doc.body()?.html()
                totalHtmlTime += Date().timeIntervalSince(htmlStart)
            }
            if let queries = resolvedSelectQueries {
                for (index, query) in queries.enumerated() {
                    let selectStart = Date()
                    if options.selectIterations == 1 {
                        _ = try doc.select(query)
                    } else {
                        var iter = 0
                        while iter < options.selectIterations {
                            _ = try doc.select(query)
                            iter += 1
                        }
                    }
                    let elapsed = Date().timeIntervalSince(selectStart)
                    totalSelectTime += elapsed
                    if selectQueryTimes != nil {
                        selectQueryTimes![index] += elapsed
                    }
                }
            }
            parsedCount += 1
        } catch {
            writeStderr("Error parsing \(url.path): \(error)\n")
        }
    }
}

let total = Date().timeIntervalSince(start)
let mb = Double(totalBytes) / (1024.0 * 1024.0)

print("Parsed \(parsedCount) files, \(String(format: "%.2f", mb)) MB in \(String(format: "%.2f", total)) s")
print("Parse time: \(String(format: "%.2f", totalParseTime)) s")
if options.includeText {
    print("Text time: \(String(format: "%.2f", totalTextTime)) s")
}
if options.includeInnerHtml {
    print("HTML time: \(String(format: "%.2f", totalHtmlTime)) s")
}
if let queries = resolvedSelectQueries {
    if let perQuery = selectQueryTimes, options.selectQueries != nil {
        for (index, query) in queries.enumerated() {
            print("Select time (\(query)): \(String(format: "%.2f", perQuery[index])) s")
        }
    }
    print("Select time: \(String(format: "%.2f", totalSelectTime)) s")
}
print(Profiler.report(top: 40))
