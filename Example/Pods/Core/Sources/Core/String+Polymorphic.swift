extension String {
    /// Determines whether or not the `String` is null.
    /// Returns `true` if the `String` is equal to `"null"`.
    public var isNull: Bool {
        return self.lowercased() == "null"
    }

    /// Attempts to convert the String to a `Bool`.
    /// The conversion **may** succeed if the `String`
    /// has a truthy/falsey value like `"yes"` or `"false"`
    /// All others will always return `nil`.
    public var bool: Bool? {
        switch lowercased() {
        case "y", "1", "yes", "t", "true", "on":
            return true
        case "n", "0", "no", "f", "false", "off":
            return false
        default:
            return nil
        }
    }

    /// Attempts to convert the `String` to a `Float`.
    /// The conversion uses the `Float(_: String)` initializer.
    public var float: Float? {
        return Float(self)
    }

    /// Attempts to convert the `String` to a `Double`.
    /// The conversion uses the `Double(_: String)` initializer.
    public var double: Double? {
        return Double(self)
    }

    /// Attempts to convert the `String` to a `Int`.
    /// The conversion uses the `Int(_: String)` initializer.
    public var int: Int? {
        return Int(self)
    }

    /// Attempts to convert the `String` to a `UInt`.
    /// The conversion uses the `UInt(_: String)` initializer.
    public var uint: UInt? {
        return UInt(self)
    }

    /// Attempts to convert the `String` to a `String`.
    /// This always works.
    public var string: String {
        return self
    }

    /// Converts the string to a UTF8 array of bytes.
    public var bytes: [UInt8] {
        return [UInt8](self.utf8)
    }
}

extension String {
    /// Attempts to convert the `String` to an `Array`.
    /// Comma separated items will be split into
    /// multiple entries.
    public func commaSeparatedArray() -> [String] {
        return characters
            .split(separator: ",")
            .map { String($0) }
            .map { $0.trimmedWhitespace() }
    }
}

extension String {
    fileprivate func trimmedWhitespace() -> String {
        var characters = self.characters

        while characters.first?.isWhitespace == true {
            characters.removeFirst()
        }
        while characters.last?.isWhitespace == true {
            characters.removeLast()
        }

        return String(characters)
    }
}

extension Character {
    fileprivate var isWhitespace: Bool {
        switch self {
        case " ", "\t", "\n", "\r":
            return true
        default:
            return false
        }
    }
}
