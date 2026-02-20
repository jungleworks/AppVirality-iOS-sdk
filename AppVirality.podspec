Pod::Spec.new do |s|

  s.name         = "AppVirality"
  s.version      = "2.0.0"
  s.summary      = "Modernized AppVirality Objective-C SDK"
  s.description  = "Patched AppVirality SDK compatible with latest iOS versions (UIWebView removed, NSURLSession used)."

  s.homepage     = "https://github.com/jungleworks/AppVirality-iOS-sdk"
  s.license      = { :type => "MIT" }
  s.author       = { "Neha" => "neha.vaish@jungleworks.com" }

  s.platform     = :ios, "13.0"

  s.source       = { :path => "." }

  s.source_files = "*.{h,m}"
  s.public_header_files = "*.h"

  s.frameworks = "UIKit", "Foundation", "WebKit", "Security", "SystemConfiguration"

  # ARC for all EXCEPT Keychain file
  s.requires_arc = true
  s.compiler_flags = '-fobjc-arc'

  s.subspec 'NoARC' do |ss|
    ss.source_files = 'SFHFKeychainUtils.m'
    ss.requires_arc = false
  end

end
