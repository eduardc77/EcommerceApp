import SwiftUI
import Networking

struct HomeView: View {
    @Environment(CategoryManager.self) private var categoryManager
    @Environment(ProductManager.self) private var productManager
    @Namespace private var namespace
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !categoryManager.categories.isEmpty {
                        featuredSection

                        SectionHeader(title: "Browse Categories")
                        categoriesSection
                    }
                    SectionHeader(title: "Latest Products")
                    productsSection

                    SectionHeader(title: "Popular Now")
                    popularNowSection
                }
                .padding(.vertical)
            }
            .navigationTitle("Store")
            .withAccountButton()
            .navigationDestination(for: CategoryResponse.self) { category in
                ProductsListView(category: category, namespace: namespace)
            }
            .navigationDestination(for: ProductResponse.self) { product in
                ProductDetailView(
                    product: product,
                    namespace: namespace
                )
            }
            .task {
                await categoryManager.loadCategories()
                await productManager.loadProducts()
            }
        }
    }

    var featuredSection: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 16) {
                ForEach(categoryManager.categories.prefix(3)) { category in
                    NavigationLink(value: category) {
                        FeaturedCard(category: category)
                    }
                    .buttonStyle(.plain)
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollIndicators(.hidden)
    }

    var categoriesSection: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                ForEach(categoryManager.categories) { category in
                    NavigationLink(value: category) {
                        CategoryCard(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByFew))
        .scrollIndicators(.hidden)
    }

    var productsSection: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 16) {
                ForEach(productManager.products) { product in
                    NavigationLink(value: product) {
                        ProductCard(
                            product: product,
                            namespace: namespace
                        )
                        .frame(width: 180)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByFew))
        .scrollIndicators(.hidden)
    }

    var popularNowSection: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 16) {
                ForEach(productManager.products.shuffled().prefix(5)) { product in
                    NavigationLink(value: product) {
                        ProductCard(
                            product: product,
                            namespace: namespace
                        )
                        .frame(width: 180)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByFew))
        .scrollIndicators(.hidden)
    }
}

struct FeaturedCard: View {
    let category: CategoryResponse

    var body: some View {
        AsyncImage(url: URL(string: category.image)) { image in
            image
                .resizable()
                .frame(width: 300, height: 200)
                .scaledToFit()
        } placeholder: {
            Rectangle()
                .fill(.quaternary)
                .frame(width: 300, height: 200)
        }
        .overlay(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Featured")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(category.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(category.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background {
                LinearGradient(
                    colors: [
                        .black.opacity(0.8),
                        .black.opacity(0.4),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            }
        }
    }
}

struct CategoryCard: View {
    let category: CategoryResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            AsyncImage(url: URL(string: category.image)) { image in
                image
                    .resizable()
                    .frame(width: 120, height: 80)
                    .scaledToFit()
            } placeholder: {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 120, height: 80)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 0) {
                Text(category.name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(category.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
            .padding(.horizontal)
    }
}
