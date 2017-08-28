//
//  XGPS.swift
//  XPlaneMap
//
//  Created by Philippe Bernery on 28/08/2017.
//  Copyright © 2017 Philippe Bernery. All rights reserved.
//

import Foundation
import MapKit

struct XGPS: XPlaneMessage {
    static var type: String {
        return "XGPS"
    }

    let location: CLLocation
}
