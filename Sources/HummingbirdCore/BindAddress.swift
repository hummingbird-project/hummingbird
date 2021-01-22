/// Address to bind to
public enum HBBindAddress {
    case hostname(_ host: String = "127.0.0.1", port: Int = 8080)
    case unixDomainSocket(path: String)

    /// if address is hostname and port return port
    public var port: Int? {
        guard case .hostname(_, let port) = self else { return nil }
        return port
    }

    /// if address is hostname and port return hostname
    public var host: String? {
        guard case .hostname(let host, _) = self else { return nil }
        return host
    }

    /// if address is unix domain socket return unix domain socket path
    public var unixDomainSocketPath: String? {
        guard case .unixDomainSocket(let path) = self else { return nil }
        return path
    }
}


