//
//  ObjectFilterTests.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 8/27/25.
//

import XCTest
@testable import AmplitudeSwift

final class ObjectFilterMatchTests: XCTestCase {
    func testMatchesExactPath() throws {
        let filter = ObjectFilter()

        // Exact match
        XCTAssertTrue(filter.matches(["user", "name"], ["user", "name"]))
        XCTAssertTrue(filter.matches(["user", "metadata", "item1"], ["user", "metadata", "item1"]))

        // No match
        XCTAssertFalse(filter.matches(["user", "name"], ["user", "email"]))
        XCTAssertFalse(filter.matches(["user", "name"], ["product", "name"]))
        XCTAssertFalse(filter.matches(["user"], ["user", "name"]))
        XCTAssertFalse(filter.matches(["user", "name"], ["user"]))
    }

    func testMatchesSingleWildcard() throws {
        let filter = ObjectFilter()

        // Single wildcard * matches exactly one level
        XCTAssertTrue(filter.matches(["user", "name"], ["user", "*"]))
        XCTAssertTrue(filter.matches(["user", "email"], ["user", "*"]))
        XCTAssertTrue(filter.matches(["user", "metadata"], ["user", "*"]))

        // * doesn't match multiple levels
        XCTAssertFalse(filter.matches(["user", "metadata", "item1"], ["user", "*"]))
        XCTAssertFalse(filter.matches(["user"], ["user", "*"]))

        // * at the beginning
        XCTAssertTrue(filter.matches(["user", "name"], ["*", "name"]))
        XCTAssertTrue(filter.matches(["product", "name"], ["*", "name"]))
        XCTAssertFalse(filter.matches(["user", "metadata", "name"], ["*", "name"]))

        // * in the middle
        XCTAssertTrue(filter.matches(["user", "metadata", "item1"], ["user", "*", "item1"]))
        XCTAssertTrue(filter.matches(["user", "settings", "item1"], ["user", "*", "item1"]))
        XCTAssertFalse(filter.matches(["user", "item1"], ["user", "*", "item1"]))

        // Multiple * wildcards
        XCTAssertTrue(filter.matches(["user", "metadata", "item1"], ["*", "*", "item1"]))
        XCTAssertTrue(filter.matches(["a", "b", "c"], ["*", "*", "*"]))
    }

    func testMatchesDoubleWildcard() throws {
        let filter = ObjectFilter()

        // ** matches any number of levels (including 0)
        XCTAssertTrue(filter.matches(["user"], ["user", "**"]))
        XCTAssertTrue(filter.matches(["user", "name"], ["user", "**"]))
        XCTAssertTrue(filter.matches(["user", "metadata", "item1"], ["user", "**"]))
        XCTAssertTrue(filter.matches(["user", "metadata", "nested", "deep", "item"], ["user", "**"]))

        // ** at the beginning
        XCTAssertTrue(filter.matches(["user", "name"], ["**", "name"]))
        XCTAssertTrue(filter.matches(["deep", "nested", "user", "name"], ["**", "name"]))
        XCTAssertTrue(filter.matches(["name"], ["**", "name"]))

        // ** in the middle
        XCTAssertTrue(filter.matches(["user", "name"], ["user", "**", "name"]))
        XCTAssertTrue(filter.matches(["user", "metadata", "nested", "name"], ["user", "**", "name"]))
        XCTAssertTrue(filter.matches(["user", "name"], ["user", "**", "name"]))

        // ** at the end
        XCTAssertTrue(filter.matches(["user", "metadata"], ["**"]))
        XCTAssertTrue(filter.matches(["a"], ["**"]))
        XCTAssertTrue(filter.matches([], ["**"]))
    }

    func testMatchesArrayIndexes() throws {
        let filter = ObjectFilter()

        // Array index matching
        XCTAssertTrue(filter.matches(["users", "0"], ["users", "0"]))
        XCTAssertTrue(filter.matches(["users", "0", "name"], ["users", "0", "name"]))
        XCTAssertTrue(filter.matches(["users", "0", "name"], ["users", "*", "name"]))
        XCTAssertTrue(filter.matches(["users", "5", "metadata", "item"], ["users", "**", "item"]))

        XCTAssertFalse(filter.matches(["users", "0"], ["users", "1"]))
        XCTAssertFalse(filter.matches(["users", "abc"], ["users", "0"]))
    }

    func testMatchesComplexWildcardCombinations() throws {
        let filter = ObjectFilter()

        // Combining * and ** wildcards
        XCTAssertTrue(filter.matches(["user", "metadata", "nested", "item"], ["*", "**", "item"]))
        XCTAssertTrue(filter.matches(["user", "item"], ["*", "**", "item"]))
        XCTAssertTrue(filter.matches(["anything", "deep", "nested", "path", "item"], ["*", "**", "item"]))

        // ** followed by *
        XCTAssertTrue(filter.matches(["user", "metadata", "item1"], ["**", "*"]))
        XCTAssertTrue(filter.matches(["item1"], ["**", "*"]))
        XCTAssertFalse(filter.matches([], ["**", "*"]))
    }

    func testMatchesEdgeCases() throws {
        let filter = ObjectFilter()

        // Empty paths
        XCTAssertTrue(filter.matches([], []))
        XCTAssertTrue(filter.matches([], ["**"]))
        XCTAssertFalse(filter.matches([], ["*"]))
        XCTAssertFalse(filter.matches(["user"], []))

        // Single element paths
        XCTAssertTrue(filter.matches(["user"], ["user"]))
        XCTAssertTrue(filter.matches(["user"], ["*"]))
        XCTAssertTrue(filter.matches(["user"], ["**"]))

        // Numeric strings (array indexes)
        XCTAssertTrue(filter.matches(["0"], ["0"]))
        XCTAssertTrue(filter.matches(["123"], ["*"]))
        XCTAssertTrue(filter.matches(["0", "name"], ["*", "name"]))
    }

