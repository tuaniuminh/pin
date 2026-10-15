import Foundation
import SwiftUI

public struct MWLocalizedString: ExpressibleByStringInterpolation, Hashable, Sendable, CustomStringConvertible {
    public let key: String

    public init(stringLiteral value: String) {
        self.key = value
    }

    public init(_ key: String) {
        self.key = key
    }

    public var description: String {
        NSLocalizedString(key, comment: "")
    }

    public var text: Text {
        Text(LocalizedStringKey(key))
    }
}

public extension Text {
    init(_ res: MWLocalizedString) {
        self.init(LocalizedStringKey(res.key))
    }
}
