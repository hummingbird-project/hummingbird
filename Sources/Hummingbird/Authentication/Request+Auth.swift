extension HBRequest {
    public struct Auth {
        /// Login with type
        /// - Parameter auth: authentication details
        public func login<Auth>(_ auth: Auth) {
            var logins = self.loginCache ?? [:]
            logins[ObjectIdentifier(Auth.self)] = auth
            request.extensions.set(\.auth.loginCache, value: logins)
        }
        
        /// Logout type
        /// - Parameter auth: authentication type
        public func logout<Auth>(_ auth: Auth.Type) {
            if var logins = self.loginCache {
                logins[ObjectIdentifier(Auth.self)] = nil
                request.extensions.set(\.auth.loginCache, value: logins)
            }
        }
        
        /// Return authenticated type
        /// - Parameter auth: Type required
        public func get<Auth>(_ auth: Auth.Type) -> Auth? {
            return loginCache?[ObjectIdentifier(Auth.self)] as? Auth
        }
        
        /// Return if request is authenticated with type
        /// - Parameter auth: Authentication type
        public func has<Auth>(_ auth: Auth.Type) -> Bool {
            return loginCache?[ObjectIdentifier(Auth.self)] != nil
        }
        
        var loginCache: [ObjectIdentifier: Any]? { request.extensions.get(\.auth.loginCache) }
            
        let request: HBRequest
    }
    
    /// Authentication object
    public var auth: Auth { return .init(request: self) }
}
