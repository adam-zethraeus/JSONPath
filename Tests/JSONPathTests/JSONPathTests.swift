@testable import JSONPath
import XCTest

struct User: Codable, Hashable {
    let name: String
    let age: Int
    let country: String
    let imageUrl: URL?
}

struct Team: Codable, Hashable {
    let id: UUID
    let name: String
    let lead: User
    let members: [User]
}

struct Server: Codable, Hashable {
    let teams: [Team]
    let name: String
    let thing💥: String
    let admin: User
}

final class DiffTests: XCTestCase {
//    func testExample() {
//        let userA = User(name: "Bob", age: 10, country: "Japan", imageUrl: URL(string: "https://example.com"))
//        let userB = User(name: "Bob", age: 20, country: "United States", imageUrl: nil)
//
//        let diff = Diff(from: userA, to: userB)
//        XCTAssertEqual(diff.count, 4)
//        XCTAssertEqual(diff["age"]?.to, 20)
//        XCTAssertEqual(diff["age"]?.from, 10)
//
//        XCTAssertEqual(diff["country"]?.to, "United States")
//        XCTAssertEqual(diff["country"]?.from, "Japan")
//
//        XCTAssertEqual(diff["imageUrl"]?.to, nil)
//        XCTAssertEqual(diff["imageUrl"]?.from, URL(string: "https://example.com")!)
//    }

    static let bob: User = .init(
        name: "Bob",
        age: 10,
        country: "Japan",
        imageUrl: URL(string: "https://example.com")
    )

    static let roberto: User = .init(
        name: "Roberto",
        age: 20,
        country: "United States",
        imageUrl: nil
    )

    static let anna: User = .init(
        name: "4NN4",
        age: 17,
        country: "7h3 w38",
        imageUrl: nil
    )

    static let billy: User = .init(
        name: "b1lly",
        age: 16,
        country: "7h3 w38",
        imageUrl: nil
    )

    static let server = Server(
        teams: [
            .init(
                id: UUID(uuidString: "8B5200BF-7B22-4499-A4E1-EB153A22A095")!,
                name: "Bob's team",
                lead: bob,
                members: [
                    bob,
                    roberto,
                ]
            ),
            .init(
                id: UUID(uuidString: "684A4F03-A663-452B-A971-C4C28CB0C191")!,
                name: "pin34ppl3",
                lead: anna,
                members: [
                    anna,
                    billy,
                ]
            ),
        ],
        name: "Bob's Server",
        thing💥: "hi.",
        admin: .init(
            name: "Bob",
            age: 10,
            country: "Japan",
            imageUrl: URL(string: "https://example.com")
        )
    )

    static let serverJSON = (try? server.json())!

    func testJSONPath() throws {
        let json = Self.serverJSON
        try XCTAssertEqual(json[".name.", as: String.self], "Bob's Server")
        try XCTAssertEqual(json["."], Self.serverJSON)
        try XCTAssertEqual(json[".", as: Server.self], Self.server)
        try XCTAssertEqual(json[".admin.", as: User.self], Self.bob)
        try XCTAssertEqual(json[".teams.[1].members.[0].", as: User.self], Self.anna)
        try XCTAssertEqual(json[".teams.[1].members.[1].", as: User.self], Self.billy)
        try XCTAssertEqual(json[".[\"teams\"].[1].members.[1].", as: User.self], Self.billy)
        try XCTAssertEqual(json[".[\"teams\"].[0].[\"members\"].[1].", as: User.self], Self.roberto)
        try XCTAssertThrowsError(json[".[\"teams\"].[a].[\"members\"].[1].country"]) {
            let fail = $0 as? JSON.Path.Fail
            XCTAssertEqual(fail?.code, "BAD_SYNTAX")
            XCTAssertEqual(fail?.prefix, ".[\"teams\"]")
        }
        try XCTAssertThrowsError(json[".[\"teams\"].a.[\"members\"].[1].country", as: String.self]) {
            let fail = $0 as? JSON.Access.Fail
            XCTAssertEqual(fail?.code, "BAD_PATH")
            XCTAssertEqual(fail?.prefix, ".[\"teams\"]")
        }
        try XCTAssertEqual(json[".teams.[0].members.[1].country", as: String.self], "United States")
        try XCTAssertEqual(json[".teams.[0].members.[0].imageUrl", as: URL.self], URL(string: "https://example.com"))
        try XCTAssertThrowsError(json[".thing💥", as: String.self]) {
            let fail = $0 as? JSON.Path.Fail
            XCTAssertEqual(fail?.code, "BAD_SYNTAX")
            XCTAssertEqual(fail?.prefix, ".thing")
            XCTAssertEqual(fail?.failure, "💥")
        }
        try XCTAssertEqual(json[".[\"thing%F0%9F%92%A5\"].", as: String.self], "hi.")
    }
}
