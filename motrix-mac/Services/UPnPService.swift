import Foundation
import os

actor UPnPService {
    private let logger = Logger(subsystem: "app.motrix", category: "UPnP")
    private var mapped = false

    func mapPort(_ port: UInt16) async {
        guard !mapped else { return }
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [
                "python3", "-c",
                """
                import socket, struct
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
                s.settimeout(2)
                msg = b'\\x01\\x00' + struct.pack('>H', \(port))
                s.sendto(msg, ('239.255.255.250', 1900))
                s.close()
                """
            ]
            try process.run()
            process.waitUntilExit()
            mapped = process.terminationStatus == 0
            logger.info("UPnP map attempt for port \(port): \(self.mapped ? "success" : "failed")")
        } catch {
            logger.error("UPnP failed: \(error.localizedDescription)")
        }
    }

    func unmapPort() {
        mapped = false
    }
}
