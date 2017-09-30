Pod::Spec.new do |s|
  s.name         = "EBIMobileDeviceWatcher"
  s.version      = "0.1.1"
  s.summary      = "Observe iOS/Android device connect/disconnect on macOS."
  s.homepage     = "https://github.com/iseebi/EBIMobileDeviceWatcher"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Nobuhiro Ito" => "iseebi@iseteki.net" }
  s.social_media_url = "https://twitter.com/iseebi"
  s.platform     = :osx, "10.10"
  s.source       = { :git => "https://github.com/iseebi/EBIMobileDeviceWatcher.git", :tag => "#{s.version}" }
  s.source_files  = "Classes", "Classes/**/*.{h,m}"
  s.public_header_files = "Classes/**/*.h"
  s.framework  = "IOKit"
end
