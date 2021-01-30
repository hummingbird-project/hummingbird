import Hummingbird

extension HBRequest {
    /// attach cookies to request. When accessing this for the first time the HBCookies struct will be created
    var cookies: HBCookies {
        get { self.extensions.getOrCreate(\.cookies, HBCookies(from: self)) }
        set { self.extensions.set(\.cookies, value: newValue) }
    }
}
