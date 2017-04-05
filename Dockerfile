FROM swift:3.1

WORKDIR /package

COPY . ./

RUN swift package fetch
# swift package clean requires Swift 3.1 or later.
# Use swift build --clean for Swift 3.0 compatibility.
RUN swift package clean
CMD swift test