//
//  SensorTag.swift
//  Josef
//
//  Created by Nigel Brookes-Thomas on 01/04/2017.
//  Copyright © 2017 gorlious.io. All rights reserved.
//

import Foundation
import CoreBluetooth

// SensorTag Bluetooth advertisement name
let deviceName = "CC2650 SensorTag"

let IRTemperatureServiceUUID = CBUUID(string: "F000AA00-0451-4000-B000-000000000000")
let AccelerometerServiceUUID = CBUUID(string: "F000AA80-0451-4000-B000-000000000000")
let HumidityServiceUUID      = CBUUID(string: "F000AA20-0451-4000-B000-000000000000")
let MagnetometerServiceUUID  = CBUUID(string: "F000AA30-0451-4000-B000-000000000000")
let BarometerServiceUUID     = CBUUID(string: "F000AA40-0451-4000-B000-000000000000")
let GyroscopeServiceUUID     = CBUUID(string: "F000AA50-0451-4000-B000-000000000000")

// Characteristic UUIDs
let IRTemperatureDataUUID   = CBUUID(string: "F000AA01-0451-4000-B000-000000000000")
let IRTemperatureConfigUUID = CBUUID(string: "F000AA02-0451-4000-B000-000000000000")
let AccelerometerDataUUID   = CBUUID(string: "F000AA81-0451-4000-B000-000000000000")
let AccelerometerConfigUUID = CBUUID(string: "F000AA82-0451-4000-B000-000000000000")
let AccelerometerPollUUID   = CBUUID(string: "F000AA83-0451-4000-B000-000000000000")
let HumidityDataUUID        = CBUUID(string: "F000AA21-0451-4000-B000-000000000000")
let HumidityConfigUUID      = CBUUID(string: "F000AA22-0451-4000-B000-000000000000")
let MagnetometerDataUUID    = CBUUID(string: "F000AA31-0451-4000-B000-000000000000")
let MagnetometerConfigUUID  = CBUUID(string: "F000AA32-0451-4000-B000-000000000000")
let BarometerDataUUID       = CBUUID(string: "F000AA41-0451-4000-B000-000000000000")
let BarometerConfigUUID     = CBUUID(string: "F000AA42-0451-4000-B000-000000000000")
let GyroscopeDataUUID       = CBUUID(string: "F000AA51-0451-4000-B000-000000000000")
let GyroscopeConfigUUID     = CBUUID(string: "F000AA52-0451-4000-B000-000000000000")


class SensorTag {
    
    // Complimentary filter params
    static let alpha = 0.5
 
    class func found(advertisementData: [String : Any]) -> Bool {
        let nameOfDeviceFound = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? NSString
        
        // we must have found a name
        guard (nameOfDeviceFound != nil) else {
            return false
        }
        
        // skip if the device is not a SensorTag
        guard (nameOfDeviceFound! as String == deviceName) else {
            print("Incompatible device: \(nameOfDeviceFound!)")
            return false
        }
        
        return true
    }
    
    
    class func interesting(service: CBService) -> Bool {
        return
            service.uuid == IRTemperatureServiceUUID ||
            service.uuid == AccelerometerServiceUUID
    }
    
    
    class func interesting(characteristic: CBCharacteristic) -> Bool {
        return
            characteristic.uuid == IRTemperatureDataUUID ||
            characteristic.uuid == AccelerometerDataUUID
    }
    
    
    class func enableable(characteristic: CBCharacteristic) -> Bool {
        return
            characteristic.uuid == IRTemperatureConfigUUID ||
            characteristic.uuid == AccelerometerConfigUUID ||
            characteristic.uuid == AccelerometerPollUUID
    }
    
    class func enable(peripheral:CBPeripheral, characteristic: CBCharacteristic) {
        // 0x01 data byte to enable sensor
        let enableValue: UInt8
        let enablyBytes: Data
        
        if characteristic.uuid == AccelerometerConfigUUID {
            enableValue = 0b00111111
            // accelerometer takes 2 byts config: msb:lsb
            enablyBytes = Data(bytes: [enableValue, 0b00000010])
        } else if characteristic.uuid == AccelerometerPollUUID{
            enableValue = 0x64
            enablyBytes = Data(bytes: [enableValue])
        } else {
            enableValue = 0b00000001
            enablyBytes = Data(bytes: [enableValue])
        }
        peripheral.writeValue(enablyBytes, for: characteristic, type: CBCharacteristicWriteType.withResponse)
    }
    
