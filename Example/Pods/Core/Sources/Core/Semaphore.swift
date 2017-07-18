import Dispatch

extension DispatchSemaphore {
    /**
        Wait for a specified time in SECONDS
        timeout if necessary
    */
    public func wait(timeout: Double) -> DispatchTimeoutResult {
        let time = DispatchTime(secondsFromNow: timeout)
        return wait(timeout: time)
    }
}
