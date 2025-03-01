import SwiftUI
import Networking

struct CheckoutView: View {
    @Environment(CartManager.self) private var cartManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var cardNumber = ""
    @State private var expiryDate = ""
    @State private var cvv = ""
    @State private var isProcessing = false
    @State private var showSuccess = false
    
    private var isValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        !address.isEmpty &&
        !city.isEmpty &&
        !state.isEmpty &&
        !zipCode.isEmpty &&
        !cardNumber.isEmpty &&
        !expiryDate.isEmpty &&
        !cvv.isEmpty
    }
    
    var body: some View {
        List {
            Section("Contact Information") {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            Section("Shipping Address") {
                TextField("Address", text: $address)
                    .textContentType(.streetAddressLine1)
                TextField("City", text: $city)
                    .textContentType(.addressCity)
                TextField("State", text: $state)
                    .textContentType(.addressState)
                TextField("ZIP Code", text: $zipCode)
                    .textContentType(.postalCode)
                    .keyboardType(.numberPad)
            }
            
            Section("Payment") {
                TextField("Card Number", text: $cardNumber)
                    .textContentType(.creditCardNumber)
                    .keyboardType(.numberPad)
                
                HStack {
                    TextField("MM/YY", text: $expiryDate)
                        .keyboardType(.numberPad)
                    
                    Divider()
                    
                    TextField("CVV", text: $cvv)
                        .keyboardType(.numberPad)
                }
            }
            
            Section("Order Summary") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Items")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(cartManager.items.count)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Subtotal")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(cartManager.subtotal, format: .currency(code: "USD"))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Tax")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(cartManager.tax, format: .currency(code: "USD"))
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(cartManager.total, format: .currency(code: "USD"))
                            .fontWeight(.semibold)
                    }
                }
            }
            
            Section {
                Button {
                    placeOrder()
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Place Order")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || isProcessing)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showSuccess) {
            NavigationStack {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    
                    Text("Order Placed!")
                        .font(.title2.bold())
                    
                    Text("Thank you for your order. We'll send you a confirmation email shortly.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private func placeOrder() {
        isProcessing = true
        
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isProcessing = false
            showSuccess = true
            cartManager.clearCart()
        }
    }
} 