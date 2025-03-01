import SwiftUI
import Networking

struct AddProductView: View {
    @Environment(ProductManager.self) private var productManager
    @Environment(CategoryManager.self) private var categoryManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var price = 0.0
    @State private var description = ""
    @State private var selectedCategoryId: String?
    @State private var imageURLs: [String] = [""]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Product Details") {
                    TextField("Name", text: $title)
                    TextField("Price", value: $price, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategoryId) {
                        ForEach(categoryManager.categories) { category in
                            Text(category.name)
                                .tag(Optional(category.id))
                        }
                    }
                }
                
                Section("Images") {
                    ForEach(imageURLs.indices, id: \.self) { index in
                        HStack {
                            TextField("Image URL", text: $imageURLs[index])
                                .keyboardType(.URL)
                                .textContentType(.URL)
                                .autocorrectionDisabled()
                            
                            if imageURLs.count > 1 {
                                Button(role: .destructive) {
                                    imageURLs.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    
                    Button {
                        imageURLs.append("")
                    } label: {
                        Label("Add Image", systemImage: "plus.circle")
                    }
                }
                
                Section("Preview") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(imageURLs, id: \.self) { urlString in
                                if let url = URL(string: urlString), !urlString.isEmpty {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                            .frame(width: 200, height: 200)
                                            .scaledToFit()
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                            .frame(width: 200, height: 200)
                                            .overlay {
                                                Image(systemName: "photo")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 100)
                                                    .foregroundStyle(.white)
                                            }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: addProduct)
                        .disabled(!isValid)
                }
            }
            .overlay {
                if productManager.isLoading {
                    ProgressView()
                }
            }
            .task {
                await categoryManager.loadCategories()
                if selectedCategoryId == nil {
                    selectedCategoryId = categoryManager.categories.first?.id
                }
            }
        }
    }
    
    private var isValid: Bool {
        !title.isEmpty &&
        !description.isEmpty &&
        price > 0 &&
        !imageURLs.filter { !$0.isEmpty }.isEmpty &&
        imageURLs.filter { !$0.isEmpty }.allSatisfy { URL(string: $0) != nil } &&
        selectedCategoryId != nil
    }
    
    private func addProduct() {
        let validImages = imageURLs.filter { !$0.isEmpty }
        
        let dto = CreateProductRequest(
            title: title,
            description: description,
            price: price,
            images: validImages,
            categoryId: selectedCategoryId ?? ""
        )
        
        Task {
            await productManager.createProduct(dto)
            dismiss()
        }
    }
} 
