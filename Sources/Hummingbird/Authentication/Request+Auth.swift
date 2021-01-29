extension HBRequest {
    public struct Auth {
        /// Login with type
        /// - Parameter auth: authentication details
        public func login<Auth>(_ auth: Auth) {
            var logins = self.loginCache ?? [:]
            logins[ObjectIdentifier(Auth.self)] = auth
            self.request.extensions.set(\.auth.loginCache, value: logins)
        }

        /// Logout type
        /// - Parameter auth: authentication type
        public func logout<Auth>(_: Auth.Type) {
            if var logins = self.loginCache {
                logins[ObjectIdentifier(Auth.self)] = nil
                self.request.extensions.set(\.auth.loginCache, value: logins)
            }
        }

        /// Return authenticated type
        /// - Parameter auth: Type required
        public func get<Auth>(_: Auth.Type) -> Auth? {
            return self.loginCache?[ObjectIdentifier(Auth.self)] as? Auth
        }

        /// Return if request is authenticated with type
        /// - Parameter auth: Authentication type
        public func has<Auth>(_: Auth.Type) -> Bool {
            return self.loginCache?[ObjectIdentifier(Auth.self)] != nil
        }

        var loginCache: [ObjectIdentifier: Any]? { self.request.extensions.get(\.auth.loginCache) }

        let request: HBRequest
    }

    /// Authentication object
    public var auth: Auth { return .init(request: self) }
}
