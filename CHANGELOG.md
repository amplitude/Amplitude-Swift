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
