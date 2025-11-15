## [1.15.4](https://github.com/amplitude/Amplitude-Swift/compare/v1.15.3...v1.15.4) (2025-11-15)


### Bug Fixes

* prevent network tracking plugin remote config update crash ([#336](https://github.com/amplitude/Amplitude-Swift/issues/336)) ([06b1315](https://github.com/amplitude/Amplitude-Swift/commit/06b131544236408d150a4bbb65a7e59ab67f35d8))

## [1.15.3](https://github.com/amplitude/Amplitude-Swift/compare/v1.15.2...v1.15.3) (2025-11-05)


### Bug Fixes

* support onReset plugin lifecycle event ([ed883e8](https://github.com/amplitude/Amplitude-Swift/commit/ed883e8414f58658a708033c21f612da0c441a8c))

## [1.15.2](https://github.com/amplitude/Amplitude-Swift/compare/v1.15.1...v1.15.2) (2025-10-20)


### Bug Fixes

* improve timeline thread safety ([60de801](https://github.com/amplitude/Amplitude-Swift/commit/60de80198762cc08901af5df6447614f4aca173f))
* use correct remote config key for block lists ([361d540](https://github.com/amplitude/Amplitude-Swift/commit/361d540a89c9901d50be3f74c7ad035fd6e2c160))

## [1.15.1](https://github.com/amplitude/Amplitude-Swift/compare/v1.15.0...v1.15.1) (2025-09-29)


### Bug Fixes

* add appLifecycles remote config support ([#328](https://github.com/amplitude/Amplitude-Swift/issues/328)) ([8c7a376](https://github.com/amplitude/Amplitude-Swift/commit/8c7a37639570fe7210c82f641d7d35a34dc359e8))

# [1.15.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.14.0...v1.15.0) (2025-09-13)


### Features

* add autocapture support for frustration and network tracking ([#317](https://github.com/amplitude/Amplitude-Swift/issues/317)) ([5f70980](https://github.com/amplitude/Amplitude-Swift/commit/5f70980f182607cd4566617e08e7895b2306d9b0))
* add urls and header body support for network tracking ([#320](https://github.com/amplitude/Amplitude-Swift/issues/320)) ([82620af](https://github.com/amplitude/Amplitude-Swift/commit/82620af315161db2f04e9ead239761cd7a171cf9))
* make frustration interaction GA ([#323](https://github.com/amplitude/Amplitude-Swift/issues/323)) ([414bffe](https://github.com/amplitude/Amplitude-Swift/commit/414bffe4d857118eedb5f9c87aab97f14df836dc))

# [1.14.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.13.9...v1.14.0) (2025-07-23)


### Features

* Add autocapture for Rage Click and Dead Click ([#313](https://github.com/amplitude/Amplitude-Swift/issues/313)) ([e7965ec](https://github.com/amplitude/Amplitude-Swift/commit/e7965ece84ab6e305ffb1dca22c636e09a72d32c)), closes [#304](https://github.com/amplitude/Amplitude-Swift/issues/304) [#305](https://github.com/amplitude/Amplitude-Swift/issues/305) [#306](https://github.com/amplitude/Amplitude-Swift/issues/306) [#312](https://github.com/amplitude/Amplitude-Swift/issues/312)

## [1.13.9](https://github.com/amplitude/Amplitude-Swift/compare/v1.13.8...v1.13.9) (2025-07-18)


### Bug Fixes

* app install/opened event order for pre-scenedelegate apps ([#311](https://github.com/amplitude/Amplitude-Swift/issues/311)) ([17306e0](https://github.com/amplitude/Amplitude-Swift/commit/17306e0b9fde698617733a586204bcdaf1b529f1))
* Empty Commit to trigger a build ([c246c60](https://github.com/amplitude/Amplitude-Swift/commit/c246c60e6b7edacb199734a3548f7c13ebc379e5))

## [1.13.8](https://github.com/amplitude/Amplitude-Swift/compare/v1.13.7...v1.13.8) (2025-07-09)


### Bug Fixes

* fix deadlock problem in app install event trigger ([#308](https://github.com/amplitude/Amplitude-Swift/issues/308)) ([5730a90](https://github.com/amplitude/Amplitude-Swift/commit/5730a90665c5a96bd1266df81a33d0653d472392))

## [1.13.7](https://github.com/amplitude/Amplitude-Swift/compare/v1.13.6...v1.13.7) (2025-06-19)


### Bug Fixes

* improve thread safety around shared state ([505455a](https://github.com/amplitude/Amplitude-Swift/commit/505455ae64efb0360090a6a8906398ddc6d223bc))

## [1.13.6](https://github.com/amplitude/Amplitude-Swift/compare/v1.13.5...v1.13.6) (2025-06-04)


### Bug Fixes

* update min core version ([68cce1e](https://github.com/amplitude/Amplitude-Swift/commit/68cce1e9499b17245e743e0290432f533eee22db))

## [1.13.5](https://github.com/amplitude/Amplitude-Swift/compare/v1.13.4...v1.13.5) (2025-06-03)


### Bug Fixes

* Remove unused TimeInterval helpers ([c0afe2a](https://github.com/amplitude/Amplitude-Swift/commit/c0afe2a332c72a865b3933c4e368e242fca0b1d2))
* update to xcode 16.1 for prebuilt artifacts ([8dc6c5d](https://github.com/amplitude/Amplitude-Swift/commit/8dc6c5d045f7ce8c48b28e09b11dd0203480dbc4))

## [1.13.4](https://github.com/amplitude/Amplitude-Swift/compare/v1.13.3...v1.13.4) (2025-05-29)


### Bug Fixes

* delay app start / end events when starting amplitude in foreground ([#295](https://github.com/amplitude/Amplitude-Swift/issues/295)) ([c979b1b](https://github.com/amplitude/Amplitude-Swift/commit/c979b1b02836a6aa71bf73007649568edfb778e4))
* improve objc interface for Unified SDK ([#296](https://github.com/amplitude/Amplitude-Swift/issues/296)) ([eb0ccb2](https://github.com/amplitude/Amplitude-Swift/commit/eb0ccb2ef7d4a5438068e110130ff6b4d09a722d))

## [1.13.3](https://github.com/amplitude/Amplitude-Swift/compare/v1.13.2...v1.13.3) (2025-05-27)


### Bug Fixes

* fix amplitude remove and apply plugin ([#293](https://github.com/amplitude/Amplitude-Swift/issues/293)) ([b689baf](https://github.com/amplitude/Amplitude-Swift/commit/b689baf78a712332fd7e863a640995120d3085ca))

## [1.13.2](https://github.com/amplitude/Amplitude-Swift/compare/v1.13.1...v1.13.2) (2025-05-20)


### Bug Fixes

* name of network request event ([#289](https://github.com/amplitude/Amplitude-Swift/issues/289)) ([2ef0102](https://github.com/amplitude/Amplitude-Swift/commit/2ef01025da79af5ad754b549a28a6ea2680f5e86))

## [1.13.1](https://github.com/amplitude/Amplitude-Swift/compare/v1.13.0...v1.13.1) (2025-05-13)


### Bug Fixes

* implement plugin lookup by type ([#288](https://github.com/amplitude/Amplitude-Swift/issues/288)) ([729dee3](https://github.com/amplitude/Amplitude-Swift/commit/729dee316245a7bab77a1805d9ac3b8df22a58be))

# [1.13.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.12.1...v1.13.0) (2025-05-07)


### Features

* Unified SDK Release ([#287](https://github.com/amplitude/Amplitude-Swift/issues/287)) ([7c4889d](https://github.com/amplitude/Amplitude-Swift/commit/7c4889ddca5fcc1cd52303a8de777db2bc6cd209)), closes [#279](https://github.com/amplitude/Amplitude-Swift/issues/279) [#280](https://github.com/amplitude/Amplitude-Swift/issues/280)

## [1.12.1](https://github.com/amplitude/Amplitude-Swift/compare/v1.12.0...v1.12.1) (2025-05-05)


### Bug Fixes

* remove eventbridge ([#285](https://github.com/amplitude/Amplitude-Swift/issues/285)) ([6c6dfaf](https://github.com/amplitude/Amplitude-Swift/commit/6c6dfafeb315a19a3febeb3a276963c35808be66))
* set user/device id on session events ([#286](https://github.com/amplitude/Amplitude-Swift/issues/286)) ([a25df6e](https://github.com/amplitude/Amplitude-Swift/commit/a25df6e806edfd9f6056922dafcf55a2c68ffd6c))

# [1.12.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.11.10...v1.12.0) (2025-04-25)


### Bug Fixes

* apply identifies to identity userProperties in correct order ([#272](https://github.com/amplitude/Amplitude-Swift/issues/272)) ([41deb6a](https://github.com/amplitude/Amplitude-Swift/commit/41deb6a8ff4c8ab70d1f9b6146c645ad2a05d7a7))
* clean up ios observers on stop ([#275](https://github.com/amplitude/Amplitude-Swift/issues/275)) ([3965e13](https://github.com/amplitude/Amplitude-Swift/commit/3965e136dce8ded31511d3ebbbcc6fc12790530d))
* disallow setting nulls for various properties dicts, as this is not supported ([#277](https://github.com/amplitude/Amplitude-Swift/issues/277)) ([70ea4be](https://github.com/amplitude/Amplitude-Swift/commit/70ea4be802cbe2d7b2e8475376bdcce4d6d64073))
* enable running tests from package.swift ([#274](https://github.com/amplitude/Amplitude-Swift/issues/274)) ([f7aad5b](https://github.com/amplitude/Amplitude-Swift/commit/f7aad5b7dfb0c94a7c1db69acbff2791b515d30d))
* move default init properties to new defaults structure so they can be shared ([#276](https://github.com/amplitude/Amplitude-Swift/issues/276)) ([88e3b16](https://github.com/amplitude/Amplitude-Swift/commit/88e3b164840b66e684cf56fe9d6ea0c27cdce3cc))
* remove unused enableRemoteConfig option ([#278](https://github.com/amplitude/Amplitude-Swift/issues/278)) ([c9a2608](https://github.com/amplitude/Amplitude-Swift/commit/c9a2608db78e7853a4c9bf01419cd2e22a312388))
* treat non-op user properties as sets ([#273](https://github.com/amplitude/Amplitude-Swift/issues/273)) ([df65e7b](https://github.com/amplitude/Amplitude-Swift/commit/df65e7b29fdb1a9f1ed6db30411b57055bbbb359))


### Features

* add network tracking support ([#270](https://github.com/amplitude/Amplitude-Swift/issues/270)) ([d1647b3](https://github.com/amplitude/Amplitude-Swift/commit/d1647b3653eae5d294417794674cfc1c824669f6))
* add ObjC interface for NetworkTrackingOptions ([#281](https://github.com/amplitude/Amplitude-Swift/issues/281)) ([8f699fa](https://github.com/amplitude/Amplitude-Swift/commit/8f699fa713c79c769860b44844dfc0ec5764c408))
* unify several identity apis into a single Identity struct ([#268](https://github.com/amplitude/Amplitude-Swift/issues/268)) ([ceae1e4](https://github.com/amplitude/Amplitude-Swift/commit/ceae1e4e3526200fdc0477947838068742a4dbf9))

## [1.11.10](https://github.com/amplitude/Amplitude-Swift/compare/v1.11.9...v1.11.10) (2025-04-14)


### Bug Fixes

* potential deadlock on storagequeue access ([#269](https://github.com/amplitude/Amplitude-Swift/issues/269)) ([4091bd1](https://github.com/amplitude/Amplitude-Swift/commit/4091bd12eb5447e2b00b07f0449106e9921122f5))

## [1.11.9](https://github.com/amplitude/Amplitude-Swift/compare/v1.11.8...v1.11.9) (2025-03-27)


### Bug Fixes

* port Configuration.flushMaxRetries as pipeline retry cap ([#267](https://github.com/amplitude/Amplitude-Swift/issues/267)) ([d4960b7](https://github.com/amplitude/Amplitude-Swift/commit/d4960b78f4c06e1bdc37a58fcc14f85431fd115e))

## [1.11.8](https://github.com/amplitude/Amplitude-Swift/compare/v1.11.7...v1.11.8) (2025-03-26)


### Bug Fixes

* error handling for 400 request ([#266](https://github.com/amplitude/Amplitude-Swift/issues/266)) ([33fd10c](https://github.com/amplitude/Amplitude-Swift/commit/33fd10c832c7315710958b9f657dfd1383474fb3))

## [1.11.7](https://github.com/amplitude/Amplitude-Swift/compare/v1.11.6...v1.11.7) (2025-03-05)


### Bug Fixes

* allow adding Swift Plugins to ObjC Amplitude ([#264](https://github.com/amplitude/Amplitude-Swift/issues/264)) ([d916d93](https://github.com/amplitude/Amplitude-Swift/commit/d916d93d0e5edc9a02249072df58cea1e06eb8ae))

## [1.11.6](https://github.com/amplitude/Amplitude-Swift/compare/v1.11.5...v1.11.6) (2025-03-03)


### Bug Fixes

* add watchos support back to CocoaPods ([#263](https://github.com/amplitude/Amplitude-Swift/issues/263)) ([d9dd73e](https://github.com/amplitude/Amplitude-Swift/commit/d9dd73ef3b8c4f5384373015574b991794903eb7))
* adding ability to send revenue currency ([#262](https://github.com/amplitude/Amplitude-Swift/issues/262)) ([c34a138](https://github.com/amplitude/Amplitude-Swift/commit/c34a1382f0a4b277b14ff40b57fe045da389ef48))

## [1.11.5](https://github.com/amplitude/Amplitude-Swift/compare/v1.11.4...v1.11.5) (2025-02-04)


### Bug Fixes

* improve multi-thread safety to prevent crash ([#259](https://github.com/amplitude/Amplitude-Swift/issues/259)) ([25bde46](https://github.com/amplitude/Amplitude-Swift/commit/25bde46429910d2969494a116f03edf4c706f4f9))

## [1.11.4](https://github.com/amplitude/Amplitude-Swift/compare/v1.11.3...v1.11.4) (2025-01-31)


### Bug Fixes

* offline directly after receive bad url error ([#258](https://github.com/amplitude/Amplitude-Swift/issues/258)) ([fb00966](https://github.com/amplitude/Amplitude-Swift/commit/fb009665b3408df35a6e47a2e5833b91353d21ea))

## [1.11.3](https://github.com/amplitude/Amplitude-Swift/compare/v1.11.2...v1.11.3) (2025-01-23)


### Bug Fixes

* enhance thread safety of properties ([#257](https://github.com/amplitude/Amplitude-Swift/issues/257)) ([8ffcc65](https://github.com/amplitude/Amplitude-Swift/commit/8ffcc657efb02f42dd7a3f8603c6e0f3511247a0))

## [1.11.2](https://github.com/amplitude/Amplitude-Swift/compare/v1.11.1...v1.11.2) (2024-12-17)


### Bug Fixes

* add repeat interval on EventPipeline to prevent high frequency requests on continuing failing ([#250](https://github.com/amplitude/Amplitude-Swift/issues/250)) ([8af9acf](https://github.com/amplitude/Amplitude-Swift/commit/8af9acf3ccd666111f03040467d9891fc0c3b76a))
* fix likely-to-fail test case ([#251](https://github.com/amplitude/Amplitude-Swift/issues/251)) ([94e5e11](https://github.com/amplitude/Amplitude-Swift/commit/94e5e11f722dcb5fe8e62f1104de5a2a33465e97))

## [1.11.1](https://github.com/amplitude/Amplitude-Swift/compare/v1.11.0...v1.11.1) (2024-12-09)


### Bug Fixes

* also include NSURLErrorNotConnectedToInternet when setting configuration to offline ([#249](https://github.com/amplitude/Amplitude-Swift/issues/249)) ([4efb6f4](https://github.com/amplitude/Amplitude-Swift/commit/4efb6f45343593eae4551a48e7cb62a9d50cf923))

# [1.11.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.10.6...v1.11.0) (2024-11-20)


### Features

* add visionOS support ([#244](https://github.com/amplitude/Amplitude-Swift/issues/244)) ([cd25c07](https://github.com/amplitude/Amplitude-Swift/commit/cd25c0737b39a749716ae9b9c3ec2036a4871ba7))

## [1.10.6](https://github.com/amplitude/Amplitude-Swift/compare/v1.10.5...v1.10.6) (2024-11-19)


### Bug Fixes

* empty commit to trigger a build ([dc00739](https://github.com/amplitude/Amplitude-Swift/commit/dc00739f79a56ef2605ce8ae72d3c83f565c26d9))

## [1.10.5](https://github.com/amplitude/Amplitude-Swift/compare/v1.10.4...v1.10.5) (2024-11-18)


### Bug Fixes

* prevent main thread checker warning ([#248](https://github.com/amplitude/Amplitude-Swift/issues/248)) ([7b71d12](https://github.com/amplitude/Amplitude-Swift/commit/7b71d129f6b71e6a7978c934cda60f8190316674))

## [1.10.4](https://github.com/amplitude/Amplitude-Swift/compare/v1.10.3...v1.10.4) (2024-11-14)


### Bug Fixes

* improvements to app lifecycle monitoring ([#243](https://github.com/amplitude/Amplitude-Swift/issues/243)) ([8098782](https://github.com/amplitude/Amplitude-Swift/commit/809878222577da3e1a177452305b190c99631757))

## [1.10.3](https://github.com/amplitude/Amplitude-Swift/compare/v1.10.2...v1.10.3) (2024-11-13)


### Bug Fixes

* empty commit to trigger a build ([ed0953f](https://github.com/amplitude/Amplitude-Swift/commit/ed0953f7d599f62fe60134581ae455a69031953e))

## [1.10.2](https://github.com/amplitude/Amplitude-Swift/compare/v1.10.1...v1.10.2) (2024-11-12)


### Bug Fixes

* properly decode embedded arrays ([#242](https://github.com/amplitude/Amplitude-Swift/issues/242)) ([c5b4d2b](https://github.com/amplitude/Amplitude-Swift/commit/c5b4d2bf1fd002340300e427cedbc75113560fc8))
* restore Analytics-Connector to built from source version when distributing as a swift package ([#241](https://github.com/amplitude/Amplitude-Swift/issues/241)) ([31133ac](https://github.com/amplitude/Amplitude-Swift/commit/31133ac2d342f175fab55a1a114a6b7868de86f5))

## [1.10.1](https://github.com/amplitude/Amplitude-Swift/compare/v1.10.0...v1.10.1) (2024-11-01)


### Bug Fixes

* preserve symlinks when zipping xcframeworks ([#237](https://github.com/amplitude/Amplitude-Swift/issues/237)) ([0b01833](https://github.com/amplitude/Amplitude-Swift/commit/0b018330464248d3a6f26e133503db88159b254d))

# [1.10.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.9.4...v1.10.0) (2024-10-31)


### Features

* support building without UIKit ([#235](https://github.com/amplitude/Amplitude-Swift/issues/235)) ([61e77a1](https://github.com/amplitude/Amplitude-Swift/commit/61e77a16bc164f7eba86db35de2dcd308f828d9f))

## [1.9.4](https://github.com/amplitude/Amplitude-Swift/compare/v1.9.3...v1.9.4) (2024-10-11)


### Bug Fixes

* Empty Commit to Trigger a Build ([19ffa87](https://github.com/amplitude/Amplitude-Swift/commit/19ffa87f0ea6621e458c76be8c00c3443e8fe08c))

## [1.9.3](https://github.com/amplitude/Amplitude-Swift/compare/v1.9.2...v1.9.3) (2024-10-01)


### Bug Fixes

* add autoreleasepool around sendNextEventFile ([#232](https://github.com/amplitude/Amplitude-Swift/issues/232)) ([0ec1187](https://github.com/amplitude/Amplitude-Swift/commit/0ec1187a218c5b90cd1b8a9024ceabb55af6a092))
* improve logging in httpclient ([#228](https://github.com/amplitude/Amplitude-Swift/issues/228)) ([633deb5](https://github.com/amplitude/Amplitude-Swift/commit/633deb5bd793c487ef2063877016d61abc0bb5d2))
* Use extension safe APIs ([#231](https://github.com/amplitude/Amplitude-Swift/issues/231)) ([4794f4e](https://github.com/amplitude/Amplitude-Swift/commit/4794f4e0cdbccc7d1a663247879fefe74438d810))

## [1.9.2](https://github.com/amplitude/Amplitude-Swift/compare/v1.9.1...v1.9.2) (2024-09-10)


### Bug Fixes

* notify plugins of internal sessionId changes ([#224](https://github.com/amplitude/Amplitude-Swift/issues/224)) ([61d43cf](https://github.com/amplitude/Amplitude-Swift/commit/61d43cff8dc7b15208076b6e3dbeb25eee9df646))

## [1.9.1](https://github.com/amplitude/Amplitude-Swift/compare/v1.9.0...v1.9.1) (2024-09-05)


### Bug Fixes

* Add maxQueuedEventCount parameter to trim events in storage if over a limit ([#222](https://github.com/amplitude/Amplitude-Swift/issues/222)) ([0134383](https://github.com/amplitude/Amplitude-Swift/commit/0134383b76890bba7cc05d4cc8656b234f052189))
* Send a max of one upload at a time ([#221](https://github.com/amplitude/Amplitude-Swift/issues/221)) ([63e76d9](https://github.com/amplitude/Amplitude-Swift/commit/63e76d9e3b28ce491880665eb2ca778c85aea47a))

# [1.9.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.8.1...v1.9.0) (2024-08-24)


### Features

* Enhancements to Plugin interface ([#218](https://github.com/amplitude/Amplitude-Swift/issues/218)) ([254e03a](https://github.com/amplitude/Amplitude-Swift/commit/254e03a0034b40ca10873c1defd547c206cd70a9))

## [1.8.1](https://github.com/amplitude/Amplitude-Swift/compare/v1.8.0...v1.8.1) (2024-08-23)


### Bug Fixes

* Delete events on an invalid api key response. ([#211](https://github.com/amplitude/Amplitude-Swift/issues/211)) ([9329a26](https://github.com/amplitude/Amplitude-Swift/commit/9329a26e7ce29a7c5295f3adb9aa6c78619b9c14))
* Fix code compatibility issues on Xcode 14.1 ([#213](https://github.com/amplitude/Amplitude-Swift/issues/213)) ([b2022b6](https://github.com/amplitude/Amplitude-Swift/commit/b2022b6e44ed9dced61244f5cc6f2c9fd03b899c))
* fix pinchGestureRecognizer unavailability issue on tvos ([#217](https://github.com/amplitude/Amplitude-Swift/issues/217)) ([4c5ae67](https://github.com/amplitude/Amplitude-Swift/commit/4c5ae674631973c7ddadd3c891def11047a9d01b))
* set offline when receiving certain error responses ([#212](https://github.com/amplitude/Amplitude-Swift/issues/212)) ([056ccbf](https://github.com/amplitude/Amplitude-Swift/commit/056ccbfe3d63e6df8b128e27a13eed7abed4ee9d))

# [1.8.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.7.0...v1.8.0) (2024-08-08)


### Features

* Feature Autocapture ([#209](https://github.com/amplitude/Amplitude-Swift/issues/209)) ([4ab5673](https://github.com/amplitude/Amplitude-Swift/commit/4ab5673bbd0ed45c11adec7b688d8ed38a291d77)), closes [#190](https://github.com/amplitude/Amplitude-Swift/issues/190) [#195](https://github.com/amplitude/Amplitude-Swift/issues/195) [#196](https://github.com/amplitude/Amplitude-Swift/issues/196) [#199](https://github.com/amplitude/Amplitude-Swift/issues/199) [#202](https://github.com/amplitude/Amplitude-Swift/issues/202) [#203](https://github.com/amplitude/Amplitude-Swift/issues/203) [#204](https://github.com/amplitude/Amplitude-Swift/issues/204) [#206](https://github.com/amplitude/Amplitude-Swift/issues/206) [#207](https://github.com/amplitude/Amplitude-Swift/issues/207) [#208](https://github.com/amplitude/Amplitude-Swift/issues/208)

# [1.7.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.6.2...v1.7.0) (2024-07-11)


### Bug Fixes

* add support for Decimal property values ([#187](https://github.com/amplitude/Amplitude-Swift/issues/187)) ([c838bd9](https://github.com/amplitude/Amplitude-Swift/commit/c838bd90a6da46337af5a5f6960fbca531994d2d))
* fix indentation issue ([#188](https://github.com/amplitude/Amplitude-Swift/issues/188)) ([48b9a37](https://github.com/amplitude/Amplitude-Swift/commit/48b9a37ff77fbd4ae2381aa400ff65bf443869ee))


### Features

* Improve codable support ([#192](https://github.com/amplitude/Amplitude-Swift/issues/192)) ([1ad9796](https://github.com/amplitude/Amplitude-Swift/commit/1ad979673abaeabcd84afe6a495c01a169a43284))

## [1.6.2](https://github.com/amplitude/Amplitude-Swift/compare/v1.6.1...v1.6.2) (2024-06-14)


### Bug Fixes

* Don't use idfv for deviceId if invalid ([#183](https://github.com/amplitude/Amplitude-Swift/issues/183)) ([f17e7fa](https://github.com/amplitude/Amplitude-Swift/commit/f17e7fa13306f631314a4d28ed811397b5d2511e))

## [1.6.1](https://github.com/amplitude/Amplitude-Swift/compare/v1.6.0...v1.6.1) (2024-06-12)


### Bug Fixes

* Add additional diagnostic logging ([#177](https://github.com/amplitude/Amplitude-Swift/issues/177)) ([e0e47a7](https://github.com/amplitude/Amplitude-Swift/commit/e0e47a747eb619dbb0f553c2025ae621bd514793))
* dispatch identify interceptor callbacks on correct queue ([#176](https://github.com/amplitude/Amplitude-Swift/issues/176)) ([eaf6d16](https://github.com/amplitude/Amplitude-Swift/commit/eaf6d168d4a523cf4e5f279e0e34291f4ffb4887))
* resolve compilation issue with watchOS 8.0 ([#180](https://github.com/amplitude/Amplitude-Swift/issues/180)) ([d0b7bff](https://github.com/amplitude/Amplitude-Swift/commit/d0b7bff4b228b283cc801c6ad7510f85b2bdc5a7))

# [1.6.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.5.2...v1.6.0) (2024-06-04)


### Bug Fixes

* Disable network connectivity check on watchOS as it is not supported on real devices ([#174](https://github.com/amplitude/Amplitude-Swift/issues/174)) ([853e4e5](https://github.com/amplitude/Amplitude-Swift/commit/853e4e510a1c1c098f9404ef6ef4e1281c5298f4))


### Features

* support single-target Watch applications ([#163](https://github.com/amplitude/Amplitude-Swift/issues/163)) ([0d23d94](https://github.com/amplitude/Amplitude-Swift/commit/0d23d9428d564b40248c9ddd632bae9b10a62642))

## [1.5.2](https://github.com/amplitude/Amplitude-Swift/compare/v1.5.1...v1.5.2) (2024-05-21)


### Bug Fixes

* Send application opened for apps not yet using scene delegates ([#167](https://github.com/amplitude/Amplitude-Swift/issues/167)) ([dd43026](https://github.com/amplitude/Amplitude-Swift/commit/dd43026b59cf5a2be1c0a7dea1e5247d67a1c229))

## [1.5.1](https://github.com/amplitude/Amplitude-Swift/compare/v1.5.0...v1.5.1) (2024-05-15)


### Bug Fixes

* Improve application opened event reliability ([#165](https://github.com/amplitude/Amplitude-Swift/issues/165)) ([d3b9de7](https://github.com/amplitude/Amplitude-Swift/commit/d3b9de7d200274c5f43e036b221c7669011869a6))

# [1.5.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.4.5...v1.5.0) (2024-05-10)


### Features

* Dispatch operations to internal queue ([#159](https://github.com/amplitude/Amplitude-Swift/issues/159)) ([83d24f7](https://github.com/amplitude/Amplitude-Swift/commit/83d24f7b4e2131c578889997ef4d11b2e7323248))
* Fix retain cycles in Amplitude so instance will not leak memory ([#161](https://github.com/amplitude/Amplitude-Swift/issues/161)) ([492d1fd](https://github.com/amplitude/Amplitude-Swift/commit/492d1fda2f14a2224905026cf02dbae07950fd99))

## [1.4.5](https://github.com/amplitude/Amplitude-Swift/compare/v1.4.4...v1.4.5) (2024-04-18)


### Bug Fixes

* Adopt resource bundle for privacy manifest in Cocoapods ([#156](https://github.com/amplitude/Amplitude-Swift/issues/156)) ([bdf2f43](https://github.com/amplitude/Amplitude-Swift/commit/bdf2f4375a71231d87b33e701571e36f2e67a0f1))

## [1.4.4](https://github.com/amplitude/Amplitude-Swift/compare/v1.4.3...v1.4.4) (2024-04-01)


### Bug Fixes

* expose DET utils for flutter plugin ([dc7c619](https://github.com/amplitude/Amplitude-Swift/commit/dc7c6192fc439edb923798def08a3c3ce568e6e8))

## [1.4.3](https://github.com/amplitude/Amplitude-Swift/compare/v1.4.2...v1.4.3) (2024-03-26)


### Bug Fixes

* Trim and dedup error logs ([#147](https://github.com/amplitude/Amplitude-Swift/issues/147)) ([1eb1633](https://github.com/amplitude/Amplitude-Swift/commit/1eb1633b5e3e5c0cd9f839e4a25d6c16723b4010))

## [1.4.2](https://github.com/amplitude/Amplitude-Swift/compare/v1.4.1...v1.4.2) (2024-03-22)


### Bug Fixes

* better carthage support ([#142](https://github.com/amplitude/Amplitude-Swift/issues/142)) ([a6f1559](https://github.com/amplitude/Amplitude-Swift/commit/a6f155998e1472da05fa413ed1434168ba72e81a))
* Fix compilation on Xcode 14.x ([#141](https://github.com/amplitude/Amplitude-Swift/issues/141)) ([8eedaab](https://github.com/amplitude/Amplitude-Swift/commit/8eedaab14b9b0be9ecd6575a950763e760c60e4e))
* Use appropriate background task API for app extensions ([#138](https://github.com/amplitude/Amplitude-Swift/issues/138)) ([7231bee](https://github.com/amplitude/Amplitude-Swift/commit/7231beec5921e5ec7bf8d0d4d62c7464ff13a344))

## [1.4.1](https://github.com/amplitude/Amplitude-Swift/compare/v1.4.0...v1.4.1) (2024-03-19)


### Bug Fixes

* Rely on on task completion vs http completion to end tasks ([#134](https://github.com/amplitude/Amplitude-Swift/issues/134)) ([b17e704](https://github.com/amplitude/Amplitude-Swift/commit/b17e7044e20e2690837dc5b87e7f0789540e7458))

# [1.4.0](https://github.com/amplitude/Amplitude-Swift/compare/v1.3.6...v1.4.0) (2024-03-15)


### Bug Fixes

* Don't use idfv as deviceID if disabled. ([#133](https://github.com/amplitude/Amplitude-Swift/issues/133)) ([76ef012](https://github.com/amplitude/Amplitude-Swift/commit/76ef012e2949ff4722033ef59b188e4b9e98bc5b))
* Fixes for automatic screen tracking ([#137](https://github.com/amplitude/Amplitude-Swift/issues/137)) ([55b2ca9](https://github.com/amplitude/Amplitude-Swift/commit/55b2ca95c9335188ae469a3fb3e39e978af84f9e))
* tests on iOS 17 ([#136](https://github.com/amplitude/Amplitude-Swift/issues/136)) ([04e5d03](https://github.com/amplitude/Amplitude-Swift/commit/04e5d036d4690ceebce0603f5b52bb6e988ab3c9))


### Features

* migrate storage to for better thread safety ([#129](https://github.com/amplitude/Amplitude-Swift/issues/129)) ([2bbe919](https://github.com/amplitude/Amplitude-Swift/commit/2bbe919b78b2a102403f34dce2b0c3d9daf8c3e1))

## [1.3.6](https://github.com/amplitude/Amplitude-Swift/compare/v1.3.5...v1.3.6) (2024-03-05)


### Bug Fixes

* Set inForeground to true after a new session has been started ([#124](https://github.com/amplitude/Amplitude-Swift/issues/124)) ([3780c44](https://github.com/amplitude/Amplitude-Swift/commit/3780c44fc65f1dd8913c25cf70fbe189e61fc315))

## [1.3.5](https://github.com/amplitude/Amplitude-Swift/compare/v1.3.4...v1.3.5) (2024-02-28)


### Bug Fixes

* Do not migrate remnant data from legacy SDK when sandboxing is not enabled ([#127](https://github.com/amplitude/Amplitude-Swift/issues/127)) ([e92f6ed](https://github.com/amplitude/Amplitude-Swift/commit/e92f6ed2a93a034d39aab49885cf82a3b730a25c))

## [1.3.4](https://github.com/amplitude/Amplitude-Swift/compare/v1.3.3...v1.3.4) (2024-02-23)


### Bug Fixes

* fix the enrichment plugin to enable filter event ([#123](https://github.com/amplitude/Amplitude-Swift/issues/123)) ([5d3aeb0](https://github.com/amplitude/Amplitude-Swift/commit/5d3aeb0494d6d2aa625d38019d04c46d82340aeb))

## [1.3.3](https://github.com/amplitude/Amplitude-Swift/compare/v1.3.2...v1.3.3) (2024-02-13)


### Bug Fixes

* fix setOnce identify operation ([#119](https://github.com/amplitude/Amplitude-Swift/issues/119)) ([6934c89](https://github.com/amplitude/Amplitude-Swift/commit/6934c8913d23765806f72046bc7976b316078959))
* try fix crash ([#117](https://github.com/amplitude/Amplitude-Swift/issues/117)) ([0536666](https://github.com/amplitude/Amplitude-Swift/commit/0536666dd36e4dda86a0a5334de8588c59063f7c))

## [1.3.2](https://github.com/amplitude/Amplitude-Swift/compare/v1.3.1...v1.3.2) (2024-02-13)


### Bug Fixes

* storage instance issue ([#118](https://github.com/amplitude/Amplitude-Swift/issues/118)) ([2655645](https://github.com/amplitude/Amplitude-Swift/commit/26556450b4f8b1f3df235bccf7ee10c8ca11ef0d))

## [1.3.1](https://github.com/amplitude/Amplitude-Swift/compare/v1.3.0...v1.3.1) (2024-02-12)


### Bug Fixes

* migrate storage to instanceName-apiKey to isolate by instance ([#114](https://github.com/amplitude/Amplitude-Swift/issues/114)) ([7128e62](https://github.com/amplitude/Amplitude-Swift/commit/7128e624b38e005ca6e68245e5c4f6443c62fa19))

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
