import NIOHTTP1

extension HBRequest {
    /// Patches Response via `HBResponse.apply(patch:)`
    public struct ResponsePatch {
        /// patch status of reponse
        public var status: HTTPResponseStatus?
        /// headers to add to response
        public var headers: HTTPHeaders

        init() {
            self.status = nil
            self.headers = [:]
        }
    }

    /// Allows you to edit the status and headers of the response
    var response: ResponsePatch {
        get { self.extensions.getOrCreate(\.response, ResponsePatch()) }
        set { self.extensions.set(\.response, value: newValue) }
    }
}

extension HBResponse {
    func apply(patch: HBRequest.ResponsePatch?) -> Self {
        guard let patch = patch else { return self }
        if let status = patch.status {
            self.status = status
        }
        self.headers.add(contentsOf: patch.headers)
        return self
    }
}
