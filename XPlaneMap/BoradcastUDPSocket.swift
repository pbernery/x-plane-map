//
//  BoradcastUDPSocket.swift
//  XPlaneMap
//
//  Created by Philippe Bernery on 28/08/2017.
//  Copyright © 2017 Philippe Bernery. All rights reserved.
//

import Foundation

/// A UDP Socket set to listen to broadcasted data.
/// Inspired from [Gunter Hager UDPBroadcastConnection](https://github.com/gunterhager/UDPBroadcastConnection)
class BroadcastUDPSocket {
    /// A dispatch source for reading data from the UDP socket.
    var responseSource: DispatchSourceRead?

    public init?(port: UInt16, handler: ((_ ipAddress: String, _ port: Int, _ response: [UInt8]) -> Void)?) {
        var address = sockaddr_in(
            sin_len: __uint8_t(MemoryLayout<sockaddr_in>.size),
            sin_family: sa_family_t(AF_INET),
            sin_port: SocketHelpers.htonsPort(port: port),
            sin_addr: in_addr(s_addr: INADDR_ANY),
            sin_zero: ( 0, 0, 0, 0, 0, 0, 0, 0 )
        )

        let newSocket = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)
        let status = withUnsafePointer(to: &address) { pointer in
            return bind(newSocket,
                        UnsafeRawPointer(pointer).bindMemory(to: sockaddr.self, capacity: 1),
                        socklen_t(MemoryLayout<sockaddr_in>.size))
        }

        if status == -1 {
            print("Couldn't bind socket")
            close(newSocket)
            return nil
        }

        // Set up a dispatch source
        let newResponseSource = DispatchSource.makeReadSource(fileDescriptor: newSocket, queue: DispatchQueue.main)

        // Set up cancel handler
        newResponseSource.setCancelHandler {
            print("Closing UDP socket")
            let UDPSocket = Int32(newResponseSource.handle)
            shutdown(UDPSocket, SHUT_RDWR)
            close(UDPSocket)
        }

        // Set up event handler (gets called when data arrives at the UDP socket)
        newResponseSource.setEventHandler { [weak self] in
            guard let wSelf = self else { return }
            guard let source = wSelf.responseSource else { return }

            var socketAddress = sockaddr_storage()
            var socketAddressLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let response = [UInt8](repeating: 0, count: 512)
            let UDPSocket = Int32(source.handle)

            let bytesRead = withUnsafeMutablePointer(to: &socketAddress) {
                recvfrom(UDPSocket, UnsafeMutableRawPointer(mutating: response), response.count, 0,
                         UnsafeMutableRawPointer($0).bindMemory(to: sockaddr.self, capacity: 1), &socketAddressLength)
            }

            guard bytesRead >= 0 else {
                if let errorString = String(validatingUTF8: strerror(errno)) {
                    print("recvfrom failed: \(errorString)")
                }
                self?.closeConnection()
                return
            }

            guard bytesRead > 0 else {
                print("recvfrom returned EOF")
                self?.closeConnection()
                return
            }

            guard let endpoint = withUnsafePointer(to: &socketAddress, { wSelf.getEndpointFromSocketAddress(socketAddressPointer: UnsafeRawPointer($0).bindMemory(to: sockaddr.self, capacity: 1)) })
                else {
                    print("Failed to get the address and port from the socket address received from recvfrom")
                    self?.closeConnection()
                    return
            }

            // print("UDP connection received \(bytesRead) bytes from \(endpoint.host):\(endpoint.port)")

            // Handle response
            handler?(endpoint.host, endpoint.port, response)
        }

        newResponseSource.resume()
        responseSource = newResponseSource
    }

    deinit {
        responseSource?.cancel()
    }

    func closeConnection() {
        if let source = responseSource {
            source.cancel()
            responseSource = nil
        }
    }

    func getEndpointFromSocketAddress(socketAddressPointer: UnsafePointer<sockaddr>) -> (host: String, port: Int)? {
        let socketAddress = UnsafePointer<sockaddr>(socketAddressPointer).pointee

        switch Int32(socketAddress.sa_family) {
        case AF_INET:
            var socketAddressInet = UnsafeRawPointer(socketAddressPointer).load(as: sockaddr_in.self)
            let length = Int(INET_ADDRSTRLEN) + 2
            var buffer = [CChar](repeating: 0, count: length)
            let hostCString = inet_ntop(AF_INET, &socketAddressInet.sin_addr, &buffer, socklen_t(length))
            let port = Int(UInt16(socketAddressInet.sin_port).byteSwapped)
            return (String(cString: hostCString!), port)

        case AF_INET6:
            var socketAddressInet6 = UnsafeRawPointer(socketAddressPointer).load(as: sockaddr_in6.self)
            let length = Int(INET6_ADDRSTRLEN) + 2
            var buffer = [CChar](repeating: 0, count: length)
            let hostCString = inet_ntop(AF_INET6, &socketAddressInet6.sin6_addr, &buffer, socklen_t(length))
            let port = Int(UInt16(socketAddressInet6.sin6_port).byteSwapped)
            return (String(cString: hostCString!), port)

        default:
            return nil
        }
    }
}

fileprivate struct SocketHelpers {
    static func htonsPort(port: in_port_t) -> in_port_t {
        let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
        return isLittleEndian ? _OSSwapInt16(port) : port
    }
    
    static func ntohs(value: CUnsignedShort) -> CUnsignedShort {
        return (value << 8) + (value >> 8)
    }
}
