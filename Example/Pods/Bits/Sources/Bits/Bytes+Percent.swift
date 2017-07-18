import Foundation

extension Sequence where Iterator.Element == Byte {
    public var percentDecoded: Bytes {
        return makeString()
            .removingPercentEncoding?
            .makeBytes() ?? []
    }
    
    public var percentEncodedForURLQuery: Bytes {
        return makeString()
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .makeBytes() ?? []
    }
    
    public var percentEncodedForURLPath: Bytes {
        return makeString()
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?
            .makeBytes() ?? []
    }
    
    public var percentEncodedForURLHost: Bytes {
        return makeString()
            .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)?
            .makeBytes() ?? []
    }
    
    public var percentEncodedForURLFragment: Bytes {
        return makeString()
            .addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)?
            .makeBytes() ?? []
    }
}
