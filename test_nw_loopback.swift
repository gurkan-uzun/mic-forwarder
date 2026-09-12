import Network

let tcpOptions = NWProtocolTCP.Options()
let parameters = NWParameters(tls: nil, tcp: tcpOptions)
parameters.requiredInterfaceType = .loopback
parameters.allowLocalEndpointReuse = true

do {
    let listener = try NWListener(using: parameters, on: 12345)
    print("Bound listener successfully on loopback")
} catch {
    print("Failed: \(error)")
}
