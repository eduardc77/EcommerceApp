import Observation
import Networking

@Observable
public final class UserManager {
    private let userService: UserServiceProtocol
    
    public var users: [UserResponse] = []
    public var isLoading = false
    public var error: Error?
    
    public init(userService: UserServiceProtocol) {
        self.userService = userService
    }
    
    public func loadUsers() async {
        isLoading = true
        error = nil
        do {
            users = try await userService.getAllUsers()
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    public func getUser(id: String) async -> UserResponse? {
        isLoading = true
        error = nil
        do {
            let user = try await userService.getUser(id: id)
            isLoading = false
            return user
        } catch {
            self.error = error
            isLoading = false
            return nil
        }
    }
    
    public func getUserPublic(id: String) async -> PublicUserResponse? {
        isLoading = true
        error = nil
        do {
            let user = try await userService.getUserPublic(id: id)
            isLoading = false
            return user
        } catch {
            self.error = error
            isLoading = false
            return nil
        }
    }
    
    public func createUser(username: String, displayName: String, email: String, password: String, role: Role = .customer) async {
        isLoading = true
        error = nil
        do {
            let dto = AdminCreateUserRequest(
                username: username,
                displayName: displayName,
                email: email,
                password: password,
                role: role
            )
            let newUser = try await userService.createUser(dto)
            users.append(newUser)
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    public func updateUser(id: String, displayName: String, email: String? = nil) async {
        isLoading = true
        error = nil
        do {
            let dto = UpdateUserRequest(displayName: displayName, email: email)
            let updatedUser = try await userService.updateProfile(id: id, dto: dto)
            if let index = users.firstIndex(where: { $0.id == id }) {
                users[index] = updatedUser
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    public func updateUserRole(userId: String, role: Role) async {
        isLoading = true
        error = nil
        do {
            let request = UpdateRoleRequest(role: role)
            let updatedUser = try await userService.updateRole(userId: userId, request: request)
            if let index = users.firstIndex(where: { $0.id == userId }) {
                users[index] = updatedUser
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    /// Check if a username is available
    public func checkUsernameAvailability(_ username: String) async -> Bool {
        isLoading = true
        error = nil
        do {
            let response = try await userService.checkAvailability(.username(username))
            isLoading = false
            return response.available
        } catch {
            self.error = error
            isLoading = false
            return false
        }
    }
    
    /// Check if an email is available
    public func checkEmailAvailability(_ email: String) async -> Bool {
        isLoading = true
        error = nil
        do {
            let response = try await userService.checkAvailability(.email(email))
            isLoading = false
            return response.available
        } catch {
            self.error = error
            isLoading = false
            return false
        }
    }
    
    /// Delete a user
    public func deleteUser(id: String) async -> Bool {
        isLoading = true
        error = nil
        do {
            _ = try await userService.deleteUser(id: id)
            users.removeAll { $0.id == id }
            isLoading = false
            return true
        } catch {
            self.error = error
            isLoading = false
            return false
        }
    }
}
