import Hummingbird

extension HBResponse {
    struct Cookies {
        func set(cookie: HBCookie) {
            response.headers.add(name: "Set-Cookie", value: cookie.description)
        }
        
        let response: HBResponse
    }
    
    var cookies: Cookies { return .init(response: self)}
}
