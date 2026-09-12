import Network

let tcpOptions = NWProtocolTCP.Options()
let parameters = NWParameters(tls: nil, tcp: tcpOptions)
parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "0.0.0.0", port: 12345)
parameters.allowLocalEndpointReuse = true

do {
    let listener = try NWListener(using: parameters)
    print("Bound listener successfully")
} catch {
    print("Failed: \(error)")
}
