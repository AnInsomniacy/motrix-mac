import Foundation
import Testing
@testable import Motrix

@Suite("ByteFormatter")
@MainActor
struct ByteFormatterTests {

    @Test func zeroBytes() {
        #expect(ByteFormatter.format(0) == "0 KB")
    }

    @Test func rawBytes() {
        #expect(ByteFormatter.format(512) == "512 B")
    }

    @Test func kilobytes() {
        #expect(ByteFormatter.format(1024) == "1.0 KB")
        #expect(ByteFormatter.format(1536) == "1.5 KB")
    }

    @Test func megabytes() {
        #expect(ByteFormatter.format(1_048_576) == "1.0 MB")
        #expect(ByteFormatter.format(5_242_880) == "5.0 MB")
    }

    @Test func gigabytes() {
        #expect(ByteFormatter.format(1_073_741_824) == "1.0 GB")
    }

    @Test func terabytes() {
        #expect(ByteFormatter.format(1_099_511_627_776) == "1.0 TB")
    }

    @Test func speedSuffix() {
        #expect(ByteFormatter.speed(0) == "0 KB/s")
        #expect(ByteFormatter.speed(1_048_576) == "1.0 MB/s")
    }

    @Test func customPrecision() {
        #expect(ByteFormatter.format(1_500_000, precision: 2) == "1.43 MB")
    }
}

@Suite("TimeRemainingFormatter")
@MainActor
struct TimeRemainingFormatterTests {

    @Test func zeroSpeed() {
        #expect(TimeRemainingFormatter.format(totalLength: 1000, completedLength: 0, downloadSpeed: 0) == "")
    }

    @Test func zeroOrNegativeSeconds() {
        #expect(TimeRemainingFormatter.format(seconds: 0) == "")
        #expect(TimeRemainingFormatter.format(seconds: -5) == "")
    }

    @Test func secondsOnly() {
        #expect(TimeRemainingFormatter.format(seconds: 45) == "45s")
    }

    @Test func minutesAndSeconds() {
        #expect(TimeRemainingFormatter.format(seconds: 125) == "2m 5s")
    }

    @Test func hoursMinutesSeconds() {
        #expect(TimeRemainingFormatter.format(seconds: 3661) == "1h 1m 1s")
    }

    @Test func exactHour() {
        #expect(TimeRemainingFormatter.format(seconds: 3600) == "1h 0s")
    }

    @Test func moreThanOneDay() {
        #expect(TimeRemainingFormatter.format(seconds: 100_000) == "> 1 day")
    }

    @Test func remainingCalculation() {
        let result = TimeRemainingFormatter.format(totalLength: 2000, completedLength: 1000, downloadSpeed: 100)
        #expect(result == "10s")
    }
}

@Suite("ThunderLink")
@MainActor
struct ThunderLinkTests {

    @Test func nonThunderLinkPassthrough() {
        #expect(ThunderLink.decode("https://example.com") == "https://example.com")
    }

    @Test func validThunderLink() {
        let inner = "AAhttp://example.com/file.zipZZ"
        let encoded = Data(inner.utf8).base64EncodedString()
        let thunderURL = "thunder://\(encoded)"
        #expect(ThunderLink.decode(thunderURL) == "http://example.com/file.zip")
    }

    @Test func caseInsensitivePrefix() {
        let inner = "AAhttp://example.com/test.exeZZ"
        let encoded = Data(inner.utf8).base64EncodedString()
        let thunderURL = "THUNDER://\(encoded)"
        #expect(ThunderLink.decode(thunderURL) == "http://example.com/test.exe")
    }

    @Test func invalidBase64() {
        #expect(ThunderLink.decode("thunder://!!!invalid!!!") == "thunder://!!!invalid!!!")
    }

    @Test func tooShortDecoded() {
        let inner = "AB"
        let encoded = Data(inner.utf8).base64EncodedString()
        #expect(ThunderLink.decode("thunder://\(encoded)") == "thunder://\(encoded)")
    }
}

@Suite("MagnetLink")
@MainActor
struct MagnetLinkTests {

    @Test func basicBuild() {
        let result = MagnetLink.build(infoHash: "abc123")
        #expect(result == "magnet:?xt=urn:btih:abc123")
    }

    @Test func buildWithName() {
        let result = MagnetLink.build(infoHash: "abc123", name: "test file")
        #expect(result.hasPrefix("magnet:?xt=urn:btih:abc123&dn="))
        #expect(result.contains("test"))
    }

    @Test func buildWithTrackers() {
        let result = MagnetLink.build(infoHash: "abc123", trackers: ["http://tracker1.com", "http://tracker2.com"])
        #expect(result.contains("&tr="))
        let trCount = result.components(separatedBy: "&tr=").count - 1
        #expect(trCount == 2)
    }

    @Test func isMagnetPositive() {
        #expect(MagnetLink.isMagnet("magnet:?xt=urn:btih:abc"))
        #expect(MagnetLink.isMagnet("MAGNET:?xt=urn:btih:abc"))
    }

    @Test func isMagnetNegative() {
        #expect(!MagnetLink.isMagnet("https://example.com"))
        #expect(!MagnetLink.isMagnet(""))
    }
}

@Suite("BencodeDecoder")
@MainActor
struct BencodeDecoderTests {

    @Test func decodeInteger() {
        let data = Data("i42e".utf8)
        let result = BencodeDecoder(data: data).decode()
        guard case .integer(let v) = result else {
            Issue.record("Expected integer")
            return
        }
        #expect(v == 42)
    }