    class func ambientTemperature(data: Data) -> Double {
        // Convert NSData to array of signed 16 bit values
        let lsb = data[2]
        let msb = data[3]
        let tempBitPattern = UInt16(lsb) + (UInt16(msb) << 8)
        let temp = Int16(bitPattern: tempBitPattern)
        
        // Element 1 of the array will be ambient temperature raw value
        let ambientTemperature = Double(temp) / 128.0
        
        return ambientTemperature
    }
    
    class func gyro(data: Data) -> (x: Double, y: Double, z: Double) {
        let lsbX = data[0]
        let msbX = data[1]
        let lsbY = data[2]
        let msbY = data[3]
        let lsbZ = data[4]
        let msbZ = data[5]
        
        let gyroBitPatternX = Int16(bitPattern: UInt16(lsbX) + (UInt16(msbX) << 8))
        let gyroBitPatternY = Int16(bitPattern: UInt16(lsbY) + (UInt16(msbY) << 8))
        let gyroBitPatternZ = Int16(bitPattern: UInt16(lsbZ) + (UInt16(msbZ) << 8))
        
        let gyroX = Double(gyroBitPatternX) / (65536.0 / 500.0)
        let gyroY = Double(gyroBitPatternY) / (65536.0 / 500.0)
        let gyroZ = Double(gyroBitPatternZ) / (65536.0 / 500.0)
        
        let gyro = (x: gyroX, y: gyroY, z: gyroZ)
        
        return gyro
    }
    
    class func accelerometer(data: Data) -> (x: Double, y: Double, z: Double) {
        let lsbX = data[ 6]
        let msbX = data[ 7]
        let lsbY = data[ 8]
        let msbY = data[ 9]
        let lsbZ = data[10]
        let msbZ = data[11]
        
        let accelBitPatternX = Int16(bitPattern: UInt16(lsbX) + (UInt16(msbX) << 8))
        let accelBitPatternY = Int16(bitPattern: UInt16(lsbY) + (UInt16(msbY) << 8))
        let accelBitPatternZ = Int16(bitPattern: UInt16(lsbZ) + (UInt16(msbZ) << 8))
        
        let accelX = Double(accelBitPatternX) / (32768.0 / 8.0)
        let accelY = Double(accelBitPatternY) / (32768.0 / 8.0)
        let accelZ = Double(accelBitPatternZ) / (32768.0 / 8.0)
        
        let accel = (x: accelX, y: accelY, z: accelZ)
        
        return accel
    }
    
    class func acceleromterAngles(data: Data) -> (x: Double, y: Double) {
        let accelData = accelerometer(data: data)
        
        // compute squares
        let x2 = accelData.x * accelData.x
        let y2 = accelData.y * accelData.y
        let z2 = (accelData.z - 1.0) * (accelData.z - 1.0) // factor out normal z-gravity
        
        let xAxis = accelData.x / sqrt(y2+z2)
        let xAngle = atan(accelData.y / accelData.z) //atan(xAxis)
        
        let yAxis = accelData.y / sqrt(x2+z2)
        let yAngle = atan(accelData.x / accelData.z)//atan(yAxis)
        
        let result = (x: xAngle, y: yAngle)
        print(result)
        return result
    }
    
    class func complimentaryFilter(currentValues: (x: Double, y: Double, z: Double),
                                   data: Data,
                                   sampleRate:Double = 1000) -> (x: Double, y:Double, z: Double) {
//        filteredAngle[i] = alpha * (filteredAngle[i] + omega[i] * ts / 1000) + (1 - alpha) * accAngle[i];
        let gyro  = self.gyro(data: data)
        let accel = self.accelerometer(data: data)
        
        let x = alpha * (currentValues.x + gyro.x * (sampleRate * 1000.0) / 1000.0) + (1 - alpha) * accel.x
        let y = alpha * (currentValues.x + gyro.y * (sampleRate * 1000.0) / 1000.0) + (1 - alpha) * accel.y
        let z = alpha * (currentValues.x + gyro.z * (sampleRate * 1000.0) / 1000.0) + (1 - alpha) * accel.z
        
        return (x: x, y: y, z: z)
    }

    
}
