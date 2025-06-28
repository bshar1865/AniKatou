import Foundation

@MainActor
class AniListAuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userLibrary: [AniListLibraryItem] = []
    @Published var selectedStatus: AniListStatus? = nil
    @Published var userProfile: AniListUserProfile?
    
    private let authService = AniListAuthService.shared
    
    init() {
        isAuthenticated = authService.isAuthenticated
        if isAuthenticated {
            Task {
                await loadUserProfile()
                await loadUserLibrary()
            }
        }
    }
    
    func authenticate(code: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let success = try await authService.authenticate(code: code)
            if success {
                isAuthenticated = true
                await loadUserLibrary()
            } else {
                errorMessage = "Authentication failed"
            }
            isLoading = false
            return success
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func storeAccessToken(_ accessToken: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let success = try await authService.storeAccessToken(accessToken)
            if success {
                isAuthenticated = true
                await loadUserProfile()
                await loadUserLibrary()
            } else {
                errorMessage = "Failed to store access token"
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func logout() {
        authService.logout()
        isAuthenticated = false
        userLibrary = []
        selectedStatus = nil
    }
    
    func loadUserLibrary() async {
        guard isAuthenticated else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            userLibrary = try await authService.getUserLibrary(status: selectedStatus)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func filterByStatus(_ status: AniListStatus?) {
        selectedStatus = status
        Task {
            await loadUserLibrary()
        }
    }
    
    func getLibraryForStatus(_ status: AniListStatus) -> [AniListLibraryItem] {
        return userLibrary.filter { $0.status == status }
    }
    
    func getWatchingList() -> [AniListLibraryItem] {
        return getLibraryForStatus(.current)
    }
    
    func getPlanToWatchList() -> [AniListLibraryItem] {
        return getLibraryForStatus(.planning)
    }
    
    func getCompletedList() -> [AniListLibraryItem] {
        return getLibraryForStatus(.completed)
    }
    
    func loadUserProfile() async {
        guard isAuthenticated else { return }
        
        do {
            userProfile = try await authService.getUserProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
} 