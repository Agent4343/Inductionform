/**
 * LegalSignatureView.swift
 *
 * Canadian-compliant electronic signature capture component
 *
 * Legal Framework:
 * - Federal: PIPEDA Part 2 (Personal Information Protection and Electronic Documents Act)
 * - Provincial: Electronic Transactions Acts (Ontario ETA, BC ETA, etc.)
 *
 * Features:
 * - Consent acknowledgment with checkbox
 * - Document hash (SHA-256) for integrity verification
 * - Timestamp, IP, device ID, location for audit trail
 * - Multiple signature types (drawn, typed, initials)
 * - Witness signature support
 * - Signature certificate generation
 */

import SwiftUI
import PencilKit
import CryptoKit
import CoreLocation

// MARK: - Signature Data Model

struct LegalSignature: Codable, Identifiable {
    let id: UUID
    let signerName: String
    let signerEmail: String
    let signerRole: String?
    let signatureType: SignatureType
    let signatureData: String // Base64 encoded image
    let documentHash: String // SHA-256 of form content
    let consentGiven: Bool
    let consentText: String
    let signedAt: Date
    let ipAddress: String?
    let deviceId: String
    let latitude: Double?
    let longitude: Double?
    let witnessName: String?
    let witnessEmail: String?

    enum SignatureType: String, Codable, CaseIterable {
        case drawn = "drawn"
        case typed = "typed"
        case initials = "initials"

        var displayName: String {
            switch self {
            case .drawn: return "Draw Signature"
            case .typed: return "Type Signature"
            case .initials: return "Initials Only"
            }
        }
    }
}

// MARK: - Legal Signature View

struct LegalSignatureView: View {
    @Environment(\.dismiss) private var dismiss

    // Form data for hashing
    let formId: UUID
    let formTitle: String
    let formFields: [FormField] // Your existing form field type
    let formCreatedAt: Date

    // Callbacks
    let onSign: (LegalSignature) -> Void

    // State
    @State private var signerName = ""
    @State private var signerEmail = ""
    @State private var signerRole = ""
    @State private var signatureType: LegalSignature.SignatureType = .drawn
    @State private var consentGiven = false
    @State private var showingWitness = false
    @State private var witnessName = ""
    @State private var witnessEmail = ""

    // Drawn signature
    @State private var canvasView = PKCanvasView()

    // Typed signature
    @State private var typedSignature = ""
    @State private var selectedFont = "Snell Roundhand"

    // Location
    @StateObject private var locationManager = SignatureLocationManager()

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    private let signatureFonts = [
        "Snell Roundhand",
        "Bradley Hand",
        "Noteworthy",
        "Marker Felt",
        "Zapfino"
    ]

    private let consentTextDefault = """
    I acknowledge that by providing my electronic signature, I am agreeing to sign this document electronically. I understand this electronic signature is legally binding and has the same legal effect as a handwritten signature under Canadian law (PIPEDA and applicable provincial Electronic Transactions Acts).
    """

