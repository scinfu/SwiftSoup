extension String {
    /**
        Ensures a string has a strailing suffix w/o duplicating
     
        "hello.jpg".finished(with: ".jpg") 
        // == 'hello.jpg'
     
        "hello".finished(with: ".jpg")
        // == 'hello.jpg'
    */
    public func finished(with end: String) -> String {
        guard !self.hasSuffix(end) else { return self }
        return self + end
    }
}
