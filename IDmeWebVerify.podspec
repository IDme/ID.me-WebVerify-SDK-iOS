Pod::Spec.new do |s|
  s.name         = "IDmeWebVerify"
  s.version      = "4.0.3"
  s.summary      = "An iOS library that allows you to verify a user's group affiliation status using ID.me's platform."
  s.homepage     = "https://github.com/IDme/ID.me-WebVerify-SDK-iOS"
  s.platform     = :ios, '8.0'
  s.source       = { :git => "https://github.com/IDme/ID.me-WebVerify-SDK-iOS.git", :tag => s.version.to_s }
  s.source_files = [
    'Source/*{.h,.m}'
  ]
  s.requires_arc = true
  s.author       = { "Arthur Ariel Sabintsev" => "arthur@sabintsev.com", "ID.me" => "devops@id.me" }
  s.license      = 'MIT'
  s.ios.frameworks = 'UIKit', 'Foundation'
  s.dependency 'SAMKeychain', '~> 1.5'
end
