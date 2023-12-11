import HummingbirdRouter

extension HBRouter<HBBasicRequestContext> {
    public convenience init() {
        self.init(context: Context.self)
    }
}