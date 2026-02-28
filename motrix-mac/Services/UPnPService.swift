import Foundation
import Darwin
import os

actor UPnPService {
    private let logger = Logger(subsystem: "app.motrix", category: "UPnP")
    private var mapped = false
    private var mappedPort: UInt16?
    private var mappedControlURL: URL?
    private var mappedServiceType: String?
    private var mappedInternalClient: String?

    func mapPort(_ port: UInt16) async {
        if mapped, mappedPort == port {
            return
        }
        if mapped {
            await unmapPort()
        }
        guard let internalClient = localIPv4Address() else {
            logger.error("UPnP map failed: could not resolve local IPv4 address")
            return
        }
        guard let gateway = await discoverGateway() else {
            logger.warning("UPnP map failed: no IGD gateway discovered")
            return
        }
        let success = await addPortMapping(
            controlURL: gateway.controlURL,
            serviceType: gateway.serviceType,
            externalPort: port,
            internalPort: port,
            internalClient: internalClient
        )
        mapped = success
        if success {
            mappedPort = port
            mappedControlURL = gateway.controlURL
            mappedServiceType = gateway.serviceType
            mappedInternalClient = internalClient
        } else {
            mappedPort = nil
            mappedControlURL = nil
            mappedServiceType = nil
            mappedInternalClient = nil
        }
        logger.info("UPnP map attempt for port \(port): \(self.mapped ? "success" : "failed")")
    }

    func unmapPort() async {
        if mapped,
           let controlURL = mappedControlURL,
           let serviceType = mappedServiceType,
           let port = mappedPort {
            _ = await deletePortMapping(
                controlURL: controlURL,
                serviceType: serviceType,
                externalPort: port
            )
        }
        mapped = false
        mappedPort = nil
        mappedControlURL = nil
        mappedServiceType = nil
        mappedInternalClient = nil
    }

    private struct GatewayControl {
        let controlURL: URL
        let serviceType: String
    }

    private func discoverGateway() async -> GatewayControl? {
        let requests = [
            "urn:schemas-upnp-org:service:WANIPConnection:1",
            "urn:schemas-upnp-org:service:WANPPPConnection:1",
            "urn:schemas-upnp-org:device:InternetGatewayDevice:1"
        ]
        for st in requests {
            guard let response = performSSDPDiscover(st: st),
                  let location = extractHeader("location", from: response),
                  let descriptionURL = URL(string: location) else {
                continue
            }
            guard let xml = await fetchDescriptionXML(from: descriptionURL),
                  let service = extractWANService(from: xml),
                  let controlURL = resolveControlURL(service.controlURL, base: descriptionURL) else {
                continue
            }
            return GatewayControl(controlURL: controlURL, serviceType: service.serviceType)
        }
        return nil
    }

    private func performSSDPDiscover(st: String) -> String? {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return nil }
        defer { close(sock) }

        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        withUnsafePointer(to: &timeout) {
            _ = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, UnsafeRawPointer($0), socklen_t(MemoryLayout<timeval>.size))
        }

        let request = """
M-SEARCH * HTTP/1.1\r
HOST:239.255.255.250:1900\r
MAN:"ssdp:discover"\r
MX:2\r
ST:\(st)\r
\r
"""

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(1900).bigEndian
        addr.sin_addr.s_addr = inet_addr("239.255.255.250")

        let sendResult = request.withCString { ptr in
            withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    sendto(sock, ptr, strlen(ptr), 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sendResult > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: 4096)
        var fromAddr = sockaddr_in()
        var fromLen: socklen_t = socklen_t(MemoryLayout<sockaddr_in>.size)
        let recvLen = withUnsafeMutablePointer(to: &fromAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                recvfrom(sock, &buffer, buffer.count - 1, 0, sockaddrPtr, &fromLen)
            }
        }
        guard recvLen > 0 else { return nil }
        buffer[Int(recvLen)] = 0
        return decodeCString(buffer)
    }

    private func extractHeader(_ name: String, from response: String) -> String? {
        let prefix = "\(name.lowercased()):"
        for line in response.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            if lower.hasPrefix(prefix) {
                return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func fetchDescriptionXML(from url: URL) async -> String? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func extractWANService(from xml: String) -> (serviceType: String, controlURL: String)? {
        let pattern = "<service>\\s*<serviceType>([^<]+)</serviceType>[\\s\\S]*?<controlURL>([^<]+)</controlURL>[\\s\\S]*?</service>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsRange = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        let matches = regex.matches(in: xml, options: [], range: nsRange)
        for match in matches where match.numberOfRanges >= 3 {
            guard let typeRange = Range(match.range(at: 1), in: xml),
                  let urlRange = Range(match.range(at: 2), in: xml) else {
                continue
            }
            let serviceType = String(xml[typeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let controlURL = String(xml[urlRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if serviceType.contains("WANIPConnection") || serviceType.contains("WANPPPConnection") {
                return (serviceType, controlURL)
            }
        }
        return nil
    }

    private func resolveControlURL(_ controlURL: String, base: URL) -> URL? {
        if let absolute = URL(string: controlURL), absolute.scheme != nil {
            return absolute
        }
        return URL(string: controlURL, relativeTo: base)?.absoluteURL
    }

    private func addPortMapping(controlURL: URL, serviceType: String, externalPort: UInt16, internalPort: UInt16, internalClient: String) async -> Bool {
        let body = """
<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body>
<u:AddPortMapping xmlns:u="\(serviceType)">
<NewRemoteHost></NewRemoteHost>
<NewExternalPort>\(externalPort)</NewExternalPort>
<NewProtocol>TCP</NewProtocol>
<NewInternalPort>\(internalPort)</NewInternalPort>
<NewInternalClient>\(internalClient)</NewInternalClient>
<NewEnabled>1</NewEnabled>
<NewPortMappingDescription>motrix-mac</NewPortMappingDescription>
<NewLeaseDuration>0</NewLeaseDuration>
</u:AddPortMapping>
</s:Body>
</s:Envelope>
"""
        return await performSOAP(controlURL: controlURL, serviceType: serviceType, action: "AddPortMapping", body: body)
    }

    private func deletePortMapping(controlURL: URL, serviceType: String, externalPort: UInt16) async -> Bool {
        let body = """
<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body>
<u:DeletePortMapping xmlns:u="\(serviceType)">
<NewRemoteHost></NewRemoteHost>
<NewExternalPort>\(externalPort)</NewExternalPort>
<NewProtocol>TCP</NewProtocol>
</u:DeletePortMapping>
</s:Body>
</s:Envelope>
"""
        return await performSOAP(controlURL: controlURL, serviceType: serviceType, action: "DeletePortMapping", body: body)
    }

    private func performSOAP(controlURL: URL, serviceType: String, action: String, body: String) async -> Bool {
        var request = URLRequest(url: controlURL)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(serviceType)#\(action)\"", forHTTPHeaderField: "SOAPAction")
        request.httpBody = body.data(using: .utf8)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }

    private func localIPv4Address() -> String? {
        var addresses: [String] = []
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }
        var pointer = first
        while true {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)
            if let addr = interface.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_INET),
               (flags & IFF_UP) == IFF_UP,
               (flags & IFF_LOOPBACK) != IFF_LOOPBACK {
                let name = String(cString: interface.ifa_name)
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    addr,
                    socklen_t(addr.pointee.sa_len),
                    &host,
                    socklen_t(host.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                if result == 0 {
                    let ip = decodeCString(host)
                    if name == "en0" {
                        return ip
                    }
                    addresses.append(ip)
                }
            }
            if let next = interface.ifa_next {
                pointer = next
            } else {
                break
            }
        }
        return addresses.first
    }

    private func decodeCString(_ bytes: [CChar]) -> String {
        let utf8 = bytes.map { UInt8(bitPattern: $0) }
        if let zeroIndex = utf8.firstIndex(of: 0) {
            return String(decoding: utf8[..<zeroIndex], as: UTF8.self)
        }
        return String(decoding: utf8, as: UTF8.self)
    }
}
