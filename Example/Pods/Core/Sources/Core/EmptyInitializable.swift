/// Types conforming to this protocol can 
/// be initialized with no arguments, allowing
/// protocols to add static convenience methods.
public protocol EmptyInitializable {
    init() throws
}
