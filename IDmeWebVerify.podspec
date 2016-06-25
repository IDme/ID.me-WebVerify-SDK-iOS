Pod::Spec.new do |s|
  s.name         = "IDmeWebVerify"
  s.version      = "3.1.2"
  s.summary      = "An iOS library that allows you to verify a user's group affiliation status using ID.me's platform."
  s.homepage     = "https://github.com/IDme/ID.me-WebVerify-SDK-iOS"
  s.platform     = :ios, '8.0'
  s.source       = { :git => "https://github.com/IDme/ID.me-WebVerify-SDK-iOS.git", :tag => s.version.to_s }
  s.source_files = 'ID.me WebVerify SDK/*{.h,.m}'
  s.requires_arc = true
  s.author       = { "Arthur Ariel Sabintsev" => "arthur@sabintsev.com" }
  s.license      = 'MIT'
end
