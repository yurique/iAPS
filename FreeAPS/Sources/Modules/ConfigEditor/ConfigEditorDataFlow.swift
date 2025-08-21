enum ConfigEditor {
    enum Config {}
}

protocol ConfigEditorProvider: Provider {
    func save(_ value: String, as file: ConfigEditorFile)
    func load(file: ConfigEditorFile) -> String
}
