import Foundation

/// A projection from some Model type to a Value type.
///
/// Given a dictionary of values used in the projection, this can be used to create a `Value`.
public struct Projection<Model: Schemata.Model & Sendable, Value>: @unchecked Sendable {
	/// The `KeyPath`s that are required to create a `Value`.
	public let keyPaths: Set<PartialKeyPath<Model>>

	/// The `KeyPath`s in the order they appear in the projection's parameter pack.
	public let orderedKeyPaths: [PartialKeyPath<Model>]

	fileprivate let make: ([PartialKeyPath<Model>: Any]) -> Value
	fileprivate let makeOrdered: ([Any?]) -> Value
	fileprivate let makeDecoding: (@escaping (Int) -> Any?) -> Value

	fileprivate init<each T>(
		keyPath: repeat KeyPath<Model, each T>,
		make: @escaping ([PartialKeyPath<Model>: Any]) -> Value,
		makeOrdered: @escaping ([Any?]) -> Value,
		makeDecoding: @escaping (@escaping (Int) -> Any?) -> Value
	) {
		var keyPaths: Set<PartialKeyPath<Model>> = []
		var ordered: [PartialKeyPath<Model>] = []

		#if compiler(>=6.0)
		for keyPath in repeat each keyPath {
			keyPaths.insert(keyPath)
			ordered.append(keyPath)
		}
		#else
		func insertKeyPath<U>(_ keyPath: KeyPath<Model, U>) {
			keyPaths.insert(keyPath)
			ordered.append(keyPath)
		}

		repeat insertKeyPath(each keyPath)
		#endif

		self.keyPaths = keyPaths
		self.orderedKeyPaths = ordered
		self.make = make
		self.makeOrdered = makeOrdered
		self.makeDecoding = makeDecoding
	}

	public func makeValue(_ values: [PartialKeyPath<Model>: Any]) -> Value {
		return make(values)
	}

	/// Create a `Value` from decoded values in `orderedKeyPaths` order.
	public func makeValue(ordered values: [Any?]) -> Value {
		return makeOrdered(values)
	}

	/// Create a `Value` by decoding each parameter on demand — avoids the `[Any?]` intermediate.
	public func makeValue(decoding decode: @escaping (Int) -> Any?) -> Value {
		return makeDecoding(decode)
	}
}

// swiftlint:disable force_cast
extension Projection {
	public init<each T>(
		_ make: @Sendable @escaping (repeat each T) -> Value,
		_ keyPath: repeat KeyPath<Model, each T>
	) {
		self.init(
			keyPath: repeat each keyPath,
			make: { values in
				make(repeat values[each keyPath] as! each T)
			},
			makeOrdered: { values in
				var index = 0
				func next<U>(_: U.Type) -> U {
					defer { index += 1 }
					return values[index] as! U
				}
				return make(repeat next((each T).self))
			},
			makeDecoding: { decode in
				var index = 0
				func next<U>(_: U.Type) -> U {
					defer { index += 1 }
					return decode(index) as! U
				}
				return make(repeat next((each T).self))
			}
		)
	}
}

// swiftlint:enable force_cast
