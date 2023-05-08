public struct DebugDependency: Sendable {
  public var dependency: @Sendable (PartialKeyPath<DependencyValues>) -> Void

  public init(dependency: @escaping @Sendable (PartialKeyPath<DependencyValues>) -> Void) {
    self.dependency = dependency
  }
}

extension DependencyValues {
  public var debug: DebugDependency {
    get { self[DebugDependency.self] }
    set { self[DebugDependency.self] = newValue }
  }
}

extension DebugDependency: DependencyKey {
  public static var liveValue: DebugDependency {
    DebugDependency { _ in () }
  }
  public static var testValue: DebugDependency {
    liveValue
  }
  public static var previewValue: DebugDependency {
    liveValue
  }

  public static func print() -> DebugDependency {
    DebugDependency {
      keyPath in
      Swift.print("Did access: \(String(describing: keyPath))")
    }
  }
}
