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
	// Present only when every projected parameter is a `ModelValue`; decodes each column straight
	// into its concrete type from a `Primitive`, with no `Any` boxing or dynamic cast.
	fileprivate let makeTyped: (((Int) -> Primitive) -> Value)?

	fileprivate init<each T>(
		keyPath: repeat KeyPath<Model, each T>,
		make: @escaping ([PartialKeyPath<Model>: Any]) -> Value,
		makeOrdered: @escaping ([Any?]) -> Value,
		makeDecoding: @escaping (@escaping (Int) -> Any?) -> Value,
		makeTyped: (((Int) -> Primitive) -> Value)? = nil
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
		self.makeTyped = makeTyped
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

	/// Create a `Value` by decoding each parameter straight from a `Primitive` into its concrete type,
	/// bypassing `Any` boxing. Returns `nil` when the projection has a non-`ModelValue` parameter.
	public func makeValue(typed primitiveAt: @escaping (Int) -> Primitive) -> Value? {
		return makeTyped.map { $0(primitiveAt) }
	}

	/// Whether the boxing-free typed decode path is available (all parameters are `ModelValue`).
	public var supportsTypedDecoding: Bool {
		return makeTyped != nil
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

	/// Typed overload: available when every parameter is a `ModelValue`, enabling the boxing-free
	/// decode path. Swift selects this over the unconstrained init whenever the constraint is met.
	public init<each T: ModelValue>(
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
			},
			makeTyped: { primitiveAt in
				var index = 0
				func next<U: ModelValue>(_: U.Type) -> U {
					defer { index += 1 }
					return U.decode(primitiveAt(index))!
				}
				return make(repeat next((each T).self))
			}
		)
	}
}

// swiftlint:enable force_cast
