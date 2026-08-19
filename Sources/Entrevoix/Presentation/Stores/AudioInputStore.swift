import EntrevoixCore
import Observation

@MainActor
@Observable
final class AudioInputStore {
    private let preferencesStore: PreferencesStore
    private let deviceCatalog: any AudioInputDeviceDiscovering

    private(set) var snapshot = AudioInputDeviceSnapshot(devices: [], defaultDeviceUID: nil)

    init(
        preferencesStore: PreferencesStore,
        deviceCatalog: any AudioInputDeviceDiscovering
    ) {
        self.preferencesStore = preferencesStore
        self.deviceCatalog = deviceCatalog
        deviceCatalog.onInputDevicesChanged = { [weak self] in
            self?.refresh()
        }
        refresh()
    }

    var selection: AudioInputSelection { preferencesStore.preferences.audioInputSelection }

    var devices: [AudioInputDeviceReference] {
        snapshot.devices.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    var defaultDevice: AudioInputDeviceReference? {
        guard let uid = snapshot.defaultDeviceUID else { return nil }
        return snapshot.devices.first { $0.uid == uid }
    }

    var unavailableSelection: AudioInputDeviceReference? {
        guard case .device(let device) = selection,
              !snapshot.devices.contains(where: { $0.uid == device.uid }) else { return nil }
        return device
    }

    func setSelection(_ selection: AudioInputSelection) {
        guard preferencesStore.preferences.audioInputSelection != selection else { return }
        var preferences = preferencesStore.preferences
        preferences.audioInputSelection = selection
        preferencesStore.update(preferences, to: .immediate)
    }

    func refresh() {
        snapshot = deviceCatalog.snapshot()
        guard case .device(let selected) = preferencesStore.preferences.audioInputSelection,
              let currentDevice = snapshot.devices.first(where: { $0.uid == selected.uid }),
              currentDevice.name != selected.name else { return }
        var preferences = preferencesStore.preferences
        preferences.audioInputSelection = .device(currentDevice)
        preferencesStore.update(preferences, to: .immediate)
    }
}
