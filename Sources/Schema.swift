import Foundation

// swiftlint:disable large_tuple

private extension DecodeError {
    init(_ errors: DecodeError?...) {
        self = errors
            .compactMap { $0 }
            .reduce(DecodeError([:]), +)
    }
}

extension PartialKeyPath: @unchecked Swift.Sendable {}

public struct Schema<Model: Schemata.Model>: Hashable, Sendable {
    public let name: String
    public let properties: [PartialKeyPath<Model>: PartialProperty<Model>]

    fileprivate init<each T>(
        name: String,
        _ property: repeat Property<Model, each T>
    ) {
        self.name = name

        var properties: [PartialKeyPath<Model>: PartialProperty<Model>] = [:]

        #if compiler(>=6.0)
            for property in repeat each property {
                properties[property.keyPath] = .init(
                    keyPath: property.keyPath,
                    path: property.path,
                    type: property.type
                )
            }
        #else
            func assignProperty<U>(property: Property<Model, U>) {
                properties[property.keyPath] = .init(
                    keyPath: property.keyPath,
                    path: property.path,
                    type: property.type
                )
            }

            repeat assignProperty(property: each property)
        #endif

        self.properties = properties
    }

    public func properties(for keyPath: AnyKeyPath) -> [AnyProperty] {
        return AnySchema(self).properties(for: keyPath)
    }

    public func properties<Value>(for keyPath: KeyPath<Model, Value>) -> [AnyProperty] {
        return properties(for: keyPath as AnyKeyPath)
    }
}

public extension Schema {
    subscript<Value>(_ keyPath: KeyPath<Model, Value>) -> Property<Model, Value> {
        let partial = self[keyPath as PartialKeyPath<Model>]
        return Property<Model, Value>(
            keyPath: partial.keyPath as! KeyPath<Model, Value>, // swiftlint:disable:this force_cast
            path: partial.path,
            type: partial.type
        )
    }

    subscript<Value>(_ keyPath: KeyPath<Model, Value>) -> AnyProperty {
        return AnyProperty(self[keyPath as PartialKeyPath<Model>])
    }

    subscript(_ keyPath: PartialKeyPath<Model>) -> PartialProperty<Model> {
        return properties[keyPath]!
    }
}

public extension Schema {
    init<each T>(
        _: @escaping (repeat each T) -> Model,
        _ property: repeat Property<Model, each T>
    ) {
        self.init(
            name: Model.schemaName,
            repeat each property
        )
    }
}

extension Schema: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "\(Model.self) {\n"
            + properties.values.map { "\t" + $0.debugDescription }.sorted().joined(separator: "\n")
            + "\n}"
    }
}

public struct AnySchema: Hashable {
    public var name: String
    public var properties: [AnyKeyPath: AnyProperty]

    private static var cache: [AnyKeyPath: [AnyProperty]] = [:]

    public init<Model>(_ schema: Schema<Model>) {
        let properties = schema.properties.map { ($0.key as AnyKeyPath, AnyProperty($0.value)) }
        name = schema.name
        self.properties = Dictionary(uniqueKeysWithValues: properties)
    }

    public func properties(for keyPath: AnyKeyPath) -> [AnyProperty] {
        if let properties = Self.cache[keyPath] {
            return properties
        }

        var queue: [(keyPath: AnyKeyPath, properties: [AnyProperty])]
            = properties.values.map { ($0.keyPath, [$0]) }

        while let next = queue.first {
            queue.removeFirst()

            if next.keyPath == keyPath {
                Self.cache[keyPath] = next.properties
                return next.properties
            }

            switch next.properties.last?.type {
            case let .toOne(type, _), let .toMany(type):
                for property in type.anySchema.properties.values {
                    queue.append(
                        (
                            keyPath: next.keyPath.appending(path: property.keyPath)!,
                            properties: next.properties + [property]
                        )
                    )
                }
            default:
                break
            }
        }

        return []
    }
}
