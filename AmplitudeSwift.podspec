amplitude_version = "0.0.0" # Version is managed automatically by semantic-release, please don't change it manually

Pod::Spec.new do |s|
  s.name                   = "AmplitudeSwift"
  s.version                = amplitude_version
  s.summary                = "Amplitude Analytics SDK"
  s.homepage               = "https://amplitude.com"
  s.license                = { :type => "MIT" }
  s.author                 = { "Amplitude" => "dev@amplitude.com" }
  s.source                 = { :git => "https://github.com/amplitude/Amplitude-Swift.git", :tag => "v#{s.version}" }

  s.swift_version = '5.7'

  s.ios.deployment_target  = '13.0'
  s.ios.source_files       = 'Sources/Amplitude/**/*.{h,swift}'

  s.tvos.deployment_target = '13.0'
  s.tvos.source_files      = 'Sources/Amplitude/**/*.{h,swift}'

  s.osx.deployment_target  = '10.15'
  s.osx.source_files       = 'Sources/Amplitude/**/*.{h,swift}'

  s.watchos.deployment_target  = '7.0'
  s.watchos.source_files       = 'Sources/Amplitude/**/*.{h,swift}'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
