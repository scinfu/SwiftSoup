FROM swiftdocker/swift:latest

WORKDIR /package

COPY . ./

RUN swift --version
RUN swift package tools-version --set 3.2
RUN swift package resolve
RUN swift package clean
RUN swift test
RUN swift package tools-version --set 4.0
RUN swift package resolve
RUN swift package clean
CMD swift test