    @Test func decodeNegativeInteger() {
        let data = Data("i-7e".utf8)
        let result = BencodeDecoder(data: data).decode()
        guard case .integer(let v) = result else {
            Issue.record("Expected integer")
            return
        }
        #expect(v == -7)
    }

    @Test func decodeByteString() {
        let data = Data("5:hello".utf8)
        let result = BencodeDecoder(data: data).decode()
        guard case .bytes(let d) = result else {
            Issue.record("Expected bytes")
            return
        }
        #expect(String(data: d, encoding: .utf8) == "hello")
    }

    @Test func decodeList() {
        let data = Data("li1ei2ei3ee".utf8)
        let result = BencodeDecoder(data: data).decode()
        guard case .list(let items) = result else {
            Issue.record("Expected list")
            return
        }
        #expect(items.count == 3)
    }

    @Test func decodeDictionary() {
        let data = Data("d3:bar4:spam3:fooi42ee".utf8)
        let result = BencodeDecoder(data: data).decode()
        guard case .dictionary(let dict) = result else {
            Issue.record("Expected dictionary")
            return
        }
        #expect(dict.count == 2)
        if case .integer(let v) = dict["foo"] {
            #expect(v == 42)
        } else {
            Issue.record("Expected integer for key 'foo'")
        }
        if case .bytes(let d) = dict["bar"] {
            #expect(String(data: d, encoding: .utf8) == "spam")
        } else {
            Issue.record("Expected bytes for key 'bar'")
        }
    }

    @Test func decodeNestedStructure() {
        let data = Data("d4:infod5:filesld6:lengthi100e4:path4:testeeee".utf8)
        let result = BencodeDecoder(data: data).decode()
        guard case .dictionary(let root) = result,
              case .dictionary(let info) = root["info"],
              case .list(let files) = info["files"] else {
            Issue.record("Expected nested structure")
            return
        }
        #expect(files.count == 1)
    }

    @Test func decodeEmptyData() {
        let result = BencodeDecoder(data: Data()).decode()
        #expect(result == nil)
    }
}

@Suite("DownloadTask")
@MainActor
struct DownloadTaskTests {

    @Test func fromDictionary() {
        let dict: [String: Any] = [
            "gid": "abc123",
            "status": "active",
            "totalLength": "1000",
            "completedLength": "500",
            "downloadSpeed": "100",
            "uploadSpeed": "50",
            "dir": "/tmp",
            "files": [] as [[String: Any]]
        ]
        let task = DownloadTask.from(dict)
        #expect(task.gid == "abc123")
        #expect(task.status == .active)
        #expect(task.progress == 0.5)
    }

    @Test func statusMapping() {
        let statuses: [(String, TaskStatus)] = [
            ("active", .active),
            ("waiting", .waiting),
            ("paused", .paused),
            ("complete", .complete),
            ("error", .error),
            ("removed", .removed)
        ]
        for (raw, expected) in statuses {
            let task = DownloadTask.from(["gid": "x", "status": raw])
            #expect(task.status == expected)
        }
    }

    @Test func progressEdgeCases() {
        let zeroTotal = DownloadTask.from(["gid": "x", "totalLength": "0", "completedLength": "0"])
        #expect(zeroTotal.progress == 0)

        let complete = DownloadTask.from(["gid": "x", "totalLength": "100", "completedLength": "100"])
        #expect(complete.progress == 1.0)
    }
}

@Suite("AppState")
@MainActor
struct AppStateTests {

    @Test func filteredTasksByCategory() {
        let state = AppState()
        state.allActive = [
            DownloadTask.from(["gid": "1", "status": "active"]),
            DownloadTask.from(["gid": "2", "status": "waiting"]),
        ]
        state.allCompleted = [
            DownloadTask.from(["gid": "3", "status": "complete"]),
        ]
        state.allStopped = [
            DownloadTask.from(["gid": "4", "status": "error"]),
        ]

        state.currentList = .active
        #expect(state.filteredTasks.count == 2)

        state.currentList = .completed
        #expect(state.filteredTasks.count == 1)

        state.currentList = .stopped
        #expect(state.filteredTasks.count == 1)
    }

    @Test func globalTaskCountsIndependentOfFilter() {
        let state = AppState()
        state.allActive = [
            DownloadTask.from(["gid": "1", "status": "active"]),
        ]
        state.allCompleted = [
            DownloadTask.from(["gid": "2", "status": "complete"]),
            DownloadTask.from(["gid": "3", "status": "complete"]),
        ]
        state.allStopped = [
            DownloadTask.from(["gid": "4", "status": "error"]),
        ]

        state.currentList = .stopped
        #expect(state.activeTasks.count == 1)
        #expect(state.completedTasks.count == 2)
        #expect(state.stoppedTasks.count == 1)
    }

    @Test func adjustPollingInterval() {
        let state = AppState()
        state.globalStat = GlobalStat(downloadSpeed: 0, uploadSpeed: 0, numActive: 5, numWaiting: 0, numStopped: 0)
        state.adjustPollingInterval()
        #expect(state.pollingInterval == 0.5)

        state.globalStat = GlobalStat(downloadSpeed: 0, uploadSpeed: 0, numActive: 0, numWaiting: 0, numStopped: 0)
        state.pollingInterval = 1.0
        state.adjustPollingInterval()
        #expect(state.pollingInterval > 1.0)
    }
}
