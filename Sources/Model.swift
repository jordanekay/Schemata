import Foundation

public protocol AnyModelValue {
    static var anyValue: AnyValue { get }
}

/// A storage type whose value can be extracted directly from a `Primitive`, enabling a
/// boxing-free decode path (`ModelValue.decode(_:)`).
public protocol PrimitiveDecodable {
    static func decoded(from primitive: Primitive) -> Self?
}

extension Int: PrimitiveDecodable {
    public static func decoded(from primitive: Primitive) -> Int? {
        guard case let .int(int) = primitive else { return nil }
        return int
    }
}

extension Double: PrimitiveDecodable {
    public static func decoded(from primitive: Primitive) -> Double? {
        guard case let .double(double) = primitive else { return nil }
        return double
    }
}

extension String: PrimitiveDecodable {
    public static func decoded(from primitive: Primitive) -> String? {
        guard case let .string(string) = primitive else { return nil }
        return string
    }
}

extension Date: PrimitiveDecodable {
    public static func decoded(from primitive: Primitive) -> Date? {
        guard case let .date(date) = primitive else { return nil }
        return date
    }
}

extension Bool: PrimitiveDecodable {
    public static func decoded(from primitive: Primitive) -> Bool? {
        guard case let .int(int) = primitive else { return nil }
        return int == 1
    }
}

extension None: PrimitiveDecodable {
    public static func decoded(from primitive: Primitive) -> None? {
        guard case .null = primitive else { return nil }
        return .none
    }
}

extension Optional: PrimitiveDecodable where Wrapped: PrimitiveDecodable {
    public static func decoded(from primitive: Primitive) -> Wrapped?? {
        if case .null = primitive { return .some(.none) }
        return Wrapped.decoded(from: primitive).map(Optional.some)
    }
}

public protocol ModelValue: AnyModelValue, Hashable {
    associatedtype Encoded: PrimitiveDecodable
    static var value: Value<Encoded, Self> { get }

    /// Decode straight from a `Primitive` — no `Any` boxing. A protocol requirement so `Optional`
    /// can override it to tolerate an undecodable wrapped value as `nil` (matching the erased path).
    static func decode(_ primitive: Primitive) -> Self?
}

public extension ModelValue {
    /// Decode straight from a `Primitive` into the concrete type — no `Any` boxing or dynamic cast.
    /// Works for any `Encoded` (including generic ids and optionals) via `PrimitiveDecodable`.
    static func decode(_ primitive: Primitive) -> Self? {
        return Encoded.decoded(from: primitive).flatMap { try? value.decode($0).get() }
    }
}

extension ModelValue where Encoded == Date {
    public static var anyValue: AnyValue {
        return AnyValue(value)
    }
}

extension ModelValue where Encoded == Double {
    public static var anyValue: AnyValue {
        return AnyValue(value)
    }
}

extension ModelValue where Encoded == Int {
    public static var anyValue: AnyValue {
        return AnyValue(value)
    }
}

extension ModelValue where Encoded == Bool {
    public static var anyValue: AnyValue {
        return AnyValue(value)
    }
}

extension ModelValue where Encoded == String {
    public static var anyValue: AnyValue {
        return AnyValue(value)
    }
}

extension ModelValue where Encoded == None {
    public static var anyValue: AnyValue {
        return AnyValue(value)
    }
}

public protocol AnyModel {
    static var anySchema: AnySchema { get }
}

public protocol Model: AnyModel, Sendable {
    associatedtype Path: RawRepresentable<String>

    static var schema: Schema<Self> { get }
    static var schemaName: String { get }
}

extension Model {
    public static var anySchema: AnySchema {
        return AnySchema(schema)
    }
}

public extension Collection where Element: Model {
    typealias Path = Element.Path

    static var schemaName: String { Element.schemaName }
}

public protocol ModelProjection: Hashable {
    associatedtype Model: Schemata.Model & Sendable
    static var projection: Projection<Model, Self> { get }
}

extension Date: ModelValue {
    public static let value = Value<Date, Date>()
}

extension Double: ModelValue {
    public static let value = Value<Double, Double>()
}

extension Int: ModelValue {
    public static let value = Value<Int, Int>()
}

extension Bool: ModelValue {
    public static let value = Value<Bool, Bool>()
}

extension Optional: AnyModelValue, ModelValue where Wrapped: ModelValue {
    public typealias Encoded = Wrapped.Encoded?

    public static var value: Value<Wrapped.Encoded?, Wrapped?> {
        return Value(
            decode: { encoded in
                switch encoded {
                case nil:
                    return .success(nil)
                case let .some(value):
                    return Wrapped.value.decode(value).map(Optional.some)
                }
            },
            encode: { $0.map(Wrapped.value.encode) }
        )
    }

    // A non-null but undecodable wrapped value collapses to `nil` (e.g. a URL stored as ""), matching
    // the erased path's optional tolerance. Always returns `.some`, so the pack decode never traps.
    public static func decode(_ primitive: Primitive) -> Wrapped?? {
        if case .null = primitive { return .some(.none) }
        return .some(Wrapped.decode(primitive))
    }

    public static var anyValue: AnyValue {
        return AnyValue(
            encoded: Wrapped.anyValue.encoded,
            encode: { value in
                // swiftlint:disab'le:next force_cast
                (value as? Wrapped).map(Wrapped.anyValue.encode) ?? .null
            },
            decoded: Wrapped?.self,
            decode: { primitive -> Result<Any, ValueError> in
                if primitive == .null {
                    return .success(Wrapped?.none as Any)
                }
                return Wrapped.anyValue
                    .decode(primitive)
                    // swiftlint:disable:next force_cast
                    .map { Optional($0 as! Wrapped) as Any }
            }
        )
    }
}

extension String: ModelValue {
    public static let value = Value<String, String>()
}

extension URL: ModelValue {
    public static let value = String.value.bimap(
        decode: { string in
            URL(string: string).map(Result.success)
                ?? .failure(.typeMismatch)
        },
        encode: { $0.absoluteString }
    )
}

extension UUID: ModelValue {
    public static let value = String.value.bimap(
        decode: { string in
            UUID(uuidString: string).map(Result.success)
                ?? .failure(.typeMismatch)
        },
        encode: { $0.uuidString }
    )
}
