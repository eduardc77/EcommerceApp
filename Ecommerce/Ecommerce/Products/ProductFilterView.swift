import SwiftUI
import Networking

struct ProductFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CategoryManager.self) private var categoryManager
    @Environment(ProductManager.self) private var productManager
    @Binding var filterDTO: ProductFilterRequest
    
    @State private var priceRange: ClosedRange<Double> = 0...10000
    @State private var selectedCategoryId: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    RangeSlider(value: $priceRange, in: 0...10000)
                        .padding(.vertical)
                    
                    HStack {
                        TextField("", text: .init(
                            get: { Int(priceRange.lowerBound).formatted(.currency(code: "USD")) },
                            set: { newValue in
                                if let value = Double(newValue.filter("0123456789.".contains)) {
                                    // Ensure new value is within bounds and not higher than current upper bound
                                    let validatedValue = min(max(value, 0), min(10000, priceRange.upperBound))
                                    if validatedValue <= priceRange.upperBound {
                                        priceRange = validatedValue...priceRange.upperBound
                                    }
                                }
                            }
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.leading)
                        .textFieldStyle(.plain)
                        
                        Spacer()
                        
                        Text("to")
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        TextField("", text: .init(
                            get: { Int(priceRange.upperBound).formatted(.currency(code: "USD")) },
                            set: { newValue in
                                if let value = Double(newValue.filter("0123456789.".contains)) {
                                    // Ensure new value is within bounds and not lower than current lower bound
                                    let validatedValue = min(max(value, priceRange.lowerBound), 10000)
                                    if validatedValue >= priceRange.lowerBound {
                                        priceRange = priceRange.lowerBound...validatedValue
                                    }
                                }
                            }
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                    }
                } header: {
                    Text("Price Range")
                }
                
                Section {
                    Picker("Category", selection: $selectedCategoryId) {
                        Text("All Categories")
                            .tag(Optional<String>.none)
                        
                        ForEach(categoryManager.categories) { category in
                            Text(category.name)
                                .tag(Optional(category.id))
                        }
                    }
                }
            }
            .navigationTitle("Filter Products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        filterDTO = ProductFilterRequest(
                            minPrice: priceRange.lowerBound,
                            maxPrice: priceRange.upperBound,
                            categoryId: selectedCategoryId
                        )
                        dismiss()
                    }
                }
            }
            .task {
                await categoryManager.loadCategories()
                if selectedCategoryId == nil {
                    selectedCategoryId = filterDTO.categoryId
                }
                if let minPrice = filterDTO.minPrice,
                   let maxPrice = filterDTO.maxPrice {
                    priceRange = minPrice...maxPrice
                }
            }
        }
    }
} 
