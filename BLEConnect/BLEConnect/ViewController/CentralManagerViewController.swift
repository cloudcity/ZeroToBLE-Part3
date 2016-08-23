//
//  CentralManagerViewController.swift
//  BLEConnect
//
//  Created by Evan Stone on 8/12/16.
//  Copyright © 2016 Cloud City. All rights reserved.
//

import UIKit
import CoreBluetooth

class CentralManagerViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var rssiLabel: UILabel!
    @IBOutlet weak var connectionIndicatorView: UIView!
    
    var centralManager:CBCentralManager!
    var peripheral:CBPeripheral?
    var dataBuffer:NSMutableData!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.text = ""
        self.textView.layer.borderColor = UIColor.lightGrayColor().CGColor
        self.textView.layer.borderWidth = 1.0
        
        rssiLabel.text = ""
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        connectionIndicatorView.layer.backgroundColor = UIColor.redColor().CGColor
        connectionIndicatorView.layer.cornerRadius = connectionIndicatorView.frame.height / 2
    }
   
    override func viewWillAppear(animated: Bool) {
        self.textView.text = ""
        dataBuffer = NSMutableData()
    }
    
    override func viewWillDisappear(animated: Bool) {
        stopScanning()
        cleanupCentral()
    }
    
    
    // MARK: Central management methods
    
    func stopScanning() {
        centralManager.stopScan()
    }
    
    func startScanning() {
        centralManager.scanForPeripheralsWithServices([CBUUID.init(string: Device.TransferService)], options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
        print("Scanning Started!")
    }
    
    /*
     Call this when things either go wrong, or you're done with the connection.
     This cancels any subscriptions if there are any, or straight disconnects if not.
     (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
     */
    func cleanupCentral() {
        
        // verify we have a peripheral
        guard let peripheral = self.peripheral else {
            print("No peripheral available to cleanup.")
            return
        }
        
        // Don't do anything if we're not connected
        if peripheral.state != .Connected {
            print("Peripheral is not connected.")
            return
        }
        
        if let services = peripheral.services {
            // iterate through services
            for service in services {
                // iterate through characteristics
                if let characteristics = service.characteristics {
                    for characteristic in characteristics {
                        // find the Transfer Characteristic we defined in our Device struct
                        if characteristic.UUID == CBUUID.init(string: Device.TransferCharacteristic) {
                            peripheral.setNotifyValue(false, forCharacteristic: characteristic)
                            return
                        }
                    }
                }
            }
        }
        
        // We have a connection to the device but we are not subscribed to the Transfer Characteristic for some reason.
        // Therefore, we will just disconnect from the peripheral
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    
    // MARK: CBCentralManagerDelegate Methods
    
    /* 
     Invoked when the central manager’s state is updated.
     This is where we kick off the scanning if Bluetooth is turned on and is active.
     */
    func centralManagerDidUpdateState(central: CBCentralManager) {
        print("Central Manager State Updated: \(central.state)")
        
        // We showed more detailed handling of this in Zero-to-BLE Part 2, so please refer to that if you would like more information.
        // We will just handle it the easy way here: if Bluetooth is on, proceed...
        if central.state != .PoweredOn {
            return
        }
        
        startScanning()
    }
    
    /*
     Invoked when the central manager discovers a peripheral while scanning.
     
     The advertisement data can be accessed through the keys listed in Advertisement Data Retrieval Keys.
     You must retain a local copy of the peripheral if any command is to be performed on it.
     In use cases where it makes sense for your app to automatically connect to a peripheral that is
     located within a certain range, you can use RSSI data to determine the proximity of a discovered
     peripheral device.
     
     central - The central manager providing the update.
     peripheral - The discovered peripheral.
     advertisementData - A dictionary containing any advertisement data.
     RSSI - The current received signal strength indicator (RSSI) of the peripheral, in decibels.

     */
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        print("Discovered \(peripheral.name) at \(RSSI)")
        rssiLabel.text = RSSI.stringValue
        
        // Reject if the signal strength is too low to be close enough ("close" is around -22dB)
        if RSSI.integerValue < -35 {
            rssiLabel.textColor = UIColor.redColor()
            return;
        }
        
        print("Device is in acceptable range!!")
        rssiLabel.textColor = UIColor.greenColor()
        
        // check to see if we've already saved a reference to this peripheral
        if self.peripheral != peripheral {
            
            // save a reference to the peripheral object so Core Bluetooth doesn't get rid of it
            self.peripheral = peripheral
            
            // connect to the peripheral
            print("Connecting to peripheral: \(peripheral)")
            centralManager?.connectPeripheral(peripheral, options: nil)
        }
    }
    
    
    /*
     Invoked when a connection is successfully created with a peripheral.
     
     This method is invoked when a call to connectPeripheral:options: is successful.
     You typically implement this method to set the peripheral’s delegate and to discover its services.
     */
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("Peripheral Connected!!!")
        
        connectionIndicatorView.layer.backgroundColor = UIColor.greenColor().CGColor
        
        // Stop scanning
        centralManager.stopScan()
        print("Scanning Stopped!")

        // Clear any cached data...
        dataBuffer.length = 0
        
        // IMPORTANT: Set the delegate property, otherwise we won't receive the discovery callbacks, like peripheral(_:didDiscoverServices)
        peripheral.delegate = self
        
        // Now that we've successfully connected to the peripheral, let's discover the services.
        // This time, we will search for the transfer service UUID
        print("Looking for Transfer Service...")
        peripheral.discoverServices([CBUUID.init(string: Device.TransferService)])
    }
    
    
    /*
     Invoked when the central manager fails to create a connection with a peripheral.
     
     This method is invoked when a connection initiated via the connectPeripheral:options: method fails to complete.
     Because connection attempts do not time out, a failed connection usually indicates a transient issue,
     in which case you may attempt to connect to the peripheral again.
     */
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Failed to connect to \(peripheral) (\(error?.localizedDescription))")
        connectionIndicatorView.layer.backgroundColor = UIColor.redColor().CGColor
        self.cleanupCentral()
    }
    
    
    /*
     Invoked when an existing connection with a peripheral is torn down.
     
     This method is invoked when a peripheral connected via the connectPeripheral:options: method is disconnected.
     If the disconnection was not initiated by cancelPeripheralConnection:, the cause is detailed in error.
     After this method is called, no more methods are invoked on the peripheral device’s CBPeripheralDelegate object.
     
     Note that when a peripheral is disconnected, all of its services, characteristics, and characteristic descriptors are invalidated.
     */
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        // set our reference to nil and start scanning again...
        print("Disconnected from Peripheral")
        connectionIndicatorView.layer.backgroundColor = UIColor.redColor().CGColor
        self.peripheral = nil
        startScanning()
    }
    
    
    //MARK: - CBPeripheralDelegate methods
    
    /*
     Invoked when you discover the peripheral’s available services.
     
     This method is invoked when your app calls the discoverServices: method.
     If the services of the peripheral are successfully discovered, you can access them
     through the peripheral’s services property.
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    // When the specified services are discovered, the peripheral calls the peripheral:didDiscoverServices: method of its delegate object.
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        print("Discovered Services!!!")

        if error != nil {
            print("Error discovering services: \(error?.localizedDescription)")
            cleanupCentral()
            return
        }
        
        // Core Bluetooth creates an array of CBService objects —- one for each service that is discovered on the peripheral.
        if let services = peripheral.services {
            for service in services {
                print("Discovered service \(service)")
                
                // If we found either the transfer service, discover the transfer characteristic
                if (service.UUID == CBUUID(string: Device.TransferService)) {
                    let transferCharacteristicUUID = CBUUID.init(string: Device.TransferCharacteristic)
                    peripheral.discoverCharacteristics([transferCharacteristicUUID], forService: service)
                }
            }
        }
    }
    
    /*
     Invoked when you discover the characteristics of a specified service.
     
     If the characteristics of the specified service are successfully discovered, you can access
     them through the service's characteristics property.
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if error != nil {
            print("Error discovering characteristics: \(error?.localizedDescription)")
            return
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                // Transfer Characteristic
                if characteristic.UUID == CBUUID(string: Device.TransferCharacteristic) {
                    // subscribe to dynamic changes
                    peripheral.setNotifyValue(true, forCharacteristic: characteristic)
                }
            }
        }
    }
    
    
    /*
     Invoked when you retrieve a specified characteristic’s value,
     or when the peripheral device notifies your app that the characteristic’s value has changed.
     
     This method is invoked when your app calls the readValueForCharacteristic: method,
     or when the peripheral notifies your app that the value of the characteristic for
     which notifications and indications are enabled has changed.
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("didUpdateValueForCharacteristic: \(NSDate())")
        1
        // if there was an error then print it and bail out
        if error != nil {
            print("Error updating value for characteristic: \(characteristic) - \(error?.localizedDescription)")
            return
        }
        
        // make sure we have a characteristic value
        guard let value = characteristic.value else {
            print("Characteristic Value is nil on this go-round")
            return
        }
        
        print("Bytes transferred: \(value.length)")
        
        // make sure we have a characteristic value
        guard let nextChunk = String(data: value, encoding: NSUTF8StringEncoding) else {
            print("Next chunk of data is nil.")
            return
        }
        
        print("Next chunk: \(nextChunk)")
        
        // If we get the EOM tag, we fill the text view
        if (nextChunk == Device.EOM) {
            if let message = String(data: dataBuffer, encoding: NSUTF8StringEncoding) {
                textView.text = message
                print("Final message: \(message)")
                
                // truncate our buffer now that we received the EOM signal!
                dataBuffer.length = 0
            }
        } else {
            dataBuffer.appendData(value)
            print("Next chunk received: \(nextChunk)")
            if let buffer = self.dataBuffer {
                print("Transfer buffer: \(String(data: buffer, encoding: NSUTF8StringEncoding))")
            }
        }
    }
    
    /*
     Invoked when the peripheral receives a request to start or stop providing notifications 
     for a specified characteristic’s value.
     
     This method is invoked when your app calls the setNotifyValue:forCharacteristic: method.
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        // if there was an error then print it and bail out
        if error != nil {
            print("Error changing notification state: \(error?.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            // notification started
            print("Notification STARTED on characteristic: \(characteristic)")
        } else {
            // notification stopped
            print("Notification STOPPED on characteristic: \(characteristic)")
            self.centralManager.cancelPeripheralConnection(peripheral)
        }

    }


    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
}
