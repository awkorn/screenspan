import Foundation
import DeviceActivity
import FamilyControls
import Combine

/// Service for managing DeviceActivity authorization
@MainActor
class AuthorizationService: ObservableObject {
    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published private(set) var isAuthorized: Bool
    @Published private(set) var authorizationErrorMessage: String?

    private let authorizationCenter: AuthorizationCenter
    private var authorizationStatusObservation: AnyCancellable?

    init(authorizationCenter: AuthorizationCenter = .shared) {
        self.authorizationCenter = authorizationCenter
        let currentStatus = authorizationCenter.authorizationStatus
        self.authorizationStatus = currentStatus
        self.isAuthorized = currentStatus == .approved
        self.authorizationStatusObservation = authorizationCenter.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.authorizationStatus = status
                self?.isAuthorized = status == .approved

                if status == .approved {
                    self?.authorizationErrorMessage = nil
                }
            }
    }

    /// Refresh the in-memory authorization state from the current system value.
    func refreshAuthorizationStatus() {
        let currentStatus = authorizationCenter.authorizationStatus
        authorizationStatus = currentStatus
        isAuthorized = currentStatus == .approved

        if currentStatus == .approved {
            authorizationErrorMessage = nil
        }
    }

    /// Request DeviceActivity authorization from the user
    func requestAuthorization() async {
        authorizationErrorMessage = nil

        do {
            try await authorizationCenter.requestAuthorization(for: .individual)
            refreshAuthorizationStatus()
        } catch let error as FamilyControlsError {
            authorizationErrorMessage = Self.message(for: error)
            print("Failed to request authorization: \(error)")
        } catch {
            authorizationErrorMessage = error.localizedDescription
            print("Failed to request authorization: \(error)")
        }
        
        refreshAuthorizationStatus()
    }

    private static func message(for error: FamilyControlsError) -> String {
        switch error {
        case .authorizationCanceled:
            return "Screen Time access was canceled before it finished."
        case .authenticationMethodUnavailable:
            return "Set a device passcode and enable Face ID or Touch ID, then try Screen Time access again."
        case .authorizationConflict:
            return "Another parental controls app is already authorized on this iPhone. Remove that authorization first, then try again."
        case .invalidAccountType:
            return "This iPhone is not signed into a valid iCloud account for Screen Time access."
        case .networkError:
            return "Connect this iPhone to the internet, then try Screen Time access again."
        case .restricted:
            return "Screen Time access is restricted on this iPhone. Check Screen Time restrictions in Settings."
        case .unavailable:
            return "Screen Time is unavailable for this build right now. Reinstall after adding the Family Controls capability to the app and its Screen Time extension."
        case .invalidArgument:
            return "The Screen Time request was rejected because of an invalid authorization configuration."
        @unknown default:
            return "Screen Time access failed for an unknown reason. Please try again."
        }
    }
}
