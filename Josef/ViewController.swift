//
//  ViewController.swift
//  Josef
//
//  Created by Nigel Brookes-Thomas on 28/03/2017.
//  Copyright © 2017 gorlious.io. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var gyroLabel: UILabel!
    @IBOutlet weak var accelLabel: UILabel!
    
    // Gyroscope angles
    var angleX = 0.0
    var angleY = 0.0
    var angleZ = 0.0
    
    var initialAngleX = 0.0
    var initialAngleY = 0.0
    var initialAngleZ = 0.0
    
    // Gyroscope poll period
    let gyroPollPeriod = 1.0 // 1 sec
    var gyroHasBeenRead = false
    
    // BLE
    var centralManager : CBCentralManager!
    var sensorTagPeripheral : CBPeripheral!
    
    var filteredPositionData = (x: 0.0, y: 0.0, z: 0.0)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // BLE
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Scan for peripherals if BLE is turned on
            central.scanForPeripherals(withServices: nil, options: nil)
            self.temperatureLabel.text = "Searching for BLE Devices"
        }
        else {
            // Can have different conditions for all states if needed - print generic message for now
            print("Bluetooth switched off or not initialized")
        }
    }
    
    
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if SensorTag.found(advertisementData: advertisementData) {
            
            // Update Status temperatureLabel
            self.temperatureLabel.text = "Sensor Tag Found"
            
            // Stop scanning
            self.centralManager.stopScan()
            // Set as the peripheral to use and establish connection
            self.sensorTagPeripheral = peripheral
            self.sensorTagPeripheral.delegate = self
            self.centralManager.connect(peripheral, options: nil)
        }
    }
    
    
    
    // Discover services of the peripheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.temperatureLabel.text = "Discovering services"
        gyroHasBeenRead = false
        peripheral.discoverServices(nil)
    }
    
    
    
    // Disconnected, begin scanning again
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.temperatureLabel.text = "Disconnected"
        central.scanForPeripherals(withServices: nil, options: nil)
    }
    
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        self.temperatureLabel.text = "Examining services"
        for service in peripheral.services! {
            let thisService = service as CBService
//            print(service)
            
            if SensorTag.interesting(service: service) {
                // Discover characteristics of IR Temperature Service
                peripheral.discoverCharacteristics(nil, for: thisService)
            }
        }
    }
    
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // update status temperatureLabel
        self.temperatureLabel.text = "Enabling sensors"
        
        // check the uuid of each characteristic to find config and data characteristics
        for characteristic in service.characteristics! {
            let thisCharacteristic = characteristic as CBCharacteristic
            
            // check for data characteristic
            if SensorTag.interesting(characteristic: characteristic) {
                // Enable Sensor Notification
                self.sensorTagPeripheral.setNotifyValue(true, for: thisCharacteristic)
            }
            
            
            // check for config characteristic
            if SensorTag.enableable(characteristic: characteristic) {
                // Enable Sensor
                SensorTag.enable(peripheral: peripheral, characteristic: thisCharacteristic)
            }
        }
        
    }

    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case IRTemperatureDataUUID:
            let ambientTemperature = SensorTag.ambientTemperature(data: characteristic.value!)
            
            // Display on the temp temperatureLabel
            self.temperatureLabel.text = String(format: "%.2f°C", ambientTemperature)
            
        case AccelerometerDataUUID:
            guard characteristic.value != nil else {
                break
            }
            let data = characteristic.value!
            
            let gyroPosition = SensorTag.gyro(data: data)
            
            if !gyroHasBeenRead {
//                print(gyroPosition)
                angleX = gyroPosition.x * (1.0 / gyroPollPeriod)
                angleY = gyroPosition.y * (1.0 / gyroPollPeriod)
                angleZ = gyroPosition.z * (1.0 / gyroPollPeriod)
            } else {
                angleX = gyroPosition.x * (1.0 / gyroPollPeriod)
                angleY = gyroPosition.y * (1.0 / gyroPollPeriod)
                angleZ = gyroPosition.z * (1.0 / gyroPollPeriod)
                
                initialAngleX = angleX
                initialAngleY = angleY
                initialAngleZ = angleZ
                
                gyroHasBeenRead = true
            }
            
            self.gyroLabel.text = String(format: "Gyro X: %.1f° Y:%.1f° Z:%.1f°", angleX, angleY, angleZ)
            let accel = SensorTag.acceleromterAngles(data:data)
            
            self.accelLabel.text = String(format: "Accel X: %.1fG Y:%.1fG", accel.x, accel.y)
//            self.accelLabel.text = String(format: "X: %.1fG Y:%.1fG Z:%.1fG", accel.x, accel.y, accel.z)

            
            filteredPositionData = SensorTag.complimentaryFilter(currentValues: (x: angleX, y: angleY, z: angleZ),
                                                                 data: data,
                                                                 sampleRate: gyroPollPeriod)
            
//            print(String(format: "X: %.1f° Y:%.1f° Z:%.1f°", filteredPositionData.x, filteredPositionData.y, filteredPositionData.z))
        default:
            return
        }
    }

}
