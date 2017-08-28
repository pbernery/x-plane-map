//
//  ViewController.swift
//  XPlaneMap
//
//  Created by Philippe Bernery on 27/08/2017.
//  Copyright © 2017 Philippe Bernery. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var fromLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    
    var listener: XPlaneListener?

    fileprivate lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
    fileprivate var lastLocation: CLLocation?

    override func viewDidLoad() {
        super.viewDidLoad()

        listener = XPlaneListener(handler: { (sender, message) in
            switch message {
            case is XGPS:
                guard let gps = message as? XGPS else { return }
                self.updateGPSLabels(sender: sender, gps: gps)
                self.updateMap(gps: gps)
            default:
                Logger.log(level: .debug, message: "Unknown message: \(String(describing: message))")
            }
        })
    }
}

// MARK: - XGPS Helpers

extension ViewController {
    func updateGPSLabels(sender: String, gps: XGPS) {
        infoLabel.text = "Refreshed at \(dateFormatter.string(from: gps.location.timestamp))"

        latitudeLabel.text = "Lat.: \(gps.location.coordinate.latitude)"
        longitudeLabel.text = "Long.: \(gps.location.coordinate.longitude)"
        headingLabel.text = "Course: \(gps.location.course)°"
        speedLabel.text = "Speed: \(gps.location.speed) m/s"

        let from: String
        switch sender {
        case "1":
            from = "X-Plane specific IP mode"
        case "2":
            from = "X-Plane broadcast mode"
        default:
            from = sender
        }
        fromLabel.text = "From \(from)"
    }

    func updateMap(gps: XGPS) {
        let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        mapView.setRegion(MKCoordinateRegion(center: gps.location.coordinate, span: span), animated: true)

        if let lastLocation = lastLocation {
            mapView.removeAnnotation(lastLocation)
        }
        mapView.addAnnotation(gps.location)
        lastLocation = gps.location
    }
}

extension CLLocation: MKAnnotation {
}
