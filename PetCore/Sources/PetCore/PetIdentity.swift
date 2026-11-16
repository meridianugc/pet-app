import Foundation

/// Identifiers shared by the app and the widget.
///
/// `appGroupID` must match the App Group in both entitlements files.
/// Bundle ids live in `project.yml`. See the README section "Change the bundle id".
public enum PetIdentity {
    public static let appGroupID = "group.com.example.petapp"
    public static let recordFileName = "pet-record.json"
}
