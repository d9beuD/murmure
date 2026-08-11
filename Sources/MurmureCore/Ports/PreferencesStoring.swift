import Foundation

public protocol PreferencesStoring: AnyObject {
    var preferences: AppPreferences { get }
    func save(_ preferences: AppPreferences)
    func reset()
}
