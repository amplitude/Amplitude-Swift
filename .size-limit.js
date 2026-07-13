const limits = [
  {
    // AmplitudeSwift xcframework release artifact
    path: './.build/artifacts/AmplitudeSwift.xcframework.zip',
    limit: '47mb',
    brotli: false,
  },
  {
    // AmplitudeSwiftNoUIKit xcframework release artifact
    path: './.build/artifacts/AmplitudeSwiftNoUIKit.xcframework.zip',
    limit: '42mb',
    brotli: false,
  },
]

module.exports = limits;
