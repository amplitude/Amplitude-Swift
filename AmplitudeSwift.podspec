amplitude_version = "0.7.1" # Version is managed automatically by semantic-release, please don't change it manually

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

  # temporary disable watchos support due to: https://github.com/CocoaPods/CocoaPods/issues/11558
  # unpaired watchos will cause failure, the fix of the above issue is merged but not released
  # s.watchos.deployment_target  = '7.0'
  # s.watchos.source_files       = 'Sources/Amplitude/**/*.{h,swift}'

  s.dependency 'AnalyticsConnector', '~> 1.0.1'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
