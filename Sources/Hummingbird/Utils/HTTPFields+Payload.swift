import HTTPTypes

extension HTTPFields {
    init(contentType: String, contentLength: Int) {
        self = [
            .contentType: contentType,
            .contentLength: String(describing: contentLength)
        ]
    }
}
