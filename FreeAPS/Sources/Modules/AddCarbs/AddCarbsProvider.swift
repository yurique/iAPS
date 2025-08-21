extension AddCarbs {
    final class Provider: BaseProvider, AddCarbsProvider {
        var suggestion: Suggestion? {
            storage.suggested.retrieveOpt()
        }
    }
}
