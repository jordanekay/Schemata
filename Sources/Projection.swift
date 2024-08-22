import Foundation

/// A projection from some Model type to a Value type.
///
/// Given a dictionary of values used in the projection, this can be used to create a `Value`.
public struct Projection<Model: Schemata.Model & Sendable, Value>: @unchecked Sendable {
    /// The `KeyPath`s that are required to create a `Value`.
    public let keyPaths: Set<PartialKeyPath<Model>>

    fileprivate let make: ([PartialKeyPath<Model>: Any]) -> Value

	fileprivate init<each T>(
		keyPath: repeat KeyPath<Model, each T>,
		make: @escaping ([PartialKeyPath<Model>: Any]) -> Value
	) {
		var keyPaths: Set<PartialKeyPath<Model>> = []

		#if compiler(>=6.0)
		for keyPath in repeat each keyPath {
			keyPaths.insert(keyPath)
		}
		#else
		func insertKeyPath<U>(_ keyPath: KeyPath<Model, U>) {
			keyPaths.insert(keyPath)
		}

		repeat insertKeyPath(each keyPath)
		#endif

		self.keyPaths = keyPaths
		self.make = make
	}

    public func makeValue(_ values: [PartialKeyPath<Model>: Any]) -> Value {
        return make(values)
    }
}

// swiftlint:disable force_cast
extension Projection {
	public init<each T>(
		_ make: @Sendable @escaping (repeat each T) -> Value,
		_ keyPath: repeat KeyPath<Model, each T>
	) {
		self.init(keyPath: repeat each keyPath) { values in
			make(repeat values[each keyPath] as! each T)
		}
	}
}

// swiftlint:enable force_cast
