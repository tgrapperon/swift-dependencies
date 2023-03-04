import Foundation

#if DEBUG
  struct DebugDependency {
    enum Mode: Sendable {
      case verbose
      case compact
    }
    var path: [String] = []
    var iterationPerLevel: [Int: Int] = [:]
    let maxLineLength: Int = 80
//    let debugMode = LockIsolated(Mode?.none)
     let debugMode = LockIsolated(Mode?.some(.verbose))

    mutating func overrideDependencies(
      function: StaticString,
      fileID: StaticString,
      line: UInt
    ) -> String {
      guard let mode = debugMode.value else { return "" }
      guard !DependencyValues.isEscapedDependencies else { return "" }
      var hash = "\(fileID):\(line):\(function)".stableHashString
      if let previous = self.path.last(where: { $0.starts(with: hash) }) {
        if let index = previous.components(separatedBy: ":").last.flatMap(Int.init) {
          hash += ":\(index+1)"
        } else {
          hash += ":1"
        }
      }

      path.append(hash)
      var message = [String]()

      if mode == .verbose {
        message.append(
          "┌─ withDependencies: \(hash) " + String(repeating: "─", count: maxLineLength))
        message.append("│ Function: \(function)")
        message.append("│ Location: \(fileID):\(line)")
        message.append("│ Path: \(path.joined(separator: "/"))")
        message.append("├────────┄")
        message.append("┆ ")
      } else {
        message.append(
          "┌─ withDependencies: \(path.joined(separator: "/")) "
            + String(repeating: "─", count: maxLineLength))
      }

      message =
        message
        .indent(level: self.path.count - 1)
        .map { String($0.prefix(maxLineLength)).ellipsized }
      print(message.joined(separator: "\n"))

      return hash
    }

    func finishOverridingDependencies(hash: String) {
      guard let mode = debugMode.value else { return }
      guard !DependencyValues.isEscapedDependencies else { return }

      var message = [String]()
      if mode == .verbose {
        message.append("└─ End of: \(hash) " + String(repeating: "─", count: maxLineLength))
      } else {
        message.append(
          "└─ End of: \(path.joined(separator: "/")) "
            + String(repeating: "─", count: maxLineLength))
      }
      message =
        message
        .indent(level: self.path.count - 1)
        .map { String($0.prefix(maxLineLength)).ellipsized }
      print(message.joined(separator: "\n"))
    }

    func escapeDependencies(
      function: StaticString,
      fileID: StaticString,
      line: UInt
    ) -> String? {
      guard let mode = debugMode.value else { return nil }

      if let hash = self.path.last {
        let baseMessage: String
        if mode == .verbose {
          baseMessage = "┿━< Escaping \(hash) at \(fileID):\(line)"
        } else {
          baseMessage = "┿━< Escaping \(self.path.joined(separator: "/"))"
        }
        let message = [baseMessage]
          .indent(level: self.path.count - 1)
          .map { String($0.prefix(maxLineLength)).ellipsized }
        print(message.joined(separator: "\n"))
        return hash
      } else {
        // Is this pathological?
        let baseMessage: String
        if mode == .verbose {
          baseMessage = "┿━< Escaping default dependencies at \(fileID):\(line)"
        } else {
          baseMessage = "┿━< Escaping default dependencies"
        }
        let message = [baseMessage]
          .map { String($0.prefix(maxLineLength)).ellipsized }
        print(message.joined(separator: "\n"))
        return nil
      }
    }

    func yieldEscapedDependencies(hash: String?) {
      guard let mode = debugMode.value else { return }

      if let hash = hash {
        var message = [String]()
        if mode == .verbose {
          message.append(
            "┯━> Yielding escaped dependencies: \(hash) "
              + String(repeating: "━", count: maxLineLength))
          message.append("│ Path: \(path.joined(separator: "/"))")
          message.append("├────────┄")
          message.append("┆ ")
        } else {
          message.append(
            "┯━> Yielding escaped dependencies: \(path.joined(separator: "/")) "
              + String(repeating: "━", count: maxLineLength))
        }
        message =
          message
          .indent(level: self.path.count - 1)
          .map { String($0.prefix(maxLineLength)).ellipsized }
        print(message.joined(separator: "\n"))
      } else {
        // Is this pathological?
        let message = [
          "┯━> Yielding default dependencies" + String(repeating: "━", count: maxLineLength)
        ]
        .indent(level: self.path.count - 1)
        .map { String($0.prefix(maxLineLength)).ellipsized }
        print(message.joined(separator: "\n"))
      }
    }

    func finishYieldingDependencies(hash: String?) {
      guard let mode = debugMode.value else { return }

      if let hash = hash {
        var message = [String]()
        if mode == .verbose {
          message.append(
            "└─ End of escaped: \(hash) " + String(repeating: "─", count: maxLineLength))
        } else {
          message.append(
            "└─ End of escaped: \(path.joined(separator: "/")) "
              + String(repeating: "─", count: maxLineLength))
        }
        message =
          message
          .indent(level: self.path.count - 1)
          .map { String($0.prefix(maxLineLength)).ellipsized }
        print(message.joined(separator: "\n"))
      } else {
        // Is this pathological?
        let message = [
          "└─ End of escaped default dependencies " + String(repeating: "─", count: maxLineLength)
        ]
        .indent(level: self.path.count - 1)
        .map { String($0.prefix(maxLineLength)).ellipsized }
        print(message.joined(separator: "\n"))
      }
    }
  }

  extension DebugDependency: DependencyKey {
    static var liveValue: DebugDependency { .init() }
    static var testValue: DebugDependency { .init() }
  }
#endif

extension DependencyValues {
  #if DEBUG
    public static func printDependenciesPath() {
      if _current.debug.path.isEmpty {
        print("Dependencies path: / (Default Dependencies)")
      } else {
        print("Dependencies path: \(_current.debug.path.joined(separator: "/"))")
      }
    }

    public static func enableDebug(verbose: Bool = true) {
      _current.debug.debugMode.withValue {
        $0 = verbose ? .verbose : .compact
      }
    }

    var debug: DebugDependency {
      get { self[DebugDependency.self] }
      set { self[DebugDependency.self] = newValue }
    }
  #endif
}

#if DEBUG
  extension Array where Element == String {
    func indent(level: Int) -> Self {
      let indentString = String(repeating: "│ ", count: level)
      return self.map {
        indentString + $0
      }
    }
  }

  extension String {
    var ellipsized: String {
      if self.last == "─" {
        return self[...self.index(before: self.endIndex)] + "┄"
      } else if self.last == "━" {
        return self[...self.index(before: self.endIndex)] + "┅"
      }
      return self
    }
  }

  /*
 This source file is part of the Swift.org open source project
 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception
 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
  extension String {

    /// Returns an FNV1 hashed value of the string.
    private func fnv1() -> UInt32 {

      // Magic number for FNV hashing.
      let prime: UInt32 = 16_777_619

      // Start with the FNV-1 init value and keep hashing into it;
      // the hash value will overflow.
      return utf8.reduce(2_166_136_261) { (hash, byte) -> UInt32 in
        var hval = hash &* prime
        hval ^= UInt32(byte)
        return hval
      }
    }

    /// FNV-1 hash string, folded to fit 24 bits, and then base36 encoded;
    /// - note: The FNV-1 algorithm is public domain.
    var stableHashString: String {
      let fnv = fnv1()
      // Fold to 24 bits and encode in base 36.
      return String((fnv >> 24) ^ (fnv & 0xffffff), radix: 36, uppercase: false)
    }
  }
#endif
