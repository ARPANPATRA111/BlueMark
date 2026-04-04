import Flutter
import UIKit
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CBPeripheralManagerDelegate {
  private var peripheralManager: CBPeripheralManager?
  private var pendingAdvertisementData: [String: Any]?
  private var advertiseState: String = "stopped"
  private var isAdvertising: Bool = false
  private var advertiseError: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let registrar = self.registrar(forPlugin: "AttendanceBleAdvertiser") {
      let channel = FlutterMethodChannel(name: "attendance_ble_advertiser", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, methodResult in
        guard let self = self else {
          methodResult(FlutterError(code: "deallocated", message: "AppDelegate unavailable", details: nil))
          return
        }

        switch call.method {
        case "startAdvertising":
          guard let args = call.arguments as? [String: Any],
                let rollNumber = args["rollNumber"] as? String,
                let serviceUuid = args["serviceUuid"] as? String
          else {
            methodResult(FlutterError(code: "invalid_args", message: "rollNumber and serviceUuid are required", details: nil))
            return
          }

          let manufacturerId = (args["manufacturerId"] as? Int) ?? 0x0A77
          let payloadList = (args["payload"] as? [Int]) ?? []

          self.startAdvertising(
            rollNumber: rollNumber,
            serviceUuid: serviceUuid,
            manufacturerId: manufacturerId,
            payloadList: payloadList
          )
          methodResult(true)

        case "stopAdvertising":
          self.stopAdvertising()
          methodResult(true)

        case "getAdvertisingStatus":
          methodResult([
            "isAdvertising": self.isAdvertising,
            "state": self.advertiseState,
            "lastError": self.advertiseError as Any,
          ])

        default:
          methodResult(FlutterMethodNotImplemented)
        }
      }
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func startAdvertising(
    rollNumber: String,
    serviceUuid: String,
    manufacturerId: Int,
    payloadList: [Int]
  ) {
    advertiseState = "starting"
    isAdvertising = false
    advertiseError = nil

    let payloadData: Data
    if payloadList.isEmpty {
      payloadData = Data("BAT:\(rollNumber.uppercased())".utf8)
    } else {
      payloadData = Data(payloadList.map { UInt8(truncatingIfNeeded: $0) })
    }

    var manufacturerData = Data()
    manufacturerData.append(UInt8(manufacturerId & 0xFF))
    manufacturerData.append(UInt8((manufacturerId >> 8) & 0xFF))
    manufacturerData.append(payloadData)

    let payload: [String: Any] = [
      CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: serviceUuid)],
      CBAdvertisementDataManufacturerDataKey: manufacturerData,
    ]

    pendingAdvertisementData = payload

    if peripheralManager == nil {
      peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [
        CBPeripheralManagerOptionShowPowerAlertKey: true,
      ])
      return
    }

    if peripheralManager?.state == .poweredOn {
      peripheralManager?.stopAdvertising()
      peripheralManager?.startAdvertising(payload)
    } else {
      advertiseState = "waiting_bluetooth"
      advertiseError = "Bluetooth is not powered on"
    }
  }

  private func stopAdvertising() {
    peripheralManager?.stopAdvertising()
    pendingAdvertisementData = nil
    isAdvertising = false
    advertiseState = "stopped"
    advertiseError = nil
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    if peripheral.state == .poweredOn, let payload = pendingAdvertisementData {
      peripheral.stopAdvertising()
      peripheral.startAdvertising(payload)
    } else if peripheral.state != .poweredOn {
      isAdvertising = false
      advertiseState = "waiting_bluetooth"
      advertiseError = "Bluetooth is not powered on"
    }
  }

  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    if let error = error {
      isAdvertising = false
      advertiseState = "error"
      advertiseError = error.localizedDescription
      return
    }

    isAdvertising = true
    advertiseState = "active"
    advertiseError = nil
  }
}
