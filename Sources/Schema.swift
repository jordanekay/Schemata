import Foundation

// swiftlint:disable large_tuple

private extension DecodeError {
    init(_ errors: DecodeError?...) {
        self = errors
            .compactMap { $0 }
            .reduce(DecodeError([:]), +)
    }
}

public struct Schema<Model: Schemata.Model>: Hashable, Sendable {
    public let name: String
    public let properties: [PartialKeyPath<Model>: PartialProperty<Model>]

	fileprivate init<each T>(
		name: String = String(describing: Model.self),
		_ property: repeat Property<Model, each T>
	) {
		self.name = name

		var properties: [PartialKeyPath<Model>: PartialProperty<Model>] = [:]
		for property in repeat each property {
			properties[property.keyPath] = .init(
				keyPath: property.keyPath,
				path: property.path,
				type: property.type
			)
		}

		self.properties = properties
	}

    public func properties(for keyPath: AnyKeyPath) -> [AnyProperty] {
        return AnySchema(self).properties(for: keyPath)
    }

    public func properties<Value>(for keyPath: KeyPath<Model, Value>) -> [AnyProperty] {
        return properties(for: keyPath as AnyKeyPath)
    }
}

extension Schema {
    public subscript<Value>(_ keyPath: KeyPath<Model, Value>) -> Property<Model, Value> {
        let partial = self[keyPath as PartialKeyPath<Model>]
        return Property<Model, Value>(
            keyPath: partial.keyPath as! KeyPath<Model, Value>, // swiftlint:disable:this force_cast
            path: partial.path,
            type: partial.type
        )
    }

    public subscript<Value>(_ keyPath: KeyPath<Model, Value>) -> AnyProperty {
        return AnyProperty(self[keyPath as PartialKeyPath<Model>])
    }

    public subscript(_ keyPath: PartialKeyPath<Model>) -> PartialProperty<Model> {
        return properties[keyPath]!
    }
}

extension Schema {
	public init<each T>(
		_: @escaping  (repeat each T) -> Model,
		_ property: repeat Property<Model, each T>
	) {
		self.init(repeat each property)
	}

	public init<each T>(
		_ initializer: Initializer<Model, (repeat each T)>,
		_ property: repeat Property<Model, each T>
	) {
		self.init(
			name: initializer.name,
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

    public init<Model>(_ schema: Schema<Model>) {
        let properties = schema.properties.map { ($0.key as AnyKeyPath, AnyProperty($0.value)) }
        name = schema.name
        self.properties = Dictionary(uniqueKeysWithValues: properties)
    }

    public func properties(for keyPath: AnyKeyPath) -> [AnyProperty] {
        var queue: [(keyPath: AnyKeyPath, properties: [AnyProperty])]
            = properties.values.map { ($0.keyPath, [$0]) }

        while let next = queue.first {
            queue.removeFirst()

            if next.keyPath == keyPath {
                return next.properties
            }

            switch next.properties.last?.type {
            case .toOne(let type, _), .toMany(let type):
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
