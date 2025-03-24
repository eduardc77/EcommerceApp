@testable import App
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import Testing
import HTTPTypes
import FluentKit

@Suite("Role-Based Access Control Tests")
struct RoleBasedAccessTests {
    
    @Test("Different roles have appropriate permissions")
    func testRolePermissions() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Testing role permissions
            let admin = Role.admin
            let staff = Role.staff
            let seller = Role.seller
            let customer = Role.customer
            
            // Check admin permissions
            #expect(admin.isAdmin)
            #expect(admin.permissions.contains(.manageRoles))
            #expect(admin.permissions.contains(.manageAllProducts))
            #expect(admin.permissions.contains(.manageUsers))
            #expect(admin.canProcessOrders)
            
            // Check staff permissions
            #expect(!staff.isAdmin)
            #expect(!staff.permissions.contains(.manageRoles))
            #expect(staff.permissions.contains(.manageAllProducts))
            #expect(staff.permissions.contains(.manageUsers))
            #expect(staff.canProcessOrders)
            
            // Check seller permissions
            #expect(!seller.isAdmin)
            #expect(!seller.permissions.contains(.manageRoles))
            #expect(!seller.permissions.contains(.manageAllProducts))
            #expect(seller.permissions.contains(.manageOwnProducts))
            #expect(!seller.permissions.contains(.manageUsers))
            #expect(seller.canProcessOrders)
            
