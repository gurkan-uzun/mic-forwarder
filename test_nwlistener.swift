import Network

let parameters = NWParameters.tcp
parameters.requiredInterfaceType = .loopback // Just checking what's available
print(parameters)