    var body: some View {
        NavigationStack {
            Form {
                // Signer Information
                Section("Signer Information") {
                    TextField("Full Legal Name", text: $signerName)
                        .textContentType(.name)
                        .autocapitalization(.words)

                    TextField("Email Address", text: $signerEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    TextField("Role/Title (Optional)", text: $signerRole)
                }

                // Signature Type Selection
                Section("Signature Type") {
                    Picker("Type", selection: $signatureType) {
                        ForEach(LegalSignature.SignatureType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Signature Input
                Section("Your Signature") {
                    switch signatureType {
                    case .drawn:
                        drawnSignatureView
                    case .typed:
                        typedSignatureView
                    case .initials:
                        initialsView
                    }
                }

                // Witness (Optional)
                Section {
                    Toggle("Add Witness", isOn: $showingWitness)

                    if showingWitness {
                        TextField("Witness Name", text: $witnessName)
                            .textContentType(.name)
                        TextField("Witness Email", text: $witnessEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                } header: {
                    Text("Witness (Optional)")
                } footer: {
                    Text("A witness can provide additional verification for important documents.")
                }

                // Legal Consent
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(consentTextDefault)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Toggle(isOn: $consentGiven) {
                            Text("I agree to the above terms")
                                .fontWeight(.medium)
                        }
                    }
                } header: {
                    Text("Legal Acknowledgment")
                } footer: {
                    Text("You must agree to sign this document electronically.")
                        .foregroundColor(consentGiven ? .secondary : .red)
                }

                // Document Information
                Section("Document Details") {
                    LabeledContent("Document", value: formTitle)
                    LabeledContent("Document ID", value: formId.uuidString.prefix(8) + "...")
                    LabeledContent("Hash Algorithm", value: "SHA-256")
                    if let location = locationManager.location {
                        LabeledContent("Location", value: String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
                    }
                }
            }
            .navigationTitle("Sign Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sign") { submitSignature() }
                        .disabled(!isFormValid)
                        .fontWeight(.bold)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                locationManager.requestLocation()
            }
        }
    }

    // MARK: - Signature Input Views

    private var drawnSignatureView: some View {
        VStack {
            SignatureCanvasView(canvasView: $canvasView)
                .frame(height: 150)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            Button("Clear") {
                canvasView.drawing = PKDrawing()
            }
            .font(.caption)
        }
    }

    private var typedSignatureView: some View {
        VStack(spacing: 12) {
            TextField("Type your signature", text: $typedSignature)
                .font(.custom(selectedFont, size: 32))
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            Picker("Font Style", selection: $selectedFont) {
                ForEach(signatureFonts, id: \.self) { font in
                    Text(font).tag(font)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var initialsView: some View {
        VStack {
            SignatureCanvasView(canvasView: $canvasView)
                .frame(width: 100, height: 100)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            Text("Draw your initials")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Clear") {
                canvasView.drawing = PKDrawing()
            }
            .font(.caption)
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !signerName.trimmingCharacters(in: .whitespaces).isEmpty &&
        isValidEmail(signerEmail) &&
        consentGiven &&
        hasSignature
    }

    private var hasSignature: Bool {
        switch signatureType {
        case .drawn, .initials:
            return !canvasView.drawing.bounds.isEmpty
        case .typed:
            return !typedSignature.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }

    // MARK: - Submit Signature

    private func submitSignature() {
        guard isFormValid else {
            errorMessage = "Please fill in all required fields and provide your signature."
            showingError = true
            return
        }

        // Generate document hash
        let documentHash = generateDocumentHash()

        // Generate signature image data
        let signatureData = generateSignatureData()

        // Get device ID
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        // Create legal signature
        let signature = LegalSignature(
            id: UUID(),
            signerName: signerName.trimmingCharacters(in: .whitespaces),
            signerEmail: signerEmail.trimmingCharacters(in: .whitespaces).lowercased(),
            signerRole: signerRole.isEmpty ? nil : signerRole,
            signatureType: signatureType,
            signatureData: signatureData,
            documentHash: documentHash,
            consentGiven: consentGiven,
            consentText: consentTextDefault,
            signedAt: Date(),
            ipAddress: nil, // Set by server
            deviceId: deviceId,
            latitude: locationManager.location?.coordinate.latitude,
            longitude: locationManager.location?.coordinate.longitude,
            witnessName: showingWitness ? witnessName : nil,
            witnessEmail: showingWitness ? witnessEmail : nil
        )

        onSign(signature)
        dismiss()
    }

    // MARK: - Document Hash Generation

    private func generateDocumentHash() -> String {
        // Create deterministic JSON representation of form content
        let formContent: [String: Any] = [
            "id": formId.uuidString,
            "title": formTitle,
            "fields": formFields.map { field -> [String: Any] in
                return [
                    "id": field.id?.uuidString ?? "",
                    "label": field.label ?? "",
                    "value": field.value ?? ""
                ]
            },
            "created_at": ISO8601DateFormatter().string(from: formCreatedAt)
        ]

        // Convert to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: formContent, options: .sortedKeys) else {
            return "error_generating_hash"
        }

        // Generate SHA-256 hash
        let hash = SHA256.hash(data: jsonData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Signature Image Generation

    private func generateSignatureData() -> String {
        var image: UIImage?

        switch signatureType {
        case .drawn, .initials:
            image = canvasView.drawing.image(from: canvasView.drawing.bounds, scale: 2.0)
        case .typed:
            image = renderTypedSignature()
        }

        guard let signatureImage = image,
              let imageData = signatureImage.pngData() else {
            return ""
        }

        return "data:image/png;base64," + imageData.base64EncodedString()
    }

    private func renderTypedSignature() -> UIImage? {
        let size = CGSize(width: 400, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: selectedFont, size: 48) ?? UIFont.systemFont(ofSize: 48),
                .foregroundColor: UIColor.black
            ]

            let text = typedSignature as NSString
            let textSize = text.size(withAttributes: attributes)
            let point = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )

            text.draw(at: point, withAttributes: attributes)
        }
    }
}

// MARK: - Signature Canvas View

struct SignatureCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) { }
}

// MARK: - Location Manager

class SignatureLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Signature Certificate View

struct SignatureCertificateView: View {
    let signature: LegalSignature
    let formTitle: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("Signature Verified")
                            .font(.headline)
                        Text("Document signed electronically")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)

                Divider()

                // Document Info
                Group {
                    Text("Document Information")
                        .font(.headline)

                    LabeledContent("Document", value: formTitle)
                    LabeledContent("Document Hash (SHA-256)") {
                        Text(signature.documentHash.prefix(16) + "...")
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                Divider()

                // Signer Info
                Group {
                    Text("Signer Information")
                        .font(.headline)

                    LabeledContent("Name", value: signature.signerName)
                    LabeledContent("Email", value: signature.signerEmail)
                    if let role = signature.signerRole {
                        LabeledContent("Role", value: role)
                    }
                    LabeledContent("Signature Type", value: signature.signatureType.displayName)
                    LabeledContent("Signed At", value: signature.signedAt.formatted(date: .long, time: .complete))
                }

                Divider()

                // Verification Info
                Group {
                    Text("Verification Details")
                        .font(.headline)

                    LabeledContent("Device ID", value: String(signature.deviceId.prefix(8)) + "...")
                    if let lat = signature.latitude, let lon = signature.longitude {
                        LabeledContent("Location", value: String(format: "%.4f, %.4f", lat, lon))
                    }
                    LabeledContent("Consent Given", value: signature.consentGiven ? "Yes" : "No")
                }

                if let witnessName = signature.witnessName {
                    Divider()
                    Group {
                        Text("Witness")
                            .font(.headline)
                        LabeledContent("Name", value: witnessName)
                        if let witnessEmail = signature.witnessEmail {
                            LabeledContent("Email", value: witnessEmail)
                        }
                    }
                }

                Divider()

                // Legal Notice
                VStack(alignment: .leading, spacing: 8) {
                    Text("Legal Framework")
                        .font(.headline)
                    Text("This electronic signature is legally binding under Canadian law, including the Personal Information Protection and Electronic Documents Act (PIPEDA) and applicable provincial Electronic Transactions Acts.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Signature Certificate")
    }
}

// MARK: - Preview

#Preview {
    LegalSignatureView(
        formId: UUID(),
        formTitle: "Safety Inspection Form",
        formFields: [],
        formCreatedAt: Date()
    ) { signature in
        print("Signed: \(signature.signerName)")
    }
}
