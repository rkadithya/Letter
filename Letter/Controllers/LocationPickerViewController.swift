//
//  LocationPickerViewController.swift
//  Letter
//
//  Created by Adithya on 15/09/24.
//
import UIKit
import CoreLocation
import MapKit

import Foundation

class LocationPickerViewController:UIViewController{
    public var completion:((CLLocationCoordinate2D) -> Void)?
    private var  coordinates:CLLocationCoordinate2D?
    public var isPickable = true
    
    private let map:MKMapView = {
        let mapView = MKMapView()
        return mapView
    }()
    
    init(coordinates: CLLocationCoordinate2D?){
        self.coordinates = coordinates
        self.isPickable = false
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    


    override func viewDidLoad() {
        super.viewDidLoad()
//        title = "Pick Location"
        view.backgroundColor = .systemBackground

        if isPickable{
            map.isUserInteractionEnabled = true
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: self, action: #selector(sendButtonTapped))
            let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapMap(_:)))
            gesture.numberOfTouchesRequired = 1
            gesture.numberOfTapsRequired = 1
            map.addGestureRecognizer(gesture)

        }else{
            //Just showing Location
            guard let coordinates = self.coordinates else{return}
            let pin = MKPointAnnotation()
            pin.coordinate = coordinates
            map.addAnnotation(pin)
        }
        view.addSubview(map)

    }
    
    @objc func sendButtonTapped(){
        guard let coordinates = coordinates else{
            return
        }
        navigationController?.popViewController(animated: true)
        completion?(coordinates)
    }
    
    @objc func didTapMap(_ gesture:UITapGestureRecognizer){
        let locationInView = gesture.location(in: map)
        let coordinates = map.convert(locationInView, toCoordinateFrom: map)
        self.coordinates = coordinates
        
        for annotation in map.annotations{
            map.removeAnnotation(annotation)
        }
        //Drop pin on location
        let pin = MKPointAnnotation()
        pin.coordinate = coordinates
        map.addAnnotation(pin)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
    }
}

