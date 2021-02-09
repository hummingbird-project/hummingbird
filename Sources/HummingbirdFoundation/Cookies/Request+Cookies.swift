import Hummingbird

extension HBRequest {
    /// access cookies from request. When accessing this for the first time the HBCookies struct will be created
    public var cookies: HBCookies {
        self.extensions.getOrCreate(\.cookies, HBCookies(from: self))
    }
}
