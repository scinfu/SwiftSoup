import Dispatch

/**
    A simple background function that uses dispatch to send to a global queue
*/
public func background(function: @escaping () -> Void) {
    DispatchQueue.global().async(execute: function)
}
