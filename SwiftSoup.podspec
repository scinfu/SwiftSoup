Pod::Spec.new do |s|
  s.name             = 'SwiftSoup'
  s.version          = '2.7.3'
  s.summary          = 'Swift HTML Parser / Reader, XML , with best of DOM, CSS, and jquery'
  s.description      = <<-DESC
SwiftSoup is a Swift library for working with real-world HTML. It provides a very convenient API for extracting and manipulating data, using the best of DOM, CSS, and jquery-like methods.
                       DESC

  s.homepage         = 'https://github.com/scinfu/SwiftSoup'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Nabil Chatbi' => 'scinfu@gmail.com' }
  s.source           = { :git => 'https://github.com/scinfu/SwiftSoup.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/scinfu'

  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.13'
  s.watchos.deployment_target = '4.0'
  s.tvos.deployment_target = '12.0'

  s.source_files = 'Sources/**/*.swift'
  s.swift_versions = ['4.0', '4.2', '5.0', '5.1']

  s.ios.resource_bundles = {'SwiftSoup' => ['Sources/PrivacyInfo.xcprivacy']}
  s.osx.resource_bundles = {'SwiftSoup' => ['Sources/PrivacyInfo.xcprivacy']}
  s.watchos.resource_bundles = {'SwiftSoup' => ['Sources/PrivacyInfo.xcprivacy']}
  s.tvos.resource_bundles = {'SwiftSoup' => ['Sources/PrivacyInfo.xcprivacy']}
end
