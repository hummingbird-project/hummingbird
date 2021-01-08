import NIOHTTP1

struct HTTPError: Error {
    let error: HTTPResponseStatus
}
