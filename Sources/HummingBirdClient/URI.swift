import HummingBird

extension URI {
    var requiresTLS: Bool {
        return self.scheme == .https || self.scheme == .https_unix
    }
}