    func testMatchesCombinedWildcardPatterns() throws {
        let filter = ObjectFilter()

        // ** followed by * - matches any depth then exactly one more level
        XCTAssertTrue(filter.matches(["a", "b"], ["**", "*"]))
        XCTAssertTrue(filter.matches(["a", "b", "c", "d"], ["**", "*"]))
        XCTAssertTrue(filter.matches(["x"], ["**", "*"]))
        XCTAssertFalse(filter.matches([], ["**", "*"]))

        // * followed by ** - exactly one level then any depth
        XCTAssertTrue(filter.matches(["user"], ["*", "**"]))
        XCTAssertTrue(filter.matches(["user", "data"], ["*", "**"]))
        XCTAssertTrue(filter.matches(["user", "data", "nested", "deep"], ["*", "**"]))
        XCTAssertFalse(filter.matches([], ["*", "**"]))

        // ** with * in the middle
        XCTAssertTrue(filter.matches(["a", "b", "c", "d"], ["**", "*", "d"]))
        XCTAssertTrue(filter.matches(["x", "y", "d"], ["**", "*", "d"]))
        XCTAssertTrue(filter.matches(["c", "d"], ["**", "*", "d"]))
        XCTAssertFalse(filter.matches(["d"], ["**", "*", "d"]))

        // * with ** in the middle
        XCTAssertTrue(filter.matches(["a", "b", "c"], ["*", "**", "c"]))
        XCTAssertTrue(filter.matches(["x", "y", "z", "w", "c"], ["*", "**", "c"]))
        XCTAssertTrue(filter.matches(["a", "c"], ["*", "**", "c"]))
        XCTAssertFalse(filter.matches(["c"], ["*", "**", "c"]))

        // Multiple combinations
        XCTAssertTrue(filter.matches(["api", "v1", "users", "john", "profile"], ["*", "v1", "**", "profile"]))
        XCTAssertTrue(filter.matches(["api", "v1", "profile"], ["*", "v1", "**", "profile"]))
        XCTAssertFalse(filter.matches(["v1", "users", "profile"], ["*", "v1", "**", "profile"]))

        // Complex pattern: **/users/*/metadata/**
        XCTAssertTrue(filter.matches(["app", "users", "john", "metadata", "settings"], ["**", "users", "*", "metadata", "**"]))
        XCTAssertTrue(filter.matches(["users", "john", "metadata", "a", "b", "c"], ["**", "users", "*", "metadata", "**"]))
        XCTAssertTrue(filter.matches(["users", "123", "metadata"], ["**", "users", "*", "metadata", "**"]))
        XCTAssertFalse(filter.matches(["users", "metadata", "data"], ["**", "users", "*", "metadata", "**"]))
        XCTAssertFalse(filter.matches(["users", "john", "profile", "metadata"], ["**", "users", "*", "metadata", "**"]))

        // Pattern: */data/**/items/*
        XCTAssertTrue(filter.matches(["store", "data", "nested", "items", "item1"], ["*", "data", "**", "items", "*"]))
        XCTAssertTrue(filter.matches(["shop", "data", "items", "product"], ["*", "data", "**", "items", "*"]))
        XCTAssertTrue(filter.matches(["x", "data", "a", "b", "c", "items", "y"], ["*", "data", "**", "items", "*"]))
        XCTAssertFalse(filter.matches(["data", "items", "item1"], ["*", "data", "**", "items", "*"]))
        XCTAssertFalse(filter.matches(["store", "data", "items"], ["*", "data", "**", "items", "*"]))

        // Pattern with multiple * and **: */*/*/**
        XCTAssertTrue(filter.matches(["a", "b", "c"], ["*", "*", "*", "**"]))
        XCTAssertTrue(filter.matches(["a", "b", "c", "d", "e"], ["*", "*", "*", "**"]))
        XCTAssertFalse(filter.matches(["a", "b"], ["*", "*", "*", "**"]))

        // Pattern: **/*/*/**
        XCTAssertTrue(filter.matches(["a", "b"], ["**", "*", "*", "**"]))
        XCTAssertTrue(filter.matches(["x", "y", "z", "a", "b", "c"], ["**", "*", "*", "**"]))
        XCTAssertTrue(filter.matches(["a", "b", "c", "d"], ["**", "*", "*", "**"]))
        XCTAssertFalse(filter.matches(["a"], ["**", "*", "*", "**"]))
    }

    func testMatchesNestedWildcardScenarios() throws {
        let filter = ObjectFilter()

        // Test boundary conditions with combined wildcards

        // Pattern: user/**/config/*
        XCTAssertTrue(filter.matches(["user", "config", "database"], ["user", "**", "config", "*"]))
        XCTAssertTrue(filter.matches(["user", "app", "config", "cache"], ["user", "**", "config", "*"]))
        XCTAssertTrue(filter.matches(["user", "a", "b", "c", "config", "item"], ["user", "**", "config", "*"]))
        XCTAssertFalse(filter.matches(["user", "config"], ["user", "**", "config", "*"]))
        XCTAssertFalse(filter.matches(["user", "config", "nested", "value"], ["user", "**", "config", "*"]))

        // Pattern: logs/**/*/*
        XCTAssertTrue(filter.matches(["logs", "2024", "jan"], ["logs", "**", "*", "*"]))
        XCTAssertTrue(filter.matches(["logs", "error", "2024", "jan"], ["logs", "**", "*", "*"]))
        XCTAssertTrue(filter.matches(["logs", "a", "b", "c", "x", "y"], ["logs", "**", "*", "*"]))
        XCTAssertFalse(filter.matches(["logs", "single"], ["logs", "**", "*", "*"]))
        XCTAssertFalse(filter.matches(["logs"], ["logs", "**", "*", "*"]))

        // Pattern with alternating wildcards: */**/*/**/*
        XCTAssertTrue(filter.matches(["a", "b", "c"], ["*", "**", "*", "**", "*"]))
        XCTAssertTrue(filter.matches(["a", "b", "c", "d", "e"], ["*", "**", "*", "**", "*"]))
        XCTAssertTrue(filter.matches(["x", "y", "z", "w", "q", "r", "s"], ["*", "**", "*", "**", "*"]))
        XCTAssertFalse(filter.matches(["a", "b"], ["*", "**", "*", "**", "*"]))
        XCTAssertFalse(filter.matches([], ["*", "**", "*", "**", "*"]))
    }

