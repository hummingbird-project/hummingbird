import Hummingbird

public struct HBCookies {
    init(from request: HBRequest) {
        self.array = request.headers["cookie"].compactMap { HBCookie(from: $0) }
    }

    let array: [HBCookie]
}

extension HBCookies: Collection {
    public typealias Element = HBCookie

    public func index(after i: Int) -> Int {
        return self.array.index(after: i)
    }

    public subscript(_ index: Int) -> HBCookies.Element {
        return self.array[index]
    }

    public var startIndex: Int { self.array.startIndex }
    public var endIndex: Int { self.array.endIndex }
}
