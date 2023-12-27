import Foundation
import RegexBuilder
//
// public struct Diff<T: Encodable> {
//    public var startIndex: Dictionary<String, (from: AnyHashable?, to: AnyHashable?)>.Index { dic.startIndex }
//
//    public var endIndex: Dictionary<String, (from: AnyHashable?, to: AnyHashable?)>.Index { dic.endIndex }
//
//    private let dic: [String: (from: AnyHashable?, to: AnyHashable?)]
//
//    public init(from fromValue: T, to toValue: T) {
//        let fromValue = fromValue.dict()
//        let toValue = toValue.dict()
//        let allKeys = Set(fromValue.keys).union(Set(toValue.keys))
//        self.dic = allKeys.reduce(into: [:]) { acc, key in
//            acc[key] = (from: fromValue[key].flat(), to: toValue[key].flat())
//        }
//    }
//
//    public subscript(it: String) -> (from: AnyHashable?, to: AnyHashable?)? {
//        dic[it]
//    }
//
//    public var count: Int { dic.count }
//    public var keys: [String] { [] + dic.keys }
//
// }
//
// protocol Flattenable {
//    associatedtype T
//    func flat() -> Optional<T>
// }
//
// extension Optional: Flattenable {
//    func flat() -> Optional<Wrapped> {
//        self
//    }
//
//    func flat<X>() -> Optional<X> where Wrapped: Flattenable, Wrapped.T == X {
//        switch self {
//        case .some(let wrapped): wrapped.flat()
//        default: .none
//        }
//    }
// }

public extension Encodable {
    func json() throws -> JSON {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(JSON.self, from: data)
    }
//    func dict() -> [String: AnyHashable?] {
//        return Mirror(reflecting: self).children.compactMap { it -> (label: String, value: Any)? in if case .some(let label) = it.label { (label: label, value: it.value) } else { nil } }.reduce(into: [String: AnyHashable]()) { acc, curr in
//            acc[curr.label] = (curr.value as? any Hashable).map { .init($0) } ?? nil
//        }
//    }
}