            // Check customer permissions
            #expect(!customer.isAdmin)
            #expect(!customer.permissions.contains(.manageRoles))
            #expect(!customer.permissions.contains(.manageAllProducts))
            #expect(!customer.permissions.contains(.manageOwnProducts))
            #expect(!customer.permissions.contains(.manageUsers))
            #expect(!customer.canProcessOrders)
        }
    }
    
    @Test("Only admin can create staff accounts")
    func testAdminCanCreateStaffAccounts() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create admin user
            let admin = TestCreateUserRequest(
                username: "admin_role_test", 
                displayName: "Admin Role Test", 
                email: "admin_roles@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register admin
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(admin, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: admin.email)
            
            // Login to get token
            let adminAuth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: admin.email, password: admin.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let adminUserId = adminAuth.user!.id
            
            // Set admin role directly in the database
            try await client.setUserRole(app: app, email: admin.email, role: .admin)
            
            // 2. Admin creates a staff user
            let staff = TestCreateUserRequest(
                username: "staff_user", 
                displayName: "Staff User", 
                email: "staff@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register staff
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(staff, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: staff.email)
            
            // Login to get ID
            let staffAuth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: staff.email, password: staff.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let staffUserId = staffAuth.user!.id
            
            // 3. Admin creates a seller user
            let seller = TestCreateUserRequest(
                username: "seller_user", 
                displayName: "Seller User", 
                email: "seller@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register seller
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(seller, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: seller.email)
            
            // Login to get ID
            let sellerAuth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: seller.email, password: seller.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let sellerUserId = sellerAuth.user!.id
            
            // 4. Admin promotes users to respective roles
            // Set staff role
            try await client.execute(
                uri: "/api/v1/users/\(staffUserId)/role",
                method: .put,
                auth: .bearer(adminAuth.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(["role": "staff"], allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // Set seller role
            try await client.execute(
                uri: "/api/v1/users/\(sellerUserId)/role",
                method: .put,
                auth: .bearer(adminAuth.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(["role": "seller"], allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // 5. Seller tries to promote a customer to staff (should fail)
            let customer = TestCreateUserRequest(
                username: "customer_user", 
                displayName: "Customer User", 
                email: "customer_roles@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register customer
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(customer, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: customer.email)
            
            // Login to get ID
            let customerAuth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: customer.email, password: customer.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let customerUserId = customerAuth.user!.id
            
            // Seller tries to promote customer to staff (should fail)
            try await client.execute(
                uri: "/api/v1/users/\(customerUserId)/role",
                method: .put,
                auth: .bearer(sellerAuth.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(["role": "staff"], allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }
    
    @Test("Staff can update customer and seller roles only")
    func testStaffRoleUpdatePermissions() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create staff user
            let staff = TestCreateUserRequest(
                username: "staff_role_test", 
                displayName: "Staff Role Test", 
                email: "staff@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register staff
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(staff, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: staff.email)
            
            // Login to get token
            let staffAuth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: staff.email, password: staff.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let staffUserId = staffAuth.user!.id
            
            // 2. Create admin user
            let admin = TestCreateUserRequest(
                username: "admin_user", 
                displayName: "Admin User", 
                email: "admin@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register admin
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(admin, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: admin.email)
            
            // Login to get ID
            let adminAuth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: admin.email, password: admin.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let adminUserId = adminAuth.user!.id
            
            // Set admin role directly
            try await client.setUserRole(app: app, email: admin.email, role: .admin)
            
            // Set staff role directly
            try await client.setUserRole(app: app, email: staff.email, role: .staff)
            
            // 4. Create a customer to promote
            let customer = TestCreateUserRequest(
                username: "customer_to_promote", 
                displayName: "Customer User", 
                email: "customer_promote@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register customer
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(customer, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: customer.email)
            
            // Login to get ID
            let customerAuth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: customer.email, password: customer.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let customerUserId = customerAuth.user!.id
            
            // 5. Staff tries to update admin role (should fail)
            let adminRoleRequest = ["role": "staff"]
            try await client.execute(
                uri: "/api/v1/users/\(adminUserId)/role",
                method: .put,
                auth: .bearer(staffAuth.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(adminRoleRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .forbidden)
            }
            
            // 6. Staff tries to set a user to admin role (should fail)
            let makeAdminRequest = ["role": "admin"]
            try await client.execute(
                uri: "/api/v1/users/\(customerUserId)/role",
                method: .put,
                auth: .bearer(staffAuth.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(makeAdminRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }
    
    @Test("Regular users cannot access admin endpoints")
    func testRegularUserCannotAccessAdminEndpoints() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create regular user
            let regularUser = TestCreateUserRequest(
                username: "regular_access_test",
                displayName: "Regular Access Test",
                email: "regular_access@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register regular user
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(regularUser, allocator: ByteBufferAllocator())
            ) { createResponse in
                #expect(createResponse.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: regularUser.email)
            
            // Login to get token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: regularUser.email, password: regularUser.password)
            ) { signInResponse in
                #expect(signInResponse.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: signInResponse.body)
            }
            
            // 2. Try to access all users endpoint (admin only)
            try await client.execute(
                uri: "/api/v1/users",
                method: .get,
                auth: .bearer(authResponse.accessToken!)
            ) { adminEndpointResponse in
                #expect(adminEndpointResponse.status == .notFound)
            }
            
            // 3. Create another user to test role update
            let otherUser = TestCreateUserRequest(
                username: "other_access_test",
                displayName: "Other Access Test",
                email: "other_access@example.com",
                password: "TestingV@lid143!#", 
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register other user
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(otherUser, allocator: ByteBufferAllocator())
            ) { otherCreateResponse in
                #expect(otherCreateResponse.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: otherUser.email)
            
            // Login to get ID
            let otherAuthResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: otherUser.email, password: otherUser.password)
            ) { otherSignInResponse in
                #expect(otherSignInResponse.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: otherSignInResponse.body)
            }
            
            let otherUserId = otherAuthResponse.user!.id
            
            // 4. Try to update other user's role (admin/staff only)
            let roleUpdateRequest = ["role": "seller"]
            try await client.execute(
                uri: "/api/v1/users/\(otherUserId)/role",
                method: .put,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(roleUpdateRequest, allocator: ByteBufferAllocator())
            ) { roleUpdateResponse in
                #expect(roleUpdateResponse.status == .forbidden)
            }
        }
    }
}

// MARK: - Test Utility Extension
extension TestClientProtocol {
    /// Updates a user's role through the API
    /// - Parameters:
    ///   - userId: The ID of the user
    ///   - role: The role to set
    ///   - authToken: The auth token to use for the request
    /// - Throws: If the request fails
    func updateUserRole(userId: String, role: String, authToken: String) async throws {
        try await self.execute(
            uri: "/api/v1/users/\(userId)/role",
            method: .put,
            auth: .bearer(authToken),
            body: JSONEncoder().encodeAsByteBuffer(["role": role], allocator: ByteBufferAllocator())
        ) { response in
            guard response.status == .ok else {
                let error = try? JSONDecoder().decode(ErrorResponse.self, from: response.body)
                throw HTTPError(.internalServerError, message: error?.error.message ?? "Failed to update role")
            }
        }
    }
} 