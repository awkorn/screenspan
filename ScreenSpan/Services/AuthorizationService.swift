import Foundation
import DeviceActivity
import FamilyControls

/// Service for managing DeviceActivity authorization
@MainActor
class AuthorizationService: ObservableObject {
    @Published var isAuthorized = false

    /// Request DeviceActivity authorization from the user
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            print("Failed to request authorization: \(error)")
            isAuthorized = false
        }
    }
}
