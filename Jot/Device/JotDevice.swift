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
    static let resendID = CBUUID(string: "6e0b7c52-2f6a-4d0e-9b8c-3f1d5a7e9c41")
    private static let enabledKey = "JotDeviceEnabled"

    private(set) var status: Status = .off
    /// What happened to the last clip, for the Develop screen.
    private(set) var lastClip: String?
    /// The most audio bytes one notification can carry on this connection.
    private(set) var packetLimit: Int?

    private let source = BLEAudioSource()
    private let capture: CaptureController
    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var assembler = ClipAssembler()
    @ObservationIgnored private var clipStartedAt: Date?
    @ObservationIgnored private var largestPacket = 0
    @ObservationIgnored private var resendCharacteristic: CBCharacteristic?
    /// Asks again if a clip goes quiet before it's complete (a lost END).
    @ObservationIgnored private var stallTask: Task<Void, Never>?

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
        resendCharacteristic = nil
        stallTask?.cancel()
        assembler = ClipAssembler()
        status = .off
        packetLimit = nil
        capture.failDeviceCapture(source)
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
        if !assembler.isActive {
            clipStartedAt = .now
            largestPacket = 0
        }
        largestPacket = max(largestPacket, packet.count)
        handle(assembler.receive(packet))
        watchForStall()
    }

    private func handle(_ event: ClipAssembler.Event?) {
        switch event {
        case .started, nil:
            break
        case .resend(let packets):
            guard let peripheral, let resendCharacteristic else { return }
            peripheral.writeValue(ClipAssembler.resendRequest(packets), for: resendCharacteristic, type: .withResponse)
        case .finished(let adpcm, let sampleRate):
            stallTask?.cancel()
            let samples = IMAADPCM.decode(adpcm)
            let seconds = Double(samples.count) / Double(max(sampleRate, 1))
            let ms = Int((clipStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0) * 1000)
            lastClip = String(
                format: "%.1f s of audio, %d bytes in %d ms, %d resend rounds",
                seconds, adpcm.count, ms, assembler.rounds
            )
            source.deliver(samples, sampleRate: sampleRate)
            capture.endDeviceCapture(source)
        case .failed(let reason):
            stallTask?.cancel()
            lastClip = "Clip failed: \(reason). Largest packet \(largestPacket) bytes."
            capture.failDeviceCapture(source)
        }
    }

    private func watchForStall() {
        stallTask?.cancel()
        guard assembler.isActive else { return }
        stallTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, !Task.isCancelled else { return }
            self.handle(self.assembler.stalled())
            self.watchForStall()
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
        packetLimit = nil
        resendCharacteristic = nil
        stallTask?.cancel()
        assembler = ClipAssembler()
        capture.failDeviceCapture(source)
        scan()
    }
}

extension JotDevice: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceID }) else { return }
        peripheral.discoverCharacteristics([Self.buttonID, Self.audioID, Self.resendID], for: service)
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
        resendCharacteristic = characteristics.first { $0.uuid == Self.resendID }
        if characteristics.contains(where: { $0.uuid == Self.audioID }), resendCharacteristic != nil {
            packetLimit = peripheral.maximumWriteValueLength(for: .withoutResponse)
            status = .connected
        } else {
            status = .unavailable("This Jot's firmware doesn't send audio. Upload the latest jot_v1_clip.")
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
