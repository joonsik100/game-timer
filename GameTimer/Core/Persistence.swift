import Foundation

/// 상태 전체를 JSON 한 파일에 담는다. 개인용 앱이라 DB가 필요 없고, 파일이면 눈으로 열어볼 수도 있다.
struct Persistence {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// 앱 샌드박스의 Application Support/GameTimer/store.json.
    static var `default`: Persistence {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = base
            .appendingPathComponent("GameTimer", isDirectory: true)
            .appendingPathComponent("store.json")
        return Persistence(fileURL: url)
    }

    // MARK: - Coding

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - IO

    /// 파일이 없으면 nil(첫 실행). 파일은 있는데 읽거나 해석하지 못하면 옆으로 치워 두고 nil을 반환한다.
    ///
    /// '없음'과 '못 읽음'을 구분하는 게 중요하다. 구분하지 않으면 일시적인 읽기 실패에도 기본값으로 뜨고,
    /// 그 상태에서 버튼을 한 번 누르는 순간 멀쩡하던 원본이 기본값으로 덮여 복구 수단이 사라진다.
    func load() -> PersistedState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            // 읽지는 못해도 이름은 바꿀 수 있다. 원본을 남겨 두면 나중에 손으로 복구할 수 있다.
            quarantineFile()
            return nil
        }

        do {
            return try Self.makeDecoder().decode(PersistedState.self, from: data)
        } catch {
            quarantineFile()
            return nil
        }
    }

    /// 임시 파일에 쓰고 이름을 바꾸는 원자적 쓰기라, 저장 도중 앱이 죽어도 반쪽짜리 파일이 남지 않는다.
    func save(_ state: PersistedState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.makeEncoder().encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    /// 못 읽은 파일을 옆으로 치워 원본을 남긴다.
    ///
    /// 이름이 겹치면 이동이 실패하고 원본이 제자리에 남아 다음 저장에 덮여 버리므로,
    /// 비어 있는 이름을 찾을 때까지 번호를 올린다(같은 초에 두 번 일어날 수 있다).
    private func quarantineFile() {
        let directory = fileURL.deletingLastPathComponent()
        let stamp = Int(Date().timeIntervalSince1970)
        var backup = directory.appendingPathComponent("store.corrupt-\(stamp).json")
        var suffix = 2
        while FileManager.default.fileExists(atPath: backup.path) {
            backup = directory.appendingPathComponent("store.corrupt-\(stamp)-\(suffix).json")
            suffix += 1
        }
        try? FileManager.default.moveItem(at: fileURL, to: backup)
    }
}
