import Foundation
import Dispatch

extension Double {
    internal var nanoseconds: UInt64 {
        return UInt64(self * Double(1_000_000_000))
    }
}

extension DispatchTime {
    /**
        Create a dispatch time for a given seconds from now.
    */
    public init(secondsFromNow: Double) {
        let uptime = DispatchTime.now().rawValue + secondsFromNow.nanoseconds
        self.init(uptimeNanoseconds: uptime)
    }
}
