import Hummingbird
import Logging

var logger = Logger(label: "HB")
logger.logLevel = .debug

let router = HBRouter(context: HBBasicRequestContext.self)
router.middlewares.add(HBLogRequestsMiddleware(.info))
router.get { request, context -> HTTPResponse.Status in
    .ok
}

let app = HBApplication(router: router, logger: logger)

try await app.runService()
