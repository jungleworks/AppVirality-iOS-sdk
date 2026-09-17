Pod::Spec.new do |s|

  s.name         = "AppVirality"
  s.version      = "2.0.5"
  s.summary      = "Modernized AppVirality Objective-C SDK"
  s.description  = "Patched AppVirality SDK compatible with latest iOS versions (UIWebView removed, NSURLSession used)."

  s.homepage     = "https://github.com/jungleworks/AppVirality-iOS-sdk"
  s.license      = { :type => "MIT" }
  s.author       = { "Neha" => "neha.vaish@jungleworks.com" }

  s.platform     = :ios, "13.0"

  s.source       = { :path => "." }

  s.source_files = "*.{h,m}"
  s.public_header_files = "*.h"

  s.frameworks = "UIKit", "Foundation", "WebKit", "Security", "SystemConfiguration", "SafariServices", "CoreImage"

  # ARC for all EXCEPT Keychain file (SFHFKeychainUtils.m uses manual retain/release,
  # so CocoaPods compiles it with -fno-objc-arc). Every new .m file must be listed here.
  s.requires_arc = ["AppVirality.m", "Utility.m", "NSObject+BKBlockExecution.m", "AVQRCodeViewController.m"]

end
