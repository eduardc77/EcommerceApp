import SwiftUI
import Networking

struct UserCard: View {
    let user: UserResponse
    let namespace: Namespace.ID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImage(url: URL(string: user.avatar)) { image in
                image
                    .resizable()
                    .frame(minWidth: 150, maxWidth: .infinity)
                    .frame(height: 150)
                    .scaledToFit()
            } placeholder: {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                    }
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            }
            .clipShape(.rect(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(user.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    RoleTag(role: user.role)
                }
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .frame(height: 220)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.1))
        }
        .transitionSource(id: user.id, namespace: namespace)
    }
} 
