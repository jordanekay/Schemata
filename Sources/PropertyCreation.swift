import Foundation

precedencegroup SchemataPropertyCreationPrecedence {
    associativity: left
    higherThan: LogicalConjunctionPrecedence
    lowerThan: NilCoalescingPrecedence
}

infix operator -->: SchemataPropertyCreationPrecedence
infix operator -?>: SchemataPropertyCreationPrecedence
infix operator ->>: SchemataPropertyCreationPrecedence
infix operator <<-: SchemataPropertyCreationPrecedence

public func * <Model, Value: ModelValue>(
	lhs: KeyPath<Model, Value>,
    rhs: Model.Path
) -> Property<Model, Value> {
	return Property<Model, Value>(
		keyPath: lhs,
        path: rhs.rawValue,
		type: .value(Value.self, nullable: false)
	)
}

public func * <Model, Value: ModelValue>(
    lhs: KeyPath<Model, Value?>,
    rhs: Model.Path
) -> Property<Model, Value?> {
    return Property<Model, Value?>(
        keyPath: lhs,
        path: rhs.rawValue,
        type: .value(Value.self, nullable: true)
    )
}

public func * <Model, Value: ModelValue>(
    lhs: KeyPath<Model, [Value]>,
    rhs: Model.Path
) -> Property<Model, [Value]> {
    return Property<Model, [Value]>(
        keyPath: lhs,
        path: rhs.rawValue,
        type: .value(Value.self, nullable: false)
    )
}

public func --> <ModelA, ModelB: Schemata.Model>(
    lhs: KeyPath<ModelA, ModelB>,
    rhs: ModelA.Path
) -> Property<ModelA, ModelB> {
    return Property<ModelA, ModelB>(
        keyPath: lhs,
        path: rhs.rawValue,
        type: .toOne(ModelB.self, nullable: false)
    )
}

public func -?> <ModelA, ModelB: Schemata.Model>(
    lhs: KeyPath<ModelA, ModelB>,
    rhs: ModelA.Path
) -> Property<ModelA, ModelB> {
    return Property<ModelA, ModelB>(
        keyPath: lhs,
        path: rhs.rawValue,
        type: .toOne(ModelB.self, nullable: true)
    )
}

public func <<- <Model, Children: Sequence & Schemata.Model>(
    lhs: KeyPath<Model, Children>,
    rhs: KeyPath<Children.Element, Model>
) -> Property<Model, Children> where Children.Element: Schemata.Model {
    return Property<Model, Children>(
        keyPath: lhs,
        path: Children.Element.anySchema.properties(for: rhs).last!.path,
        type: .toMany(Children.self)
    )
}
