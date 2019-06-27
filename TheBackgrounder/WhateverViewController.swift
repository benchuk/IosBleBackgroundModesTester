

import UIKit
import CoreBluetooth

class WhateverViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
  
  var previous = NSDecimalNumber.one
  var current = NSDecimalNumber.one
  var position: UInt = 1
  var updateTimer: Timer?
  var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  
  @IBOutlet var resultsLabel: UILabel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    NotificationCenter.default.addObserver(self, selector: #selector(reinstateBackgroundTask), name: UIApplication.didBecomeActiveNotification, object: nil)
    centralManager = CBCentralManager(delegate: self, queue: .main)
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  @IBAction func didTapPlayPause(_ sender: UIButton) {
    sender.isSelected = !sender.isSelected
    if sender.isSelected {
      resetCalculation()
      updateTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self,
                                         selector: #selector(calculateNextNumber), userInfo: nil, repeats: true)
      // register background task
      registerBackgroundTask()
    } else {
      updateTimer?.invalidate()
      updateTimer = nil
      // end background task
      if backgroundTask != .invalid {
        endBackgroundTask()
      }
    }
  }
  
  var red = 100;
  var green = 80;
  var blue = 60;
  @objc func calculateNextNumber() {
    let result = current.adding(previous)
    
    let bigNumber = NSDecimalNumber(mantissa: 1, exponent: 40, isNegative: false)
    if result.compare(bigNumber) == .orderedAscending {
      previous = current
      current = result
      position += 1
    } else {
      // This is just too much.... Start over.
      resetCalculation()
    }
    
    let resultsMessage = "Position \(position) = \(current)"
    DispatchQueue.global(qos: .background).async {
      DispatchQueue.main.async {
        self.resultsLabel.text = resultsMessage
        self.red+=10
        self.green+=10
        self.blue+=10
        self.view.backgroundColor = .random()
        DispatchQueue.global(qos: .background).async {
          Utils.evaluatePerformance(prefixText: "Capture") {
            if let capture = self.view.captureImage() {
              Utils.evaluatePerformance(prefixText: "Save to gallery") {
                UIImageWriteToSavedPhotosAlbum(capture, nil, nil, nil)
              }
            }
          }
        }
      }
    }
   
    
    switch UIApplication.shared.applicationState {
    case .active:
       print("active")
    case .background:
      print("App is backgrounded. Next number = \(resultsMessage)")
      print("Background time remaining = \(UIApplication.shared.backgroundTimeRemaining) seconds")
    case .inactive:
      break
    }
    
  }
  
  func resetCalculation() {
    previous = .one
    current = .one
    position = 1
  }
  
  func registerBackgroundTask() {
    backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
      self?.endBackgroundTask()
    }
    assert(backgroundTask != .invalid)
  }
  
  func endBackgroundTask() {
    print("Background task ended.")
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }
  
  @objc func reinstateBackgroundTask() {
    if updateTimer != nil && backgroundTask == .invalid {
      registerBackgroundTask()
    }
  }
  
  ///BLE
  var centralManager:CBCentralManager?
  var connectingPeripheral:CBPeripheral?
  
  func centralManagerDidUpdateState(_ central: CBCentralManager!){
    
    switch central.state{
    case .poweredOn:
      print("poweredOn")
      
      let serviceUUIDs:[AnyObject] = [CBUUID(string: "180D")]
      let lastPeripheralsOptional = centralManager?.retrieveConnectedPeripherals(withServices: serviceUUIDs as! [CBUUID])
      
      if let lastPeripherals = lastPeripheralsOptional {
        if lastPeripherals.count > 0{
          let device = lastPeripherals.last as! CBPeripheral;
          connectingPeripheral = device;
           print("connect saved HRM")
          centralManager?.connect(connectingPeripheral! , options: nil)
        }
        else {
          print("scan")
          centralManager?.scanForPeripherals(withServices: serviceUUIDs as! [CBUUID], options: nil)
        }
      }
    default:
      print("ERROR 1")
      print(central.state)
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    print("found HRM on scan")
    connectingPeripheral = peripheral
    connectingPeripheral?.delegate = self
    print("connect HRM after scan")
    centralManager?.connect(connectingPeripheral!, options: nil)
  }
  
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("connected to BLE device")
    print("discover services")
    peripheral.discoverServices(nil)
  }
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    
    print("found services")
    if let actualError = error{
      print("Error 6")
    }
    else {
      for service in peripheral.services as [CBService]!{
        print("discover Characteristics")
        peripheral.discoverCharacteristics(nil, for: service)
      }
    }
  }
  
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    
    print("found Characteristics")
    if let actualError = error{
      
    }
    else {
      
      if service.uuid == CBUUID(string: "180D"){
        for characteristic in service.characteristics as! [CBCharacteristic]{
          switch characteristic.uuid.uuidString{
            
          case "2A37":
            // Set notification on heart rate measurement
            print("Found a Heart Rate Measurement Characteristic")
            print("register notify HRM")
            peripheral.setNotifyValue(true, for: characteristic)
            
          case "2A38":
            // Read body sensor location
            print("Found a Body Sensor Location Characteristic")
            peripheral.readValue(for: characteristic)
            
          case "2A39":
            // Write heart rate control point
            print("Found a Heart Rate Control Point Characteristic")
            
            var rawArray:[UInt8] = [0x01];
            let data = NSData(bytes: &rawArray, length: rawArray.count)
            peripheral.writeValue(data as Data, for: characteristic, type: CBCharacteristicWriteType.withoutResponse)
            
          default:
            print("Error 2")
          }
          
        }
      }
    }
  }
  
  var counter = 0;
  func update(heartRateData:NSData){
    print("HRM handle new value")
    
    counter+=1
    
    
    self.resultsLabel.text = String(counter)
    self.red+=10
    self.green+=10
    self.blue+=10
    self.view.backgroundColor = .random()
    Utils.evaluatePerformance(prefixText: "Capture") {
      if let capture = self.view.captureImage() {
        Utils.evaluatePerformance(prefixText: "Save to gallery") {
          UIImageWriteToSavedPhotosAlbum(capture, nil, nil, nil)
        }
      }
    }
   
    
//    DispatchQueue.global(qos: .background).async {
//      DispatchQueue.main.async {
//        self.resultsLabel.text = resultsMessage
//        self.red+=10
//        self.green+=10
//        self.blue+=10
//        self.view.backgroundColor = .random()
//        DispatchQueue.global(qos: .background).async {
//          Utils.evaluatePerformance(prefixText: "Capture") {
//            if let capture = self.view.captureImage() {
//              Utils.evaluatePerformance(prefixText: "Save to gallery") {
//                UIImageWriteToSavedPhotosAlbum(capture, nil, nil, nil)
//              }
//            }
//          }
//        }
//      }
//    }
    
    var buffer:[UInt8] = [UInt8](repeating: 0x00, count: heartRateData.length)
    heartRateData.getBytes(&buffer, length: buffer.count)
    
    var bpm:UInt16?
    if (buffer.count >= 2){
      if (buffer[0] & 0x01 == 0){
        bpm = UInt16(buffer[1]);
      }else {
        bpm = UInt16(buffer[1]) << 8
        bpm =  bpm! | UInt16(buffer[2])
      }
    }
    
    if let actualBpm = bpm{
      print(actualBpm)
    }else {
      print(bpm)
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    print("didUpdateValueForCharacteristic")
    if let actualError = error{
      print("Error 3")
    }else {
      switch characteristic.uuid.uuidString{
      case "2A37":
        update(heartRateData:characteristic.value as! NSData)
      default:
        print("Error 4")
      }
    }
  }
  
}
