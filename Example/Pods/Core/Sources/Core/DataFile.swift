import Foundation

/// Basic Foundation implementation of FileProtocols
public final class DataFile: FileProtocol {
    /// Working directory will be used when relative
    /// paths are supplied
    public let workDir: String
    
    /// Creates a DataFile instance with optional workdir.
    public init(workDir: String) {
        self.workDir = workDir
    }
    
    /// @see - FileProtocol.load
    public func read(at path: String) throws -> Bytes {
        let path = makeAbsolute(path: path)
        guard let data = NSData(contentsOfFile: path) else {
            throw DataFileError.load(path: path)
        }
        
        var bytes = Bytes(repeating: 0, count: data.length)
        data.getBytes(&bytes, length: bytes.count)
        return bytes
    }
    
    /// @see - FileProtocol.save
    public func write(_ bytes: Bytes, to path: String) throws {
        let path = makeAbsolute(path: path)
        if !fileExists(at: path) {
            try create(at: path, bytes: bytes)
        } else {
            try write(to: path, bytes: bytes)
        }
    }
    
    /// @see - FileProtocol.delete
    public func delete(at path: String) throws {
        let path = makeAbsolute(path: path)
        try FileManager.default.removeItem(atPath: path)
    }
    
    // MARK: Private
    
    private func makeAbsolute(path: String) -> String {
        return path.hasPrefix("/") ? path : workDir + path
    }
    
    private func create(at path: String, bytes: Bytes) throws {
        let data = Data(bytes: bytes)
        let success = FileManager.default.createFile(
            atPath: path,
            contents: data,
            attributes: nil
        )
        guard success else { throw DataFileError.create(path: path) }
    }
    
    private func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    private func write(to path: String, bytes: Bytes) throws {
        let bytes = Data(bytes: bytes)
        
        let url = URL(fileURLWithPath: path)
        try bytes.write(to: url)
    }
}

extension DataFile: EmptyInitializable {
    public convenience init() {
        self.init(workDir: workingDirectory())
    }
}

// MARK: Error

public enum DataFileError: Error {
    case create(path: String)
    case load(path: String)
    case unspecified(Swift.Error)
}

extension DataFileError: Debuggable {
    public var identifier: String {
        switch self {
        case .create:
            return "create"
        case .load:
            return "load"
        case .unspecified:
            return "unspecified"
        }
    }
    
    public var reason: String {
        switch self {
        case .create(let path):
            return "unable to create the file at path \(path)"
        case .load(let path):
            return "unable to load file at path \(path)"
        case .unspecified(let error):
            return "received an unspecified or extended error: \(error)"
        }
    }
    
    public var possibleCauses: [String] {
        switch self {
        case .create:
            return [
                "missing write permissions at specified path",
                "attempted to write corrupted data",
                "system issue"
            ]
        case .load:
            return [
                "file doesn't exist",
                "missing read permissions at specified path",
                "data read is corrupted",
                "system issue"
            ]
        case .unspecified:
            return [
                "received an error not originally supported by this version"
            ]
        }
    }
    
    public var suggestedFixes: [String] {
        return [
            "ensure that file permissions are correct for specified paths"
        ]
    }
    
    public var documentationLinks: [String] {
        return [
            "https://developer.apple.com/reference/foundation/filemanager",
        ]
    }
}
