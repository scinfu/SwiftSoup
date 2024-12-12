import Foundation

public struct ParsingStrings {
    var singleByteLookup: [Bool]
    var multiByteChars: [[UInt8]]
    var multiByteCharLengths: [Int]
    
    init(_ strings: [String]) {
        self.init(strings.map { str -> [UInt8] in
            return str.utf8Array
        })
    }
    
    init(_ strings: [[UInt8]]) {
        singleByteLookup = [Bool](repeating: false, count: 256)
        multiByteChars = []
        multiByteCharLengths = []
        
        for utf8Array in strings {
            if utf8Array.count == 1 {
                singleByteLookup[Int(utf8Array[0])] = true
            } else {
                multiByteChars.append(utf8Array)
                multiByteCharLengths.append(utf8Array.count)
            }
        }
    }
    
    init(_ strings: [UnicodeScalar]) {
        self.init(strings.map { Array($0.utf8) })
    }
    
    func contains(_ string: [UInt8]) -> Bool {
        if string.count == 1 {
            return singleByteLookup[Int(string[0])]
        } else {
            for (index, multiByteChar) in multiByteChars.enumerated() {
                if multiByteCharLengths[index] == string.count && multiByteChar.elementsEqual(string) {
                    return true
                }
            }
            return false
        }
    }
}
