# [1.3.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.2.0...v1.3.0) (2024-02-08)


### Features

* add offline mode ([#111](https://github.com/amplitude/Amplitude-Swift/issues/111)) ([37b337d](https://github.com/amplitude/Amplitude-Swift/commit/37b337daefced3fd50aa9fed7c1145e84b4e1eda))

# [1.2.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.1.0...v1.2.0) (2024-02-05)


### Bug Fixes

* ensure event data is sandboxed per app for all platforms ([#113](https://github.com/amplitude/Amplitude-Swift/issues/113)) ([72da9f8](https://github.com/amplitude/Amplitude-Swift/commit/72da9f879837d2a64c248559081b322cde994c50))
* should track coarse location by default ([#110](https://github.com/amplitude/Amplitude-Swift/issues/110)) ([2aab265](https://github.com/amplitude/Amplitude-Swift/commit/2aab2657d0f9efde6e6ba977bbd488459b4a0c53))


### Features

* add privacy manifest for ios 17 ([#109](https://github.com/amplitude/Amplitude-Swift/issues/109)) ([cf0ca47](https://github.com/amplitude/Amplitude-Swift/commit/cf0ca474f50864fbaa5ea8ae7e70a58814456e61))

# [1.1.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.0.0...v1.1.0) (2023-10-30)


### Features

* add client upload time ([#94](https://github.com/amplitude/Amplitude-Swift/issues/94)) ([a0d59f1](https://github.com/amplitude/Amplitude-Swift/commit/a0d59f169f89794f33308781a96f0a2ad252d229))

# [1.0.0](https://github.com/amplitude/Amplitude-Swift/compare/v0.7.3...v1.0.0) (2023-10-27)


### Bug Fixes

* add setSessionId() method ([#95](https://github.com/amplitude/Amplitude-Swift/issues/95)) ([1fb9f01](https://github.com/amplitude/Amplitude-Swift/commit/1fb9f01592e5a230e1e27aba0816ccf22250e01d))


### Features

* Release 1.0.0 ([#98](https://github.com/amplitude/Amplitude-Swift/issues/98)) ([b047273](https://github.com/amplitude/Amplitude-Swift/commit/b0472736148a2364a4e8802518dabf78cf149ec1))


### BREAKING CHANGES

* New major version

## [0.7.3](https://github.com/amplitude/Amplitude-Swift/compare/v0.7.2...v0.7.3) (2023-10-17)


### Bug Fixes

* add support for CGFloat property values ([#91](https://github.com/amplitude/Amplitude-Swift/issues/91)) ([6de48f0](https://github.com/amplitude/Amplitude-Swift/commit/6de48f014c7ac80b83ad94e0cfa748ddc0d7908e))

## [0.7.2](https://github.com/amplitude/Amplitude-Swift/compare/v0.7.1...v0.7.2) (2023-10-04)


### Bug Fixes

* add Objective-C support to get property values ([#88](https://github.com/amplitude/Amplitude-Swift/issues/88)) ([a0d5aa6](https://github.com/amplitude/Amplitude-Swift/commit/a0d5aa6d88d8624d980bf3bc15bfea4a1c327839))

## [0.7.1](https://github.com/amplitude/Amplitude-Swift/compare/v0.7.0...v0.7.1) (2023-09-29)


### Bug Fixes

* Objective-C support for plugin flush() ([#87](https://github.com/amplitude/Amplitude-Swift/issues/87)) ([726e3e8](https://github.com/amplitude/Amplitude-Swift/commit/726e3e84b3c3be75b65010d68d3ac2e565188df3))

# [0.7.0](https://github.com/amplitude/Amplitude-Swift/compare/v0.6.0...v0.7.0) (2023-09-28)


### Features

* Objective-C support ([#84](https://github.com/amplitude/Amplitude-Swift/issues/84)) ([eeced3e](https://github.com/amplitude/Amplitude-Swift/commit/eeced3eb1706019dc49823fd11149b89141a4e16))

# [0.6.0](https://github.com/amplitude/Amplitude-Swift/compare/v0.5.1...v0.6.0) (2023-09-21)


### Bug Fixes

* encoding Encodable values from [String: Any] ([#82](https://github.com/amplitude/Amplitude-Swift/issues/82)) ([#83](https://github.com/amplitude/Amplitude-Swift/issues/83)) ([b610fa1](https://github.com/amplitude/Amplitude-Swift/commit/b610fa197cd067e13e7cf0dedde95272ddc0dd01))


### Features

* default tracking options, auto-track application lifecycle events ([#79](https://github.com/amplitude/Amplitude-Swift/issues/79)) ([c74979a](https://github.com/amplitude/Amplitude-Swift/commit/c74979a4626ea7888320a4aa2f111f3cef1ea736))

## [0.5.1](https://github.com/amplitude/Amplitude-Swift/compare/v0.5.0...v0.5.1) (2023-09-12)


### Bug Fixes

* mark uploads as background tasks to let them continue if the app enters the background ([#78](https://github.com/amplitude/Amplitude-Swift/issues/78)) ([80b465e](https://github.com/amplitude/Amplitude-Swift/commit/80b465e4b2e31fd3d01f732d6d59ffb73b3942fd))

# [0.5.0](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.14...v0.5.0) (2023-09-08)


### Features

* support integration with experiment ios ([#80](https://github.com/amplitude/Amplitude-Swift/issues/80)) ([ff3a8ec](https://github.com/amplitude/Amplitude-Swift/commit/ff3a8ec7fec75a3f80cbbcd7004ccabecdc2377f))

## [0.4.14](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.13...v0.4.14) (2023-08-17)


### Bug Fixes

* open 'DestinationPlugin.execute()' method ([#76](https://github.com/amplitude/Amplitude-Swift/issues/76)) ([e6bd825](https://github.com/amplitude/Amplitude-Swift/commit/e6bd8253e912268cebbf6de4068a13b7ad2285b3))

## [0.4.13](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.12...v0.4.13) (2023-08-16)


### Bug Fixes

* refactor base plugin types ([#73](https://github.com/amplitude/Amplitude-Swift/issues/73)) ([4c8a662](https://github.com/amplitude/Amplitude-Swift/commit/4c8a662b3adda3a4dd91518e365296f710839a6c))

## [0.4.12](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.11...v0.4.12) (2023-08-15)


### Bug Fixes

* remove location-related code from SDK, add an example plugin to collect location data ([#75](https://github.com/amplitude/Amplitude-Swift/issues/75)) ([34ff8e5](https://github.com/amplitude/Amplitude-Swift/commit/34ff8e54e98cfa5d3d3cd2b4585af03656063c89))

## [0.4.11](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.10...v0.4.11) (2023-08-11)


### Bug Fixes

* normalize explicit empty instance name ([#71](https://github.com/amplitude/Amplitude-Swift/issues/71)) ([ac60e5e](https://github.com/amplitude/Amplitude-Swift/commit/ac60e5e38e30729782ace2242ec7b9a215d6f871))

## [0.4.10](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.9...v0.4.10) (2023-08-11)


### Bug Fixes

* move mergeEventOptions() function to EventOptions class ([#72](https://github.com/amplitude/Amplitude-Swift/issues/72)) ([7a78576](https://github.com/amplitude/Amplitude-Swift/commit/7a78576c5a307605de4c607dfb2e991391a2bf00))

## [0.4.9](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.8...v0.4.9) (2023-08-11)


### Bug Fixes

* setGroup() should set event.userProperties ([#70](https://github.com/amplitude/Amplitude-Swift/issues/70)) ([109f33c](https://github.com/amplitude/Amplitude-Swift/commit/109f33cce36459f7359192e751704e23be496822))

## [0.4.8](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.7...v0.4.8) (2023-08-09)


### Bug Fixes

* make 'mergeEventOptions' public ([#67](https://github.com/amplitude/Amplitude-Swift/issues/67)) ([5a946f7](https://github.com/amplitude/Amplitude-Swift/commit/5a946f7c0d8632a16a5838afb80cc1e0c4e7831c))
* normalize package names for all package managers ([#69](https://github.com/amplitude/Amplitude-Swift/issues/69)) ([251ebdf](https://github.com/amplitude/Amplitude-Swift/commit/251ebdf602e90957ececd06a4d82925fc2b8d3b6))

## [0.4.7](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.6...v0.4.7) (2023-07-19)


### Bug Fixes

* made EventOptions.init public ([#64](https://github.com/amplitude/Amplitude-Swift/issues/64)) ([74992ce](https://github.com/amplitude/Amplitude-Swift/commit/74992cee7c10d8bde20aaf1a17f5f02611359d4e))
* migrate 'api key' storage data to 'instance name' storage ([#63](https://github.com/amplitude/Amplitude-Swift/issues/63)) ([9199039](https://github.com/amplitude/Amplitude-Swift/commit/919903905f237d845fc7fd22266b0cb93bbbec4b))
* migrate legacy data ([#62](https://github.com/amplitude/Amplitude-Swift/issues/62)) ([d1c6b32](https://github.com/amplitude/Amplitude-Swift/commit/d1c6b324a155681d9326ecf1806da44768de557f))

## [0.4.6](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.5...v0.4.6) (2023-06-07)


### Bug Fixes

* added getSessionId() method ([#58](https://github.com/amplitude/Amplitude-Swift/issues/58)) ([b990f2a](https://github.com/amplitude/Amplitude-Swift/commit/b990f2a3b226fc7e37fc6584589007b21bd384c6))

## [0.4.5](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.4...v0.4.5) (2023-06-05)


### Bug Fixes

* add getUserId() and getDeviceId() methods ([#57](https://github.com/amplitude/Amplitude-Swift/issues/57)) ([3f17782](https://github.com/amplitude/Amplitude-Swift/commit/3f17782cca403873a0beb734b59724df3fbadaf0))

## [0.4.4](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.3...v0.4.4) (2023-05-25)


### Bug Fixes

* fix disable tracking options ([#54](https://github.com/amplitude/Amplitude-Swift/issues/54)) ([6185ac1](https://github.com/amplitude/Amplitude-Swift/commit/6185ac184a806ea7ade4b8067226cad6164a94e1))

## [0.4.3](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.2...v0.4.3) (2023-05-12)


### Bug Fixes

* session not behaving as expected ([#53](https://github.com/amplitude/Amplitude-Swift/issues/53)) ([c02b64a](https://github.com/amplitude/Amplitude-Swift/commit/c02b64a8d6b913848cabc71494f478c622d5930c))

## [0.4.2](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.1...v0.4.2) (2023-04-27)


### Bug Fixes

* updated license to current year ([#52](https://github.com/amplitude/Amplitude-Swift/issues/52)) ([61f5812](https://github.com/amplitude/Amplitude-Swift/commit/61f581272f6f230c02288e4193e261cfb4e3c287))

## [0.4.1](https://github.com/amplitude/Amplitude-Swift/compare/v0.4.0...v0.4.1) (2023-04-26)


### Bug Fixes

* update identify collapsing logic to send actions on separate identify event ([#48](https://github.com/amplitude/Amplitude-Swift/issues/48)) ([6040632](https://github.com/amplitude/Amplitude-Swift/commit/604063266ef41a80e121e3f2a99edf9813ad7140))
* updated identify merging logic to ignore nil values ([#49](https://github.com/amplitude/Amplitude-Swift/issues/49)) ([0320451](https://github.com/amplitude/Amplitude-Swift/commit/03204512c6d2a70c61355c196fcd990d63b9f3d1))

# [0.4.0](https://github.com/amplitude/Amplitude-Swift/compare/v0.3.2...v0.4.0) (2023-02-25)


### Bug Fixes

* fix platform value ([#43](https://github.com/amplitude/Amplitude-Swift/issues/43)) ([dc78228](https://github.com/amplitude/Amplitude-Swift/commit/dc78228635dbad0a9bfc9c679f11cb8a38fff688))


### Features

* add identify interceptor to reduce identify volumes ([#40](https://github.com/amplitude/Amplitude-Swift/issues/40)) ([835a6f6](https://github.com/amplitude/Amplitude-Swift/commit/835a6f6e65bc8b9cd2326ae50a9ad7f7c4408a8c))

## [0.3.2](https://github.com/amplitude/Amplitude-Swift/compare/v0.3.1...v0.3.2) (2023-02-21)


### Bug Fixes

* expose plan and ingestion metadata ([#41](https://github.com/amplitude/Amplitude-Swift/issues/41)) ([da85455](https://github.com/amplitude/Amplitude-Swift/commit/da85455c20b9eb8873032b016ede181ada1929f3))

## [0.3.1](https://github.com/amplitude/Amplitude-Swift/compare/v0.3.0...v0.3.1) (2023-02-14)


### Bug Fixes

* fix userId is overwritten by deviceId and make reset public ([#33](https://github.com/amplitude/Amplitude-Swift/issues/33)) ([4f49720](https://github.com/amplitude/Amplitude-Swift/commit/4f497206cecd6cf7fd29f978b3613388076dbb57))
* remove serverUrl as default value for configuration ([#34](https://github.com/amplitude/Amplitude-Swift/issues/34)) ([48d0921](https://github.com/amplitude/Amplitude-Swift/commit/48d092132762cc3f6e6abc586b550b964ba61602))

# [0.3.0](https://github.com/amplitude/Amplitude-Swift/compare/v0.2.0...v0.3.0) (2022-12-20)


### Features

* update destination plugin to class ([#30](https://github.com/amplitude/Amplitude-Swift/issues/30)) ([705e61f](https://github.com/amplitude/Amplitude-Swift/commit/705e61fe81146b7ec0f59d98144483b5497ead97))

# [0.2.0](https://github.com/amplitude/Amplitude-Swift/compare/v0.1.0...v0.2.0) (2022-12-16)


### Features

* add carrier info ([#27](https://github.com/amplitude/Amplitude-Swift/issues/27)) ([3a946d8](https://github.com/amplitude/Amplitude-Swift/commit/3a946d87d11b47e81dffa406f728bbe32111d0fe))
* add widget appclip examples ([#28](https://github.com/amplitude/Amplitude-Swift/issues/28)) ([c23e990](https://github.com/amplitude/Amplitude-Swift/commit/c23e990ad45f53292022e11fb2260d8f59974221))

# [0.1.0](https://github.com/amplitude/Amplitude-Swift/compare/v0.0.0...v0.1.0) (2022-12-15)


### Bug Fixes

* add lifecycle plugin ([a26c621](https://github.com/amplitude/Amplitude-Swift/commit/a26c621e03504982374ed2e30130f75837d5d425))
* add other platform lifecycle plugin and lints fix ([c3f9c5b](https://github.com/amplitude/Amplitude-Swift/commit/c3f9c5b4cc7f328b7af5c197c8fef131a9d03bf8))
* add return to IdentityEventSender.execute ([75d787e](https://github.com/amplitude/Amplitude-Swift/commit/75d787e5d4e915aba1843f811f5d7eeab1128827))
* add the placeholder for IdentityEventSender ([2ad97da](https://github.com/amplitude/Amplitude-Swift/commit/2ad97da9f4ef1f32da6cfac7b3c3ce1f3b1ff83a))
* change storage to use sync queue, fix retry issues ([#14](https://github.com/amplitude/Amplitude-Swift/issues/14)) ([e2d824a](https://github.com/amplitude/Amplitude-Swift/commit/e2d824aa459de8e65bc17f497cbace24617ef9c1))
* fix based on comments ([4f354bc](https://github.com/amplitude/Amplitude-Swift/commit/4f354bc1638f23efe0217ecdf9a6755643b49eb2))
* fix logger in destination ([a7ff24e](https://github.com/amplitude/Amplitude-Swift/commit/a7ff24eb9593e4f9c428802fd5443fc7e5e4b6f0))
* fix the demo app to fit ipad ([#12](https://github.com/amplitude/Amplitude-Swift/issues/12)) ([72b1ef1](https://github.com/amplitude/Amplitude-Swift/commit/72b1ef16570909e560f15b3071753531ac7d0bf9))
* fix timeline in destination plugin ([0767751](https://github.com/amplitude/Amplitude-Swift/commit/0767751ae92e0bcc124070f1f5269647c9032aa0))
* lints and other comments ([296951b](https://github.com/amplitude/Amplitude-Swift/commit/296951b823241f9ca0eb31746f740947230c5146))
* nits ([2e264a5](https://github.com/amplitude/Amplitude-Swift/commit/2e264a543fb9e98926b19426e46071424c9cd8c6))
* pass amplitude instance in plugin setup ([42fbb51](https://github.com/amplitude/Amplitude-Swift/commit/42fbb51cedd53aa93bcffde568cebf9bc9a74cd4))
* typo and types ([fe5dba7](https://github.com/amplitude/Amplitude-Swift/commit/fe5dba73b8bee0f60f260c45684c6e361fe3155f))
* update support watchOS version ([5cc61f2](https://github.com/amplitude/Amplitude-Swift/commit/5cc61f27a3cfcf133317044b82fae1270432c7ee))


### Features

* add class and file placeholders ([d824cf1](https://github.com/amplitude/Amplitude-Swift/commit/d824cf1082e03b3dc4888617a952be9258602249))
* add podspec and release flow ([#18](https://github.com/amplitude/Amplitude-Swift/issues/18)) ([ef1ff28](https://github.com/amplitude/Amplitude-Swift/commit/ef1ff2862175c4142a6092de0fb54fd838ee0221))
* add timeline ([7cda5b2](https://github.com/amplitude/Amplitude-Swift/commit/7cda5b2ccef08764552316b516129f55b67fee84))
* Context plugin ([#8](https://github.com/amplitude/Amplitude-Swift/issues/8)) ([64ba783](https://github.com/amplitude/Amplitude-Swift/commit/64ba783b83f3689840a7edffe022b3fd26cccff8))
* destination plugin ([4dc18d9](https://github.com/amplitude/Amplitude-Swift/commit/4dc18d9c4153a9235cd2436873f31e6ac6663ea3))
* identify, revenue, amplitude client ([#16](https://github.com/amplitude/Amplitude-Swift/issues/16)) ([ab847f0](https://github.com/amplitude/Amplitude-Swift/commit/ab847f084dbcce3586e6d1f33f9893d4e676b53d))
* idfa plugin example ([#17](https://github.com/amplitude/Amplitude-Swift/issues/17)) ([9104e5f](https://github.com/amplitude/Amplitude-Swift/commit/9104e5f9d90dc25a3805d04b0359dbe6828e6b30))
* main function implementation ([29645c0](https://github.com/amplitude/Amplitude-Swift/commit/29645c08b33e8e8de83419e6337c643281735ae4))
* persistent storage, httpclient, eventpipeline ([#9](https://github.com/amplitude/Amplitude-Swift/issues/9)) ([0b5e99f](https://github.com/amplitude/Amplitude-Swift/commit/0b5e99f26ef9ddc8738c06a2c9dfae34820a8ba3))
* response retry handlers ([#11](https://github.com/amplitude/Amplitude-Swift/issues/11)) ([86d92f6](https://github.com/amplitude/Amplitude-Swift/commit/86d92f6434fbe18ad72a86dbd26961cafc380c7c))
* session event init ([#13](https://github.com/amplitude/Amplitude-Swift/issues/13)) ([bbf7517](https://github.com/amplitude/Amplitude-Swift/commit/bbf75174f5c57883f42841aabe73c23d70925788))
* setup lint, jira issue create, fix all file lint issues, update config ([0a34b96](https://github.com/amplitude/Amplitude-Swift/commit/0a34b96160e6a220e4e666406f0f811f5fb2c482))
* support event callback and fix missing insert_id ([#15](https://github.com/amplitude/Amplitude-Swift/issues/15)) ([1f746e8](https://github.com/amplitude/Amplitude-Swift/commit/1f746e822cee72ab7b3c0e3ea8965df6c57f0820))
