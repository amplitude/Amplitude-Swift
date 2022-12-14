module.exports = {
  "branches": ["main"],
  "plugins": [
    ["@semantic-release/commit-analyzer", {
      "preset": "angular",
      "parserOpts": {
        "noteKeywords": ["BREAKING CHANGE", "BREAKING CHANGES", "BREAKING"]
      }
    }],
    ["@semantic-release/release-notes-generator", {
      "preset": "angular",
    }],
    ["@semantic-release/changelog", {
      "changelogFile": "CHANGELOG.md"
    }],
    "@semantic-release/github",
    [
      "@google/semantic-release-replace-plugin",
      {
        "replacements": [
          {
            "files": ["AmplitudeSwift.podspec"],
            "from": "amplitude_version = \".*\"",
            "to": "amplitude_version = \"${nextRelease.version}\"",
            "results": [
              {
                "file": "AmplitudeSwift.podspec",
                "hasChanged": true,
                "numMatches": 1,
                "numReplacements": 1
              }
            ],
            "countMatches": true
          },
          {
            "files": ["Sources/Amplitude/Constants.swift"],
            "from": "SDK_VERSION = @\".*\"",
            "to": "SDK_VERSION = @\"${nextRelease.version}\"",
            "results": [
              {
                "file": "Sources/Amplitude/Constants.swift",
                "hasChanged": true,
                "numMatches": 1,
                "numReplacements": 1
              }
            ],
            "countMatches": true
          },
        ]
      }
    ],
    ["@semantic-release/git", {
      "assets": ["AmplitudeSwift.podspec", "Sources/Amplitude/Constants.swift", "CHANGELOG.md"],
      "message": "chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}"
    }],
    ["@semantic-release/exec", {
      "publishCmd": "pod trunk push AmplitudeSwift.podspec --allow-warnings",
    }],
  ],
}