    func testMatchesIllegalPatterns() throws {
        let filter = ObjectFilter()

        // Test patterns containing "//" (empty path segments)
        // These patterns have empty strings in the keypath array after splitting

        // Pattern with "//" at the beginning
        XCTAssertFalse(filter.matches(["user", "name"], ["", "user", "name"]))
        XCTAssertFalse(filter.matches(["name"], ["", "name"]))
        XCTAssertFalse(filter.matches([], ["", ""]))

        // Pattern with "//" in the middle
        XCTAssertFalse(filter.matches(["user", "name"], ["user", "", "name"]))
        XCTAssertFalse(filter.matches(["user", "metadata", "item"], ["user", "", "metadata", "item"]))
        XCTAssertFalse(filter.matches(["a", "b", "c"], ["a", "", "b", "c"]))

        // Pattern with "//" at the end
        XCTAssertFalse(filter.matches(["user", "name"], ["user", "name", ""]))
        XCTAssertFalse(filter.matches(["user"], ["user", ""]))

        // Multiple consecutive empty segments
        XCTAssertFalse(filter.matches(["user", "name"], ["", "", "user", "name"]))
        XCTAssertFalse(filter.matches(["user", "name"], ["user", "", "", "name"]))
        XCTAssertFalse(filter.matches(["user", "name"], ["user", "name", "", ""]))

        // Actual path with empty segments vs normal pattern
        XCTAssertFalse(filter.matches(["", "user", "name"], ["user", "name"]))
        XCTAssertFalse(filter.matches(["user", "", "name"], ["user", "name"]))
        XCTAssertFalse(filter.matches(["user", "name", ""], ["user", "name"]))

        // Both path and pattern with empty segments
        XCTAssertTrue(filter.matches(["user", "", "name"], ["user", "", "name"]))
        XCTAssertTrue(filter.matches(["", "data"], ["", "data"]))

        // Empty string in pattern should not match non-empty segment
        XCTAssertFalse(filter.matches(["user", "john", "name"], ["user", "", "name"]))
        XCTAssertFalse(filter.matches(["prefix", "user"], ["", "user"]))
    }
}

