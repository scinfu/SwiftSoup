#if !COCOAPODS
import libc
#endif

/// This function will attempt to get the current
/// working directory of the application
public func workingDirectory() -> String {
    let fileBasedWorkDir: String?
    
    #if Xcode
    // attempt to find working directory through #file
    let file = #file
        
    if file.contains(".build") {
        // most dependencies are in `./.build/`
        fileBasedWorkDir = file.components(separatedBy: "/.build").first
    } else if file.contains("Packages") {
        // when editing a dependency, it is in `./Packages/`
        fileBasedWorkDir = file.components(separatedBy: "/Packages").first
    } else {
        // when dealing with current repository, file is in `./Sources/`
        fileBasedWorkDir = file.components(separatedBy: "/Sources").first
    }
    #else
        fileBasedWorkDir = nil
    #endif
    
    let workDir: String
    if let fileBasedWorkDir = fileBasedWorkDir {
        workDir = fileBasedWorkDir
    } else {
        // get actual working directory
        let cwd = getcwd(nil, Int(PATH_MAX))
        defer {
            free(cwd)
        }
        
        if let cwd = cwd, let string = String(validatingUTF8: cwd) {
            workDir = string
        } else {
            workDir = "./"
        }
    }
    
    return workDir.finished(with: "/")
}