public indirect enum JSON: Codable, Hashable {
    public indirect enum Path: Codable, Hashable, LosslessStringConvertible {
        public init?(_ description: String) {
            try? self.init(string: description)
        }

        static let indexCapture = Regex {
            ".["
            Capture {
                OneOrMore {
                    .digit
                }
            }
            "]"
        }

        static let dictIndexCapture = Regex {
            ".[\""
            Capture {
                OneOrMore {
                    .digit.union(.word).union(.anyOf("%"))
                }
            }
            "\"]"
        }

        static let dictDotCapture = Regex {
            "."
            Capture {
                OneOrMore {
                    .digit.union(.word)
                }
            }
        }

        public init(string path: String) throws {
            try self.init(strSlice: path[path.startIndex...])
        }

        init(strSlice: String.SubSequence) throws {
            if strSlice.count < 1 {
                self = .empty
            } else if strSlice == "." {
                self = .empty
            } else if let match = strSlice.prefixMatch(of: Self.indexCapture) {
                let rest = strSlice[match.range.upperBound...]
                let index = try Int(match.output.1).orThrow(
                    Fail.badInt("\(match.output.1)", suffix: rest)
                )
                do {
                    let tail = try Path(strSlice: rest)
                    self = .index(index, tail: tail)
                } catch let error as Fail {
                    throw error.with(prefix: strSlice[strSlice.startIndex ..< match.range.upperBound])
                } catch {
                    throw Fail.unexpected(error: error, at: strSlice)
                }
            } else if let match = strSlice.prefixMatch(of: Self.dictIndexCapture) {
                let rest = strSlice[match.range.upperBound...]
                let dictIndex = try match.output.1.removingPercentEncoding.orThrow(
                    Fail.badEncode("\(match.output.1)", suffix: rest)
                )
                do {
                    let tail = try Path(strSlice: rest)
                    self = .key(dictIndex, tail: tail)
                } catch let error as Fail {
                    throw error.with(prefix: strSlice[strSlice.startIndex ..< match.range.upperBound])
                } catch {
                    throw Fail.unexpected(error: error, at: strSlice)
                }
            } else if let match = strSlice.prefixMatch(of: Self.dictDotCapture) {
                let rest = strSlice[match.range.upperBound...]
                let dictDot = match.output.1
                guard dictDot.count > 0
                else {
                    throw Fail.badEmpty(dictDot, suffix: rest)
                }
                do {
                    let tail = try Path(strSlice: rest)
                    self = .key("\(dictDot)", tail: tail)
                } catch let error as Fail {
                    throw error.with(prefix: strSlice[strSlice.startIndex ..< match.range.upperBound])
                } catch {
                    throw Fail.unexpected(error: error, at: strSlice)
                }
            } else {
                throw Fail.badSyntax(strSlice)
            }
        }

        struct Fail: Error {
            let code: String
            let prefix: String
            let failure: String
            let suffix: String?

            static func unexpected(error: some Error, at path: some LosslessStringConvertible) -> Fail {
                .init(code: "ILLEGAL", prefix: "", failure: path.description, suffix: error.localizedDescription)
            }

            static func badSyntax(_ path: some LosslessStringConvertible) -> Fail {
                .init(code: "BAD_SYNTAX", prefix: "", failure: path.description, suffix: nil)
            }

            static func badEncode(_ path: some LosslessStringConvertible, suffix: (some LosslessStringConvertible)? = nil) -> Fail {
                .init(code: "BAD_ENCODE", prefix: "", failure: path.description, suffix: suffix?.description)
            }

            static func badInt(_ path: some LosslessStringConvertible, suffix: (some LosslessStringConvertible)? = nil) -> Fail {
                .init(code: "BAD_INT", prefix: "", failure: path.description, suffix: suffix?.description)
            }

            static func badEmpty(_ path: some LosslessStringConvertible, suffix: (some LosslessStringConvertible)? = nil) -> Fail {
                .init(code: "BAD_EMPTY", prefix: "", failure: path.description, suffix: suffix?.description)
            }

            func with(prefix: some LosslessStringConvertible) -> Fail {
                .init(code: code, prefix: "\(prefix)\(self.prefix)", failure: failure, suffix: suffix)
            }
        }

        public var description: String {
            let (head, tail) = descriptionSegments
            return "\(head)\(tail)"
        }

        public var descriptionSegments: (head: String, tail: String) {
            switch self {
            case let .key(string, tail):
                if string.allSatisfy({ $0.isLetter || $0.isNumber }) {
                    (head: ".[\"\(string.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")\"]", tail: tail.description)
                } else {
                    (head: ".\(string)", tail: tail.description)
                }
            case let .index(int, tail):
                (head: ".[\(int)]", tail: tail.description)
            case .empty:
                (head: ".", tail: "")
            }
        }

        case key(String, tail: Path)
        case index(Int, tail: Path)
        case empty

        public func extract(from json: JSON) throws -> JSON {
            switch (self, json) {
            case let (.key(key, tail), .dictionary(dict)):
                let sub = try dict[key].orThrow(Access.Fail(code: "NULL_VALUE", prefix: "", failure: descriptionSegments.head, suffix: descriptionSegments.tail))
                do {
                    return try tail.extract(from: sub)
                } catch let error as Access.Fail {
                    throw error.with(prefix: descriptionSegments.head)
                }

            case let (.index(int, tail), .array(array)):
                guard array.count > int
                else {
                    throw Access.Fail(code: "BAD_INDEX", prefix: "", failure: descriptionSegments.head, suffix: descriptionSegments.tail)
                }
                do {
                    return try tail.extract(from: array[int])
                } catch let error as Access.Fail {
                    throw error.with(prefix: descriptionSegments.head)
                }

            case let (.empty, json):
                return json

            default:
                throw Access.Fail(code: "BAD_PATH", prefix: "", failure: description, suffix: nil)
            }
        }

        static func + (lhs: Path, rhs: Path) -> Path {
            switch lhs {
            case let .key(string, tail):
                .key(string, tail: tail + rhs)
            case let .index(int, tail):
                .index(int, tail: tail + rhs)
            case .empty:
                rhs
            }
        }
    }

    public enum Access {
        public struct Fail: Error {
            let code: String
            let prefix: String
            let failure: String
            let suffix: String?

            func with(prefix: some LosslessStringConvertible) -> Fail {
                .init(code: code, prefix: "\(prefix)\(self.prefix)", failure: failure, suffix: suffix)
            }
        }
    }

    case dictionary([String: JSON])
    case array([JSON])
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null

    // MARK: Lifecycle

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let numericValue = try? container.decode(Double.self) {
            self = .number(numericValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([JSON].self) {
            self = .array(arrayValue)
        } else {
            self = try .dictionary(container.decode([String: JSON].self))
        }
    }

    // MARK: Public

    public var payload: String {
        (try? JSONEncoder().encode(self)).flatMap {
            String(data: $0, encoding: .utf8)
        } ?? "[??]"
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case let .dictionary(dictionary):
            var container = encoder.container(keyedBy: Key.self)
            for (k, v) in dictionary {
                try container.encode(v, forKey: Key(k))
            }
        case let .array(array):
            var container = encoder.unkeyedContainer()
            for i in array {
                try container.encode(i)
            }
        case let .string(string):
            var container = encoder.singleValueContainer()
            try container.encode(string)
        case let .number(double):
            var container = encoder.singleValueContainer()
            try container.encode(double)
        case let .boolean(bool):
            var container = encoder.singleValueContainer()
            try container.encode(bool)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }

    public func read<T: Decodable>(as _: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public subscript(_ path: JSON.Path) -> JSON? {
        try? path.extract(from: self)
    }

    public subscript(_ path: String) -> JSON? {
        get throws {
            let path = try JSON.Path(string: path)
            return try? path.extract(from: self)
        }
    }

    public subscript<T: Codable>(_ path: String, as ast: T.Type) -> T {
        get throws {
            let path = try JSON.Path(string: path)
            return try path.extract(from: self).read(as: ast)
        }
    }

    // MARK: Internal

    struct Key: CodingKey {
        init(_ value: String) {
            self.value = value
        }

        init?(intValue: Int) {
            value = "\(intValue)"
        }

        init?(stringValue: String) {
            value = stringValue
        }

        let value: String
        public var stringValue: String {
            value
        }

        public var intValue: Int? {
            Int(value)
        }
    }
}

extension Optional {
    struct UnexpectedNil: Error {}
    func orThrow(_ err: any Error = UnexpectedNil()) throws -> Wrapped {
        switch self {
        case .none: throw err
        case let .some(wrapped): wrapped
        }
    }
}
