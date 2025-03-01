import SwiftUI
import Networking

struct UsersView: View {
    @Environment(UserManager.self) private var userManager
    @Namespace private var namespace
    @State private var viewMode: ViewMode = .grid
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Group {
                    switch viewMode {
                    case .grid:
                        usersGrid
                    case .list:
                        usersList
                    }
                }
                .searchable(text: $searchText, prompt: "Search users")
                
                if userManager.isLoading {
                    ProgressView()
                } else if userManager.users.isEmpty {
                    emptyContentView
                }
            }
            .navigationTitle("Users")
            .withAccountButton()
            .navigationDestination(for: UserResponse.self) { user in
                UserDetailView(user: user, canEdit: true, namespace: namespace)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            withAnimation {
                                viewMode = viewMode == .grid ? .list : .grid
                            }
                        } label: {
                            Label(
                                viewMode == .grid ? "List View" : "Grid View",
                                systemImage: viewMode == .grid ? "list.bullet" : "square.grid.2x2"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                await userManager.loadUsers()
            }
            .refreshable {
                await userManager.loadUsers()
            }
        }
    }
    
    private var usersGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(userManager.users) { user in
                    NavigationLink(value: user) {
                        UserCard(user: user, namespace: namespace)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    private var usersList: some View {
        List {
            ForEach(userManager.users) { user in
                NavigationLink(value: user) {
                    UserRow(user: user, namespace: namespace)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }
    
    private var emptyContentView: some View {
        ContentUnavailableView {
            Label("No Users", systemImage: "person.2")
        } description: {
            if !searchText.isEmpty {
                Text("No users match your search")
            } else {
                Text("No users available")
            }
        }
    }
}

private extension UsersView {
    enum ViewMode {
        case grid
        case list
    }
}