final class ObjectFilterTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - filterd function tests

    func testFilterdBasicDictionary() throws {
        // Test simple allowList
        let filter = ObjectFilter(allowList: ["user/name", "user/email"])
        let input: [String: Any] = [
            "user": [
                "name": "John",
                "email": "john@example.com",
                "password": "secret123"
            ],
            "product": [
                "name": "product_1"
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        XCTAssertNotNil(result)

        let userDict = result?["user"] as? [String: Any]
        XCTAssertNotNil(userDict)
        XCTAssertEqual(userDict?["name"] as? String, "John")
        XCTAssertEqual(userDict?["email"] as? String, "john@example.com")
        XCTAssertNil(userDict?["password"])
        XCTAssertNil(result?["product"])
    }

    func testFilterdWithBlockList() throws {
        // allowList with blockList override
        let filter = ObjectFilter(
            allowList: ["user/**"],
            blockList: ["user/password", "user/metadata/secret"]
        )

        let input: [String: Any] = [
            "user": [
                "name": "John",
                "email": "john@example.com",
                "password": "secret123",
                "metadata": [
                    "item1": 1,
                    "secret": "hidden"
                ]
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let userDict = result?["user"] as? [String: Any]
        XCTAssertEqual(userDict?["name"] as? String, "John")
        XCTAssertEqual(userDict?["email"] as? String, "john@example.com")
        XCTAssertNil(userDict?["password"])

        let metadata = userDict?["metadata"] as? [String: Any]
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata?["item1"] as? Int, 1)
        XCTAssertNil(metadata?["secret"])
    }

    func testFilterdWithSingleWildcard() throws {
        // Test * wildcard (matches exactly one level)
        let filter = ObjectFilter(allowList: ["user/*"])

        let input: [String: Any] = [
            "user": [
                "name": "John",
                "email": "john@example.com",
                "metadata": [
                    "item1": 1,
                    "item2": 2
                ],
                "tags": ["return", "tier3"]
            ],
            "product": [
                "name": "product_1"
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let userDict = result?["user"] as? [String: Any]

        XCTAssertEqual(userDict?["name"] as? String, "John")
        XCTAssertEqual(userDict?["email"] as? String, "john@example.com")

        // Containers should be preserved but empty
        XCTAssertNotNil(userDict?["metadata"])
        XCTAssertTrue((userDict?["metadata"] as? [String: Any])?.isEmpty ?? false)
        XCTAssertNotNil(userDict?["tags"])
        XCTAssertTrue((userDict?["tags"] as? [Any])?.isEmpty ?? false)

        XCTAssertNil(result?["product"])
    }

    func testFilterdWithDoubleWildcard() throws {
        // Test ** wildcard (matches any number of levels)
        let filter = ObjectFilter(allowList: ["user/**"])

        let input: [String: Any] = [
            "user": [
                "name": "John",
                "email": "john@example.com",
                "metadata": [
                    "item1": 1,
                    "item2": 2
                ],
                "tags": ["return", "tier3"]
            ],
            "product": [
                "name": "product_1"
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let userDict = result?["user"] as? [String: Any]

        XCTAssertEqual(userDict?["name"] as? String, "John")
        XCTAssertEqual(userDict?["email"] as? String, "john@example.com")

        // With **, nested content should be preserved
        let metadata = userDict?["metadata"] as? [String: Any]
        XCTAssertEqual(metadata?["item1"] as? Int, 1)
        XCTAssertEqual(metadata?["item2"] as? Int, 2)

        let tags = userDict?["tags"] as? [String]
        XCTAssertEqual(tags?.count, 2)
        XCTAssertEqual(tags?[0], "return")
        XCTAssertEqual(tags?[1], "tier3")

        XCTAssertNil(result?["product"])
    }

    func testFilterdWithArray() throws {
        // Test array filtering with index
        let filter = ObjectFilter(allowList: ["users/0", "users/1/name"])

        let input: [String: Any] = [
            "users": [
                ["name": "John", "email": "john@example.com"],
                ["name": "Jane", "email": "jane@example.com"],
                ["name": "Bob", "email": "bob@example.com"]
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let users = result?["users"] as? [[String: Any]]

        XCTAssertNotNil(users)
        XCTAssertEqual(users?.count, 2) // Array compacted: only users 0 (full) and 1 (name only)

        // First user should have all fields (original index 0)
        XCTAssertEqual(users?[0]["name"] as? String, "John")
        XCTAssertEqual(users?[0]["email"] as? String, "john@example.com")

        // Second user should only have name (original index 1, now at index 1)
        XCTAssertEqual(users?[1]["name"] as? String, "Jane")
        XCTAssertNil(users?[1]["email"])
    }

    func testFilterdArrayAtRoot() throws {
        let filter = ObjectFilter(allowList: ["0/name", "1"])

        let input: [Any] = [
            ["name": "John", "email": "john@example.com"],
            ["name": "Jane", "email": "jane@example.com"],
            ["name": "Bob", "email": "bob@example.com"]
        ]

        let result = filter.filterd(input) as? [Any]
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 2) // Array compacted: only items 0 (name only) and 1 (full)

        // First item should only have name (original index 0)
        let first = result?[0] as? [String: Any]
        XCTAssertEqual(first?["name"] as? String, "John")
        XCTAssertNil(first?["email"])

        // Second item should have all fields (original index 1, now at index 1)
        let second = result?[1] as? [String: Any]
        XCTAssertEqual(second?["name"] as? String, "Jane")
        XCTAssertEqual(second?["email"] as? String, "jane@example.com")
    }

    func testFilterdWildcardInMiddle() throws {
        let filter = ObjectFilter(allowList: ["users/*/metadata/public"])

        let input: [String: Any] = [
            "users": [
                "john": [
                    "metadata": [
                        "public": "visible",
                        "private": "hidden"
                    ]
                ],
                "jane": [
                    "metadata": [
                        "public": "also_visible",
                        "private": "also_hidden"
                    ]
                ]
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let users = result?["users"] as? [String: Any]

        let johnMeta = (users?["john"] as? [String: Any])?["metadata"] as? [String: Any]
        XCTAssertEqual(johnMeta?["public"] as? String, "visible")
        XCTAssertNil(johnMeta?["private"])

        let janeMeta = (users?["jane"] as? [String: Any])?["metadata"] as? [String: Any]
        XCTAssertEqual(janeMeta?["public"] as? String, "also_visible")
        XCTAssertNil(janeMeta?["private"])
    }

    func testFilterdComplexWildcards() throws {
        // Mix of wildcards
        let filter = ObjectFilter(allowList: ["**/name", "users/*/age"])

        let input: [String: Any] = [
            "name": "Root Name",
            "users": [
                "john": [
                    "name": "John",
                    "age": 30,
                    "email": "john@example.com"
                ],
                "jane": [
                    "name": "Jane",
                    "age": 25,
                    "email": "jane@example.com"
                ]
            ],
            "product": [
                "name": "Product Name",
                "price": 100
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]

        // Root name should be included
        XCTAssertEqual(result?["name"] as? String, "Root Name")

        // Product name should be included
        let product = result?["product"] as? [String: Any]
        XCTAssertEqual(product?["name"] as? String, "Product Name")
        XCTAssertNil(product?["price"])

        // Users should have name and age
        let users = result?["users"] as? [String: Any]
        let john = users?["john"] as? [String: Any]
        XCTAssertEqual(john?["name"] as? String, "John")
        XCTAssertEqual(john?["age"] as? Int, 30)
        XCTAssertNil(john?["email"])
    }

    // MARK: - Edge Cases

    func testFilterdEmptyAllowList() throws {
        let filter = ObjectFilter(allowList: [])

        let input: [String: Any] = ["key": "value"]
        let result = filter.filterd(input)

        XCTAssertNil(result)
    }

    func testFilterdEmptyBlockList() throws {
        let filter = ObjectFilter(
            allowList: ["user/name"],
            blockList: []
        )

        let input: [String: Any] = [
            "user": ["name": "John", "email": "john@example.com"]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let user = result?["user"] as? [String: Any]

        XCTAssertEqual(user?["name"] as? String, "John")
        XCTAssertNil(user?["email"])
    }

    func testFilterdPrimitiveRoot() throws {
        let filter = ObjectFilter(allowList: ["user"])

        // String at root - should return nil
        let result1 = filter.filterd("string value")
        XCTAssertNil(result1)

        // Number at root - should return nil
        let result2 = filter.filterd(42)
        XCTAssertNil(result2)

        // Bool at root - should return nil
        let result3 = filter.filterd(true)
        XCTAssertNil(result3)
    }

    func testFilterdNilInput() throws {
        let filter = ObjectFilter(allowList: ["user"])

        let result = filter.filterd(nil)
        XCTAssertNil(result)
    }

    func testFilterdNestedArrays() throws {
        let filter = ObjectFilter(allowList: ["data/0/items/*/name"])

        let input: [String: Any] = [
            "data": [
                [
                    "items": [
                        ["name": "item1", "price": 10],
                        ["name": "item2", "price": 20]
                    ]
                ]
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let data = result?["data"] as? [[String: Any]]
        let items = data?[0]["items"] as? [[String: Any]]

        XCTAssertEqual(items?[0]["name"] as? String, "item1")
        XCTAssertNil(items?[0]["price"])
        XCTAssertEqual(items?[1]["name"] as? String, "item2")
        XCTAssertNil(items?[1]["price"])
    }

    // MARK: - Combined * and ** Wildcard Tests

    func testFilterdCombinedWildcardStartWithDoubleEnd() throws {
        // Pattern: **/something/*
        let filter = ObjectFilter(allowList: ["**/metadata/*"])

        let input: [String: Any] = [
            "user": [
                "metadata": [
                    "public": "visible",
                    "private": "hidden",
                    "nested": [
                        "deep": "value"
                    ]
                ]
            ],
            "product": [
                "info": [
                    "metadata": [
                        "title": "Product",
                        "price": 100
                    ]
                ]
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]

        // Check user metadata - should include direct children only
        let userMeta = (result?["user"] as? [String: Any])?["metadata"] as? [String: Any]
        XCTAssertEqual(userMeta?["public"] as? String, "visible")
        XCTAssertEqual(userMeta?["private"] as? String, "hidden")
        XCTAssertNotNil(userMeta?["nested"])
        XCTAssertTrue((userMeta?["nested"] as? [String: Any])?.isEmpty ?? false)

        // Check product metadata
        let productMeta = ((result?["product"] as? [String: Any])?["info"] as? [String: Any])?["metadata"] as? [String: Any]
        XCTAssertEqual(productMeta?["title"] as? String, "Product")
        XCTAssertEqual(productMeta?["price"] as? Int, 100)
    }

    func testFilterdCombinedWildcardMiddlePattern() throws {
        // Pattern: */something/**
        let filter = ObjectFilter(allowList: ["*/users/**"])

        let input: [String: Any] = [
            "v1": [
                "users": [
                    "john": [
                        "name": "John",
                        "profile": [
                            "age": 30,
                            "address": [
                                "city": "NYC"
                            ]
                        ]
                    ]
                ]
            ],
            "v2": [
                "users": [
                    "jane": [
                        "name": "Jane",
                        "email": "jane@example.com"
                    ]
                ],
                "products": ["item1", "item2"]
            ],
            "users": [
                "direct": "should not match"
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]

        // v1/users should have all nested content
        let v1Users = (result?["v1"] as? [String: Any])?["users"] as? [String: Any]
        let john = v1Users?["john"] as? [String: Any]
        XCTAssertEqual(john?["name"] as? String, "John")
        let profile = john?["profile"] as? [String: Any]
        XCTAssertEqual(profile?["age"] as? Int, 30)
        let address = profile?["address"] as? [String: Any]
        XCTAssertEqual(address?["city"] as? String, "NYC")

        // v2/users should have all content
        let v2Users = (result?["v2"] as? [String: Any])?["users"] as? [String: Any]
        let jane = v2Users?["jane"] as? [String: Any]
        XCTAssertEqual(jane?["name"] as? String, "Jane")
        XCTAssertEqual(jane?["email"] as? String, "jane@example.com")

        // v2/products should not exist
        XCTAssertNil((result?["v2"] as? [String: Any])?["products"])

        // Direct users should not match (needs exactly one level before)
        XCTAssertNil(result?["users"])
    }

    func testFilterdCombinedWildcardComplexPattern() throws {
        // Pattern: */**/items/*/details
        let filter = ObjectFilter(allowList: ["*/**/items/*/details"])

        let input: [String: Any] = [
            "store": [
                "inventory": [
                    "items": [
                        "item1": [
                            "details": "Item 1 Details",
                            "price": 10
                        ],
                        "item2": [
                            "details": "Item 2 Details",
                            "price": 20
                        ]
                    ]
                ]
            ],
            "warehouse": [
                "section": [
                    "subsection": [
                        "items": [
                            "prod1": [
                                "details": "Product 1",
                                "stock": 100
                            ]
                        ]
                    ]
                ]
            ],
            "items": [  // Should not match - needs at least one level before
                "direct": [
                    "details": "Should not appear"
                ]
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]

        // Check store path
        let storeItems = ((result?["store"] as? [String: Any])?["inventory"] as? [String: Any])?["items"] as? [String: Any]
        let item1 = storeItems?["item1"] as? [String: Any]
        XCTAssertEqual(item1?["details"] as? String, "Item 1 Details")
        XCTAssertNil(item1?["price"])

        let item2 = storeItems?["item2"] as? [String: Any]
        XCTAssertEqual(item2?["details"] as? String, "Item 2 Details")
        XCTAssertNil(item2?["price"])

        // Check warehouse path
        let warehouseItems = ((((result?["warehouse"] as? [String: Any])?["section"] as? [String: Any])?["subsection"] as? [String: Any])?["items"] as? [String: Any])
        let prod1 = warehouseItems?["prod1"] as? [String: Any]
        XCTAssertEqual(prod1?["details"] as? String, "Product 1")
        XCTAssertNil(prod1?["stock"])

        // Direct items should not exist
        XCTAssertNil(result?["items"])
    }

    func testFilterdCombinedWildcardWithArrays() throws {
        // Pattern: data/**/*/*/name
        let filter = ObjectFilter(allowList: ["data/**/*/*/name"])

        let input: [String: Any] = [
            "data": [
                "admin": ["name": "Admin", "role": 100],
                "users": [
                    "list": [
                        ["name": "User1", "id": 1],
                        ["name": "User2", "id": 2]
                    ]
                ],
                "products": [
                    "items": [
                        "electronics": [
                            "laptop": ["name": "MacBook", "price": 2000],
                            "phone": ["name": "iPhone", "price": 1000]
                        ]
                    ]
                ]
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let data = result?["data"] as? [String: Any]

        // admin/name should not be included as only one level from data
        XCTAssertNil(data?["admin"])

        // Check users/list array
        let usersList = ((data?["users"] as? [String: Any])?["list"] as? [[String: Any]])
        XCTAssertEqual(usersList?[0]["name"] as? String, "User1")
        XCTAssertNil(usersList?[0]["id"])
        XCTAssertEqual(usersList?[1]["name"] as? String, "User2")
        XCTAssertNil(usersList?[1]["id"])

        // Check products/items/electronics
        let electronics = (((data?["products"] as? [String: Any])?["items"] as? [String: Any])?["electronics"] as? [String: Any])
        let laptop = electronics?["laptop"] as? [String: Any]
        XCTAssertEqual(laptop?["name"] as? String, "MacBook")
        XCTAssertNil(laptop?["price"])

        let phone = electronics?["phone"] as? [String: Any]
        XCTAssertEqual(phone?["name"] as? String, "iPhone")
        XCTAssertNil(phone?["price"])
    }

    func testFilterdMultipleCombinedPatterns() throws {
        // Multiple patterns with different combinations
        let filter = ObjectFilter(
            allowList: [
                "**/config/*",      // ** followed by *
                "api/*/response",   // * in middle
                "logs/**"           // ** at end
            ]
        )

        let input: [String: Any] = [
            "system": [
                "config": [
                    "database": "mysql",
                    "cache": "redis",
                    "nested": [
                        "deep": "value"
                    ]
                ]
            ],
            "api": [
                "v1": [
                    "response": "API v1 response",
                    "request": "API v1 request"
                ],
                "v2": [
                    "response": "API v2 response"
                ]
            ],
            "logs": [
                "error": [
                    "2024": [
                        "jan": ["error1", "error2"]
                    ]
                ],
                "info": "Some info logs"
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]

        // Check config pattern
        let config = (result?["system"] as? [String: Any])?["config"] as? [String: Any]
        XCTAssertEqual(config?["database"] as? String, "mysql")
        XCTAssertEqual(config?["cache"] as? String, "redis")
        XCTAssertNotNil(config?["nested"])
        XCTAssertTrue((config?["nested"] as? [String: Any])?.isEmpty ?? false)

        // Check API pattern
        let api = result?["api"] as? [String: Any]
        let v1 = api?["v1"] as? [String: Any]
        XCTAssertEqual(v1?["response"] as? String, "API v1 response")
        XCTAssertNil(v1?["request"])

        let v2 = api?["v2"] as? [String: Any]
        XCTAssertEqual(v2?["response"] as? String, "API v2 response")

        // Check logs pattern (everything under logs)
        let logs = result?["logs"] as? [String: Any]
        let errorLogs = logs?["error"] as? [String: Any]
        let year2024 = errorLogs?["2024"] as? [String: Any]
        let jan = year2024?["jan"] as? [String]
        XCTAssertEqual(jan?.count, 2)
        XCTAssertEqual(logs?["info"] as? String, "Some info logs")
    }

    func testArrayIndexFiltering() {
        let filter = ObjectFilter(
            allowList: ["items/0", "items/2"],
            blockList: []
        )

        let input: [String: Any] = [
            "items": ["first", "second", "third", "fourth"]
        ]

        let filtered = filter.filterd(input) as? [String: Any]
        XCTAssertNotNil(filtered)

        let items = filtered?["items"] as? [String]
        XCTAssertNotNil(items)
        XCTAssertEqual(items?.count, 2) // Array is compacted
        XCTAssertEqual(items?[0], "first")  // Original index 0
        XCTAssertEqual(items?[1], "third")  // Original index 2, now at index 1
    }

    func testEmptyStructures() {
        let filter = ObjectFilter(
            allowList: ["data/**", "array/**"],
            blockList: []
        )

        let body: [String: Any] = [
            "data": [:],
            "array": []
        ]

        let filtered = filter.filterd(body) as? [String: Any]
        XCTAssertNotNil(filtered)
        XCTAssertNotNil(filtered?["data"])
        XCTAssertNotNil(filtered?["array"])
    }

    func testDeepWildcardThenStar() {
        // Pattern: "**/*" - match any path with at least one level
        let filter = ObjectFilter(
            allowList: ["**/*"],
            blockList: []
        )

        let body: [String: Any] = [
            "level1": "value1",
            "nested": [
                "level2": "value2",
                "deeper": [
                    "level3": "value3"
                ]
            ]
        ]

        let filtered = filter.filterd(body) as? [String: Any]
        XCTAssertNotNil(filtered)

        // level1 should be included (matches **/* pattern)
        XCTAssertEqual(filtered?["level1"] as? String, "value1")

        // nested should be included with its direct children
        let nested = filtered?["nested"] as? [String: Any]
        XCTAssertNotNil(nested)
        XCTAssertEqual(nested?["level2"] as? String, "value2")

        // deeper matches as a container, should be preserved with its contents
        let deeper = nested?["deeper"] as? [String: Any]
        XCTAssertNotNil(deeper)
        XCTAssertEqual(deeper?["level3"] as? String, "value3")
    }

    func testWildcardWithArrayIndices() {
        // Pattern: "results/*/items/0" - first item of each result
        let filter = ObjectFilter(
            allowList: ["results/*/items/0"],
            blockList: []
        )

        let body: [String: Any] = [
            "results": [
                "search1": [
                    "items": ["first", "second", "third"],
                    "count": 3
                ],
                "search2": [
                    "items": ["alpha", "beta"],
                    "count": 2
                ]
            ]
        ]

        let filtered = filter.filterd(body) as? [String: Any]
        XCTAssertNotNil(filtered)

        let results = filtered?["results"] as? [String: Any]
        let search1 = results?["search1"] as? [String: Any]
        let items1 = search1?["items"] as? [String]
        XCTAssertEqual(items1?.count, 1) // Array compacted to only the first item
        XCTAssertEqual(items1?[0], "first")
        XCTAssertNil(search1?["count"]) // count field should be excluded

        let search2 = results?["search2"] as? [String: Any]
        let items2 = search2?["items"] as? [String]
        XCTAssertEqual(items2?.count, 1) // Array compacted to only the first item
        XCTAssertEqual(items2?[0], "alpha")
    }

    func testArrayCompactionWithAllowList() {
        // Test the specific use case: ["one", "two", "three"] with allowList ["0", "2"]
        let filter = ObjectFilter(
            allowList: ["0", "2"],
            blockList: []
        )

        let input: [Any] = ["one", "two", "three"]

        let result = filter.filterd(input) as? [String]
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?[0], "one")   // Original index 0
        XCTAssertEqual(result?[1], "three") // Original index 2, now at index 1
    }

    func testArrayCompactionWithBlockList() {
        // Test the specific use case: ["one", "two", "three"] with blockList ["1"]
        let filter = ObjectFilter(
            allowList: ["**"], // Allow everything
            blockList: ["1"]
        )

        let input: [Any] = ["one", "two", "three"]

        let result = filter.filterd(input) as? [String]
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?[0], "one")   // Original index 0
        XCTAssertEqual(result?[1], "three") // Original index 2, now at index 1
    }

    // MARK: - BlockList with Wildcard Tests

    func testBlockListWithSingleWildcard() {
        // Block all direct children of user with * wildcard
        let filter = ObjectFilter(
            allowList: ["user/**"],
            blockList: ["user/*/password"]
        )

        let input: [String: Any] = [
            "user": [
                "john": [
                    "name": "John Doe",
                    "email": "john@example.com",
                    "password": "secret123"
                ],
                "jane": [
                    "name": "Jane Smith",
                    "email": "jane@example.com",
                    "password": "secret456"
                ]
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let userDict = result?["user"] as? [String: Any]

        // Check john's data
        let john = userDict?["john"] as? [String: Any]
        XCTAssertEqual(john?["name"] as? String, "John Doe")
        XCTAssertEqual(john?["email"] as? String, "john@example.com")
        XCTAssertNil(john?["password"]) // Should be blocked by user/*/password

        // Check jane's data
        let jane = userDict?["jane"] as? [String: Any]
        XCTAssertEqual(jane?["name"] as? String, "Jane Smith")
        XCTAssertEqual(jane?["email"] as? String, "jane@example.com")
        XCTAssertNil(jane?["password"]) // Should be blocked by user/*/password
    }

    func testBlockListWithDoubleWildcard() {
        // Block all fields named "secret" at any level with ** wildcard
        let filter = ObjectFilter(
            allowList: ["data/**"],
            blockList: ["**/secret"]
        )

        let input: [String: Any] = [
            "data": [
                "user": [
                    "name": "User",
                    "secret": "user_secret",
                    "nested": [
                        "info": "public",
                        "secret": "nested_secret"
                    ]
                ],
                "config": [
                    "setting": "value",
                    "secret": "config_secret"
                ]
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let data = result?["data"] as? [String: Any]

        // Check user data
        let user = data?["user"] as? [String: Any]
        XCTAssertEqual(user?["name"] as? String, "User")
        XCTAssertNil(user?["secret"]) // Blocked by **/secret

        let nested = user?["nested"] as? [String: Any]
        XCTAssertEqual(nested?["info"] as? String, "public")
        XCTAssertNil(nested?["secret"]) // Blocked by **/secret

        // Check config data
        let config = data?["config"] as? [String: Any]
        XCTAssertEqual(config?["setting"] as? String, "value")
        XCTAssertNil(config?["secret"]) // Blocked by **/secret
    }

    func testBlockListWithCombinedWildcards() {
        // Complex pattern: block specific nested paths
        let filter = ObjectFilter(
            allowList: ["api/**"],
            blockList: ["api/*/internal/**", "api/**/debug"]
        )

        let input: [String: Any] = [
            "api": [
                "v1": [
                    "public": "data1",
                    "internal": [
                        "secret1": "hidden1",
                        "secret2": "hidden2"
                    ],
                    "debug": "debug_info_v1"
                ],
                "v2": [
                    "public": "data2",
                    "internal": [
                        "config": "internal_config"
                    ],
                    "nested": [
                        "debug": "nested_debug",
                        "info": "public_info"
                    ]
                ]
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let api = result?["api"] as? [String: Any]

        // Check v1
        let v1 = api?["v1"] as? [String: Any]
        XCTAssertEqual(v1?["public"] as? String, "data1")
        XCTAssertNil(v1?["internal"]) // Blocked by api/*/internal/**
        XCTAssertNil(v1?["debug"]) // Blocked by api/**/debug

        // Check v2
        let v2 = api?["v2"] as? [String: Any]
        XCTAssertEqual(v2?["public"] as? String, "data2")
        XCTAssertNil(v2?["internal"]) // Blocked by api/*/internal/**

        let nested = v2?["nested"] as? [String: Any]
        XCTAssertNil(nested?["debug"]) // Blocked by api/**/debug
        XCTAssertEqual(nested?["info"] as? String, "public_info")
    }

    func testBlockListWithArrayWildcards() {
        // Block specific array indices using wildcards
        let filter = ObjectFilter(
            allowList: ["data/**"],
            blockList: ["data/items/*/private", "data/**/0"]
        )

        let input: [String: Any] = [
            "data": [
                "items": [
                    ["name": "Item1", "private": "secret1", "public": "info1"],
                    ["name": "Item2", "private": "secret2", "public": "info2"],
                    ["name": "Item3", "private": "secret3", "public": "info3"]
                ],
                "nested": [
                    "list": ["first", "second", "third"]
                ]
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let data = result?["data"] as? [String: Any]

        // Check items array - should be compacted (first item blocked by data/**/0)
        let items = data?["items"] as? [[String: Any]]
        XCTAssertNotNil(items)
        XCTAssertEqual(items?.count, 2) // Array compacted: items 1 and 2 remain

        // First item in result should be Item2 (original index 1)
        XCTAssertEqual(items?[0]["name"] as? String, "Item2")
        XCTAssertNil(items?[0]["private"]) // Blocked by data/items/*/private
        XCTAssertEqual(items?[0]["public"] as? String, "info2")

        // Second item in result should be Item3 (original index 2)
        XCTAssertEqual(items?[1]["name"] as? String, "Item3")
        XCTAssertNil(items?[1]["private"]) // Blocked by data/items/*/private
        XCTAssertEqual(items?[1]["public"] as? String, "info3")

        // Check nested list - should be compacted (first item blocked by data/**/0)
        let nestedList = (data?["nested"] as? [String: Any])?["list"] as? [String]
        XCTAssertNotNil(nestedList)
        XCTAssertEqual(nestedList?.count, 2) // Array compacted: "second" and "third" remain
        XCTAssertEqual(nestedList?[0], "second")
        XCTAssertEqual(nestedList?[1], "third")
    }

    func testBlockListPriorityOverAllowList() {
        // Test that blockList has higher priority than allowList even with wildcards
        let filter = ObjectFilter(
            allowList: ["**"],  // Allow everything
            blockList: ["**/password", "*/temp/*", "logs/**"]
        )

        let input: [String: Any] = [
            "user": [
                "name": "Alice",
                "password": "secret"
            ],
            "cache": [
                "temp": [
                    "file1": "temp_data",
                    "file2": "temp_data2"
                ],
                "permanent": "keep_this"
            ],
            "logs": [
                "error": "error_log",
                "info": "info_log"
            ],
            "config": [
                "settings": "value"
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]

        // Check user - password should be blocked
        let user = result?["user"] as? [String: Any]
        XCTAssertEqual(user?["name"] as? String, "Alice")
        XCTAssertNil(user?["password"]) // Blocked by **/password

        // Check cache - temp folder should be blocked
        let cache = result?["cache"] as? [String: Any]
        XCTAssertNil(cache?["temp"]) // Blocked by */temp/*
        XCTAssertEqual(cache?["permanent"] as? String, "keep_this")

        // Check logs - entire logs should be blocked
        XCTAssertNil(result?["logs"]) // Blocked by logs/**

        // Check config - should be allowed
        let config = result?["config"] as? [String: Any]
        XCTAssertEqual(config?["settings"] as? String, "value")
    }

    func testBlockListWithMiddleWildcards() {
        // Test wildcards in the middle of patterns
        let filter = ObjectFilter(
            allowList: ["app/**"],
            blockList: ["app/*/config/*/secret", "app/**/metadata/internal"]
        )

        let input: [String: Any] = [
            "app": [
                "module1": [
                    "config": [
                        "database": [
                            "host": "localhost",
                            "secret": "db_password"
                        ],
                        "cache": [
                            "type": "redis",
                            "secret": "cache_key"
                        ]
                    ],
                    "metadata": [
                        "public": "visible",
                        "internal": "hidden"
                    ]
                ],
                "module2": [
                    "config": [
                        "api": [
                            "endpoint": "https://api.example.com",
                            "secret": "api_key"
                        ]
                    ],
                    "nested": [
                        "metadata": [
                            "internal": "also_hidden",
                            "external": "visible"
                        ]
                    ]
                ]
            ]
        ]

        let result = filter.filterd(input) as? [String: Any]
        let app = result?["app"] as? [String: Any]

        // Check module1
        let module1 = app?["module1"] as? [String: Any]
        let config1 = module1?["config"] as? [String: Any]

        let database = config1?["database"] as? [String: Any]
        XCTAssertEqual(database?["host"] as? String, "localhost")
        XCTAssertNil(database?["secret"]) // Blocked by app/*/config/*/secret

        let cache = config1?["cache"] as? [String: Any]
        XCTAssertEqual(cache?["type"] as? String, "redis")
        XCTAssertNil(cache?["secret"]) // Blocked by app/*/config/*/secret

        let metadata1 = module1?["metadata"] as? [String: Any]
        XCTAssertEqual(metadata1?["public"] as? String, "visible")
        XCTAssertNil(metadata1?["internal"]) // Blocked by app/**/metadata/internal

        // Check module2
        let module2 = app?["module2"] as? [String: Any]
        let config2 = module2?["config"] as? [String: Any]
        let api = config2?["api"] as? [String: Any]
        XCTAssertEqual(api?["endpoint"] as? String, "https://api.example.com")
        XCTAssertNil(api?["secret"]) // Blocked by app/*/config/*/secret

        let nested = module2?["nested"] as? [String: Any]
        let metadata2 = nested?["metadata"] as? [String: Any]
        XCTAssertNil(metadata2?["internal"]) // Blocked by app/**/metadata/internal
        XCTAssertEqual(metadata2?["external"] as? String, "visible")
    }

    func testBlockListEdgeCases() {
        // Test edge cases with wildcards in blockList
        let filter = ObjectFilter(
            allowList: ["root/**"],
            blockList: ["**", "!root/keep"] // Block everything (though allowList limits this)
        )

        let input: [String: Any] = [
            "root": [
                "keep": "this_should_be_blocked",
                "other": "also_blocked"
            ],
            "outside": "not_in_allowlist"
        ]

        let result = filter.filterd(input) as? [String: Any]

        // Everything should be blocked by ** in blockList
        // Note: "!root/keep" is not a valid pattern (! is not supported),
        // so it won't unblock anything
        XCTAssertNil(result) // Everything is blocked
    }
}
