/// Types conforming to this protocol can store
/// arbitrary key-value data.
/// 
/// Extensions can utilize this arbitrary data store
/// to simulate optional stored properties.
public protocol Extendable {
    /// Arbitrary key-value data store.
    var extend: [String: Any] { get set }
}
