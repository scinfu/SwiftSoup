/// `Debuggable` provides an interface that allows a type
/// to be more easily debugged in the case of an error.
public protocol Debuggable: Swift.Error, CustomDebugStringConvertible {
    /// A readable name for the error's Type. This is usually
    /// similar to the Type name of the error with spaces added.
    /// This will normally be printed proceeding the error's reason.
    /// - note: For example, an error named `FooError` will have the
    /// `readableName` `"Foo Error"`.
    static var readableName: String { get }

    /// The reason for the error.
    /// Typical implementations will switch over `self`
    /// and return a friendly `String` describing the error.
    /// - note: It is most convenient that `self` be a `Swift.Error`.
    ///
    /// Here is one way to do this:
    ///
    ///     switch self {
    ///     case someError:
    ///        return "A `String` describing what went wrong including the actual error: `Error.someError`."
    ///     // other cases
    ///     }
    var reason: String { get }

    // MARK: Identifiers

    /// A unique identifier for the error's Type.
    /// - note: This defaults to `ModuleName.TypeName`,
    /// and is used to create the `identifier` property.
    static var typeIdentifier: String { get }
    
    /// Some unique identifier for this specific error.
    /// This will be used to create the `identifier` property.
    /// Do NOT use `String(reflecting: self)` or `String(describing: self)`
    /// or there will be infinite recursion
    var identifier: String { get }

    // MARK: Help
    
    /// A `String` array describing the possible causes of the error.
    /// - note: Defaults to an empty array.
    /// Provide a custom implementation to give more context.
    var possibleCauses: [String] { get }
    
    /// A `String` array listing some common fixes for the error.
    /// - note: Defaults to an empty array.
    /// Provide a custom implementation to be more helpful.
    var suggestedFixes: [String] { get }
    
    /// An array of string `URL`s linking to documentation pertaining to the error.
    /// - note: Defaults to an empty array.
    /// Provide a custom implementation with relevant links.
    var documentationLinks: [String] { get }
    
    /// An array of string `URL`s linking to related Stack Overflow questions.
    /// - note: Defaults to an empty array.
    /// Provide a custom implementation to link to useful questions.
    var stackOverflowQuestions: [String] { get }
    
    /// An array of string `URL`s linking to related issues on Vapor's GitHub repo.
    /// - note: Defaults to an empty array.
    /// Provide a custom implementation to a list of pertinent issues.
    var gitHubIssues: [String] { get }
}

// MARK: Optionals

extension Debuggable {
    public var documentationLinks: [String] {
        return []
    }
    
    public var stackOverflowQuestions: [String] {
        return []
    }
    
    public var gitHubIssues: [String] {
        return []
    }
}

extension Debuggable {
    public var fullIdentifier: String {
        return Self.typeIdentifier + "." + identifier
    }
}

// MARK: Defaults

extension Debuggable {
    /// Default implementation of readable name that expands
    /// SomeModule.MyType.Error => My Type Error
    public static var readableName: String {
        return typeIdentifier.readableTypeName()
    }

    public static var typeIdentifier: String {
        return String(reflecting: self)
    }

    public var debugDescription: String {
        return printable
    }
}

extension String {
    func readableTypeName() -> String {
        let characterSequence = self.characters
            .split(separator: ".")
            .dropFirst() // drop module
            .joined(separator: [])

        let characters = Array(characterSequence)
        guard var expanded = characters.first.flatMap({ String($0) }) else { return "" }
        
        characters.suffix(from: 1).forEach { char in
            if char.isUppercase {
                expanded.append(" ")
            }

            expanded.append(char)
        }

        return expanded
    }
}

extension Character {
    var isUppercase: Bool {
        switch self {
        case "A"..."Z":
            return true
        default:
            return false
        }
    }
}


// MARK: Representations

extension Debuggable {
    /// A computed property returning a `String` that encapsulates
    /// why the error occurred, suggestions on how to fix the problem,
    /// and resources to consult in debugging (if these are available).
    /// - note: This representation is best used with functions like print()
    public var printable: String {
        var print: [String] = []

        print.append("\(Self.readableName): \(reason)")
        print.append("Identifier: \(fullIdentifier)")

        if !possibleCauses.isEmpty {
            print.append("Here are some possible causes: \(possibleCauses.bulletedList)")
        }

        if !suggestedFixes.isEmpty {
            print.append("These suggestions could address the issue: \(suggestedFixes.bulletedList)")
        }

        if !documentationLinks.isEmpty {
            print.append("Vapor's documentation talks about this: \(documentationLinks.bulletedList)")
        }

        if !stackOverflowQuestions.isEmpty {
            print.append("These Stack Overflow links might be helpful: \(stackOverflowQuestions.bulletedList)")
        }

        if !gitHubIssues.isEmpty {
            print.append("See these Github issues for discussion on this topic: \(gitHubIssues.bulletedList)")
        }

        return print.joined(separator: "\n\n")
    }
}

extension Sequence where Iterator.Element == String {
    var bulletedList: String {
        return map { "\n- \($0)" } .joined()
    }
}
