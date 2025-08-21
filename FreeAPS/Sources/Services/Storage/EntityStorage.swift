import Foundation

struct EntityCodec<T> {
    let decode: (String) throws -> T
    let encode: (T) throws -> Data
}

enum EntityCodecs {
    static func json<T: Codable>() -> EntityCodec<T> {
        EntityCodec(
            decode: { string throws -> T in
                guard let data = string.data(using: .utf8) else {
                    throw StorageError.invalidValue(message: "failed to convert string to data")
                }
                return try JSONCoding.decoder.decode(T.self, from: data)
            },
            encode: { value throws -> Data in
                try JSONCoding.encoder.encode(value)
            }
        )
    }

    static let string = EntityCodec(
        decode: { string -> String in
            string
        },
        encode: { value -> Data in
            value.data(using: .utf8)!
        }
    )

    static let decimal = EntityCodec(
        decode: { string -> Decimal in
            guard let value = Decimal(string: string) else {
                throw StorageError.invalidValue(message: "invalid decimal: \(string)")
            }
            return value
        },
        encode: { value -> Data in
            (value as NSDecimalNumber).stringValue.data(using: .utf8)!
        }
    )

    static let date = EntityCodec(
        decode: { string throws -> Date in
            guard let date = ISO8601DateFormatter().date(from: string) else {
                throw StorageError.invalidValue(message: "invalid datetime: \(string)")
            }
            return date
        },
        encode: { value -> Data in
            ISO8601DateFormatter().string(from: value).data(using: .utf8)!
        }
    )
}

enum StorageError: Error {
    case valueMissing(message: String)
    case invalidValue(message: String)
}

protocol AnyEntityStorage {
    func retrieveAsString() throws -> String?
    func saveFromString(string: String) throws -> Void
    func fileName() -> String
}

class EntityStorage<T>: AnyEntityStorage {
    fileprivate let codec: EntityCodec<T>
    fileprivate let file: String
    private let readDefaults: Bool

    fileprivate let queue: DispatchQueue

    private var dataIsSynchronized = false
    private var currentData: String?

    init(file: String, codec: EntityCodec<T>, readDefaults: Bool = false) {
        self.codec = codec
        self.file = file
        self.readDefaults = readDefaults
        queue = DispatchQueue(label: "EntityStorage.processQueue.\(file.hashValue)", qos: .utility)
    }

    final func retrieveOpt() -> T? {
        queue.sync {
            doRetrieve()
        }
    }

    final func retrieveOrFail() throws -> T {
        try queue.sync {
            if let result = doRetrieve() {
                return result
            }
            throw StorageError.valueMissing(message: "\(file) is missing or failed to decode")
        }
    }

    final func save(_ value: T) {
        queue.sync {
            doSave(value)
        }
    }

    final func remove() {
        queue.sync {
            do {
                try Disk.remove(self.file, from: .documents)
            } catch {
                print("failed to remove \(self.file)")
            }
        }
    }

    func retrieveAsString() throws -> String? {
        guard let value = retrieveOpt() else { return nil }
        return String(data: try codec.encode(value), encoding: .utf8)
    }

    func saveFromString(string: String) throws {
        let value = try codec.decode(string)
        save(value)
    }

    func fileName() -> String {
        file
    }

    // read outside the queue
    fileprivate func readData() -> String? {
        if dataIsSynchronized {
            return currentData
        }
        let retrievedData: String?
        if let data = try? Disk.retrieve(file, from: .documents, as: Data.self) {
            retrievedData = String(data: data, encoding: .utf8)
        } else if readDefaults {
            let fallback = OpenAPS.defaults(for: file)
            if fallback != "" {
                retrievedData = fallback
            } else {
                retrievedData = nil
            }
        } else {
            retrievedData = nil
        }

        currentData = retrievedData
        dataIsSynchronized = true

        return retrievedData
    }

    // read outside the queue
    fileprivate func doRetrieve() -> T? {
        guard let data = readData() else { return nil }
        let result = try? codec.decode(data)
        return result
    }

    // save outside the queue
    fileprivate final func doSave(_ value: T) {
        do {
            let data = try codec.encode(value)
            try Disk.save(data, to: .documents, as: file)
            currentData = String(data: data, encoding: .utf8)
            dataIsSynchronized = true
        } catch {
            print("failed to save data to \(file): \(error.localizedDescription)")
        }
    }
}

class EntityStorageWithFallback<T>: EntityStorage<T> {
    let fallbackValue: () -> T

    init(file: String, codec: EntityCodec<T>, readDefaults: Bool = false, fallbackValue: @escaping @autoclosure () -> T) {
        self.fallbackValue = fallbackValue
        super.init(file: file, codec: codec, readDefaults: readDefaults)
    }

    func retrieve() -> T {
        retrieveOpt() ?? fallbackValue()
    }
}

class EntityStorageWithAppend<T: Codable>: EntityStorage<[T]> {
    private let singleItemCodec: EntityCodec<T>

    init(file: String, readDefaults: Bool = false) {
        singleItemCodec = EntityCodecs.json()
        super.init(file: file, codec: EntityCodecs.json(), readDefaults: readDefaults)
    }

    func append(_ newValue: T) -> [T] {
        queue.sync {
            var values = doRetrieve() ?? []
            values.append(newValue)
            doSave(values)
            return values
        }
    }

    func append(_ newValues: [T]) -> [T] {
        queue.sync {
            var values = doRetrieve() ?? []
            values.append(contentsOf: newValues)
            doSave(values)
            return values
        }
    }

    // TODO: the other overload not just appends, but overwrites existing entries if the key matches; this version doesn't
    func append<K: Equatable>(_ newValue: T, uniqBy keyPath: KeyPath<T, K>) -> [T] {
        queue.sync {
            var values = doRetrieve() ?? []
            guard values.first(where: { $0[keyPath: keyPath] == newValue[keyPath: keyPath] }) == nil else {
                // this element is present in the store already
                return values
            }
            values.append(newValue)
            doSave(values)
            return values
        }
    }

    func append<K: Equatable>(_ newValues: [T], uniqBy keyPath: KeyPath<T, K>) -> [T] {
        queue.sync {
            var values = doRetrieve() ?? []
            for newValue in newValues {
                if let index = values.firstIndex(where: { $0[keyPath: keyPath] == newValue[keyPath: keyPath] }) {
                    values[index] = newValue
                } else {
                    values.append(newValue)
                }
            }
            doSave(values)
            return values
        }
    }

    func retrieveOrEmpty() -> [T] {
        retrieveOpt() ?? []
    }

    // read outside the queue
    // if the file contains a single item not an array - parse it and wrap in array
    // not sure if this is still needed, but keepeing for compatibility
    override fileprivate func doRetrieve() -> [T]? {
        guard let data = readData() else { return nil }
        if let array = try? codec.decode(data) {
            return array
        }
        if let item = try? singleItemCodec.decode(data) {
            return [item]
        }
        return nil
    }
}
