import SwiftUI

struct RangeSlider: View {
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    
    @State private var lowValue: Double
    @State private var highValue: Double
    
    init(value: Binding<ClosedRange<Double>>, in bounds: ClosedRange<Double>) {
        self._range = value
        self.bounds = bounds
        
        // Ensure initial values are valid without modifying the binding
        let initialLow = max(value.wrappedValue.lowerBound, bounds.lowerBound)
        let initialHigh = min(max(initialLow, value.wrappedValue.upperBound), bounds.upperBound)
        
        // Initialize state with validated values
        self._lowValue = State(initialValue: initialLow)
        self._highValue = State(initialValue: initialHigh)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { lowValue },
                    set: { newValue in
                        // Ensure new value is within bounds and not higher than current upper
                        let validValue = min(max(newValue, bounds.lowerBound), highValue)
                        lowValue = validValue
                        range = lowValue...highValue
                    }
                ),
                in: bounds,
                step: 1
            )
            
            Slider(
                value: Binding(
                    get: { highValue },
                    set: { newValue in
                        // Ensure new value is within bounds and not lower than current lower
                        let validValue = max(min(newValue, bounds.upperBound), lowValue)
                        highValue = validValue
                        range = lowValue...highValue
                    }
                ),
                in: bounds,
                step: 1
            )
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var range: ClosedRange<Double> = 0...100
        
        var body: some View {
            VStack {
                RangeSlider(value: $range, in: 0...1000)
                Text("Range: \(Int(range.lowerBound))...\(Int(range.upperBound))")
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
} 