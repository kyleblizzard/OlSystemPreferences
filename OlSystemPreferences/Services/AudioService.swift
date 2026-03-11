import Foundation
import CoreAudio

/// Service for reading and writing audio settings via CoreAudio
class AudioService {

    static let shared = AudioService()

    // MARK: - Default Device

    func getDefaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return status == noErr ? deviceID : nil
    }

    func getDefaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return status == noErr ? deviceID : nil
    }

    func setDefaultOutputDevice(_ deviceID: AudioDeviceID) {
        var id = deviceID
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &id)
    }

    func setDefaultInputDevice(_ deviceID: AudioDeviceID) {
        var id = deviceID
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &id)
    }

    // MARK: - Volume

    func getOutputVolume() -> Float? {
        guard let deviceID = getDefaultOutputDeviceID() else { return nil }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Try main element first, then channel 1
        var status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        if status != noErr {
            address.mElement = 1
            status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        }
        return status == noErr ? volume : nil
    }

    func setOutputVolume(_ volume: Float) {
        guard let deviceID = getDefaultOutputDeviceID() else { return }
        var vol = Float32(max(0, min(1, volume)))
        let size = UInt32(MemoryLayout<Float32>.size)

        // Set on both channels (1 and 2) for stereo devices
        for channel: UInt32 in [1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
        }
    }

    // MARK: - Mute

    func isMuted() -> Bool? {
        guard let deviceID = getDefaultOutputDeviceID() else { return nil }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &muted)
        return status == noErr ? muted != 0 : nil
    }

    func setMuted(_ mute: Bool) {
        guard let deviceID = getDefaultOutputDeviceID() else { return }
        var muted: UInt32 = mute ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &muted)
    }

    // MARK: - Device Enumeration

    struct AudioDevice {
        let id: AudioDeviceID
        let name: String
        let hasOutput: Bool
        let hasInput: Bool
    }

    func getAllDevices() -> [AudioDevice] {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        guard status == noErr else { return [] }

        let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs)
        guard status == noErr else { return [] }

        return deviceIDs.compactMap { deviceID -> AudioDevice? in
            guard let name = getDeviceName(deviceID) else { return nil }
            let hasOutput = deviceHasStreams(deviceID, scope: kAudioDevicePropertyScopeOutput)
            let hasInput = deviceHasStreams(deviceID, scope: kAudioDevicePropertyScopeInput)
            guard hasOutput || hasInput else { return nil }
            return AudioDevice(id: deviceID, name: name, hasOutput: hasOutput, hasInput: hasInput)
        }
    }

    func getOutputDevices() -> [AudioDevice] {
        getAllDevices().filter(\.hasOutput)
    }

    func getInputDevices() -> [AudioDevice] {
        getAllDevices().filter(\.hasInput)
    }

    private func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        guard status == noErr, let cfName = name?.takeUnretainedValue() else { return nil }
        return cfName as String
    }

    private func deviceHasStreams(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        return status == noErr && size > 0
    }
}
