@preconcurrency import CoreBluetooth
import Foundation
import Observation

/// Connects to a Jot over Bluetooth. A press on its button starts a capture;
/// the clip it sends on release finishes it.
@MainActor
@Observable
final class JotDevice: NSObject {
    enum Status: Equatable {
        case off
        case unavailable(String)
        case searching
        case connecting
        case connected
    }

    // The Jot BLE service and characteristics (see Firmware/V1/jot_v1_clip).
    static let serviceID = CBUUID(string: "a5bc1576-7c64-4efe-9c40-2b39fdf53bed")
    static let buttonID = CBUUID(string: "15619899-b8cd-4254-97ff-0c757fa68b3d")
    static let audioID = CBUUID(string: "18d71983-6ed1-441e-bdd3-80fe9e1b1529")
    private static let enabledKey = "JotDeviceEnabled"

    private(set) var status: Status = .off
    /// What happened to the last clip, for the Develop screen.
    private(set) var lastClip: String?

    private let source = BLEAudioSource()
    private let capture: CaptureController
    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var assembler = ClipAssembler()
    @ObservationIgnored private var clipStartedAt: Date?

    var isEnabled: Bool { status != .off }

    init(capture: CaptureController) {
        self.capture = capture
        super.init()
        // Bluetooth is only asked for once Jot hardware is turned on.
        if UserDefaults.standard.bool(forKey: Self.enabledKey) { enable() }
    }

    func enable() {
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        guard central == nil else { return }
        status = .searching
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func disable() {
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        central?.stopScan()
        central = nil
        peripheral = nil
        assembler = ClipAssembler()
        status = .off
        capture.endDeviceCapture(source)
    }

    private func scan() {
        guard let central, central.state == .poweredOn else { return }
        // A Jot iOS is already connected to (from another app) doesn't advertise.
        if let known = central.retrieveConnectedPeripherals(withServices: [Self.serviceID]).first {
            connect(known)
            return
        }
        status = .searching
        central.scanForPeripherals(withServices: [Self.serviceID])
    }

    private func connect(_ peripheral: CBPeripheral) {
        central?.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        status = .connecting
        central?.connect(peripheral)
    }

    private func handleButton(_ value: Data) {
        // Release is ignored: the clip arriving is what ends the capture.
        guard value.first == 1 else { return }
        capture.beginDeviceCapture(from: source)
    }

    private func handleAudio(_ packet: Data) {
        switch assembler.receive(packet) {
        case .started:
            clipStartedAt = .now
        case .finished(let adpcm, let sampleRate):
            let samples = IMAADPCM.decode(adpcm)
            let seconds = Double(samples.count) / Double(max(sampleRate, 1))
            let ms = Int((clipStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0) * 1000)
            lastClip = String(format: "%.1f s of audio, %d bytes in %d ms", seconds, adpcm.count, ms)
            source.deliver(samples, sampleRate: sampleRate)
            capture.endDeviceCapture(source)
        case .failed(let reason):
            lastClip = "Clip failed: \(reason)"
            capture.endDeviceCapture(source)
        case nil:
            break
        }
    }
}

extension JotDevice: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: scan()
        case .poweredOff: status = .unavailable("Bluetooth is off.")
        case .unauthorized: status = .unavailable("Turn on Bluetooth for Jot in Settings.")
        case .unsupported: status = .unavailable("This device doesn't support Bluetooth LE.")
        default: break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.serviceID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        self.peripheral = nil
        scan()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        self.peripheral = nil
        assembler = ClipAssembler()
        capture.endDeviceCapture(source)
        scan()
    }
}

extension JotDevice: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceID }) else { return }
        peripheral.discoverCharacteristics([Self.buttonID, Self.audioID], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        let characteristics = service.characteristics ?? []
        for characteristic in characteristics where characteristic.uuid == Self.buttonID || characteristic.uuid == Self.audioID {
            peripheral.setNotifyValue(true, for: characteristic)
        }
        if characteristics.contains(where: { $0.uuid == Self.audioID }) {
            status = .connected
        } else {
            status = .unavailable("This Jot's firmware doesn't send audio. Upload jot_v1_clip.")
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard error == nil, let value = characteristic.value else { return }
        if characteristic.uuid == Self.buttonID {
            handleButton(value)
        } else if characteristic.uuid == Self.audioID {
            handleAudio(value)
        }
    }
}
