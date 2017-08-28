//
//  XPlaneListener.swift
//  XPlaneMap
//
//  Created by Philippe Bernery on 27/08/2017.
//  Copyright © 2017 Philippe Bernery. All rights reserved.
//

import Foundation
import CoreLocation

/// Listen to broadcasted messages on port 49002, parse messages
/// and dispatch them.
class XPlaneListener {
    typealias XPlaneMessageHandler = (_ senderName: String, _ message: XPlaneMessage) -> ()

    private let socket: BroadcastUDPSocket

    init(handler: @escaping XPlaneMessageHandler) {
        guard let socket = BroadcastUDPSocket(port: 49002, handler: { (ip, port, response) in
            let string = String(cString: response)
            Logger.log(level: .debug, message: "receiving from \(ip):\(port) => \(string)")

            let components = string.components(separatedBy: ",")
            guard let typeAndSender = components.first, typeAndSender.characters.count > 4 else { return }

            let type = typeAndSender[0..<4]
            let sender = typeAndSender.substring(from: 4)

            let message: XPlaneMessage?
            switch type {
            case XGPS.type:
                message = XGPS(components: Array(components[1..<components.count]))
            default:
                Logger.log(level: .warning, message: "Unhandled message: \(type)")
                message = nil
            }

            if let message = message {
                handler(sender, message)
            }
        }) else {
            fatalError("cannot initialize socket")
        }

        self.socket = socket
    }
}

// MARK: - XPlaneMessage builders

extension XGPS {
    fileprivate init?(components: [String]) {
        guard components.count == 5,
            let longitude = CLLocationDegrees(components[0]),
            let latitude = CLLocationDegrees(components[1]),
            let altitude = CLLocationDistance(components[2]),
            let course = CLLocationDirection(components[3]),
            let speed = CLLocationSpeed(components[4]) else {
                Logger.log(level: .error, message: "cannot parse XGPS message: \(components)")
                return nil
        }

        location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                              altitude: altitude,
                              horizontalAccuracy: 0, verticalAccuracy: 0,
                              course: course,
                              speed: speed,
                              timestamp: Date())
    }
}
