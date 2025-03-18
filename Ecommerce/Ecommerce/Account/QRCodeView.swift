import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let url: String
    let size: CGFloat
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        if let qrImage = generateQRCode(from: url) {
            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "xmark.circle")
                .font(.system(size: size / 4))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H" // High error correction
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale the image to the desired size
        let scale = size / outputImage.extent.width
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    QRCodeView(url: "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example", size: 200)
} 