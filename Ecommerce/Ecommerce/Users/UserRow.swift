//
//  UserRow.swift
//  GenericNetworking
//

import SwiftUI
import Networking

struct UserRow: View {
    let user: UserResponse
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.avatar)) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            } placeholder: {
                Color.gray.opacity(0.2)
                    .frame(width: 40, height: 40)
            }
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            RoleTag(role: user.role)
        }
        .padding(.vertical, 4)
        .transitionSource(id: user.id, namespace: namespace)
    }
}

struct RoleTag: View {
    let role: Role

    var body: some View {
        Text(role.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(roleColor.opacity(0.2))
            }
            .foregroundStyle(roleColor)
    }

    private var roleColor: Color {
        switch role {
            case .admin: .primary
            case .seller: .blue
            case .customer: .green
            case .staff: .indigo
        }
    }
}
