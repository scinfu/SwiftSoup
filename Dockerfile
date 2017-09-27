FROM swiftdocker/swift:latest

WORKDIR /package

COPY . ./

RUN swift --version
RUN swift swift package tools-version
RUN swift package resolve
RUN swift package clean
CMD swift test
