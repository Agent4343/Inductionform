/**
 * DocumentScannerView.swift
 * Document Scanner with OCR
 *
 * Scan paper forms and convert to digital forms using VisionKit OCR
 */

import SwiftUI
import VisionKit
import Vision

// MARK: - Scanner Launcher View

struct DocumentScannerLauncherView: View {
    @State private var showingScanner = false
    @State private var scannedImages: [UIImage] = []
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var showingResults = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("Document Scanner")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Scan paper forms and convert them to digital forms automatically")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Spacer()

                // Scanner Button
                Button {
                    showingScanner = true
                } label: {
                    Label("Scan Document", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)

                // Recent Scans
                if !scannedImages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Scans")
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(scannedImages.indices, id: \.self) { index in
                                    Image(uiImage: scannedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 100)
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                                }
                            }
                        }
                    }
                    .padding()
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Scan")
            .sheet(isPresented: $showingScanner) {
                DocumentScannerRepresentable(scannedImages: $scannedImages) {
                    processScannedImages()
                }
            }
            .sheet(isPresented: $showingResults) {
                ScanResultsView(
                    images: scannedImages,
                    recognizedText: recognizedText
                )
            }
            .overlay {
                if isProcessing {
                    ProcessingOverlay()
                }
            }
        }
    }

    private func processScannedImages() {
        guard !scannedImages.isEmpty else { return }

        isProcessing = true

        Task {
            var allText = ""

            for image in scannedImages {
                if let text = await recognizeText(in: image) {
                    allText += text + "\n\n"
                }
            }

            await MainActor.run {
                recognizedText = allText
                isProcessing = false
                showingResults = true
            }
        }
    }

    private func recognizeText(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}

// MARK: - Document Scanner Representable

struct DocumentScannerRepresentable: UIViewControllerRepresentable {
    @Binding var scannedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerRepresentable

        init(_ parent: DocumentScannerRepresentable) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []

            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }

            parent.scannedImages = images
            parent.dismiss()
            parent.onComplete()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Scanner error: \(error)")
            parent.dismiss()
        }
    }
}

// MARK: - Scan Results View

struct ScanResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataController: DataController

    let images: [UIImage]
    let recognizedText: String

    @State private var detectedFields: [DetectedField] = []
    @State private var formTitle = "Scanned Form"
    @State private var showingFormEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Scanned Images
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(images.indices, id: \.self) { index in
                                    Image(uiImage: images[index])
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 200)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    } header: {
                        Text("Scanned Pages")
                            .font(.headline)
                    }

                    Divider()

                    // Recognized Text
                    Section {
                        Text(recognizedText)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    } header: {
                        HStack {
                            Text("Recognized Text")
                                .font(.headline)
                            Spacer()
                            Button("Copy") {
                                UIPasteboard.general.string = recognizedText
                            }
                            .font(.caption)
                        }
                    }

                    Divider()

                    // Detected Fields
                    Section {
                        if detectedFields.isEmpty {
                            Text("Analyzing document...")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(detectedFields, id: \.id) { field in
                                DetectedFieldRow(field: field)
                            }
                        }
                    } header: {
                        Text("Detected Fields")
                            .font(.headline)
                    }

                    // Create Form Button
                    Button {
                        createForm()
                    } label: {
                        Label("Create Form", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Scan Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                analyzeText()
            }
            .sheet(isPresented: $showingFormEditor) {
                FormEditorView(form: nil)
            }
        }
    }

    private func analyzeText() {
        // Simple field detection based on common patterns
        var fields: [DetectedField] = []

        let patterns: [(String, FieldType)] = [
            ("name:", .text),
            ("date:", .date),
            ("email:", .email),
            ("phone:", .phone),
            ("signature:", .signature),
            ("yes/no", .yesNo),
            ("checkbox", .checkbox),
            ("\\[\\s*\\]", .checkbox),
            ("_____", .text)
        ]

        let lines = recognizedText.components(separatedBy: "\n")

        for line in lines {
            let lowercased = line.lowercased().trimmingCharacters(in: .whitespaces)

            if lowercased.isEmpty { continue }

            // Check for common field patterns
            for (pattern, type) in patterns {
                if lowercased.contains(pattern) || lowercased.range(of: pattern, options: .regularExpression) != nil {
                    let label = line.replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
                    fields.append(DetectedField(id: UUID(), label: label, type: type, confidence: 0.8))
                    break
                }
            }

            // Detect questions (ending with ?)
            if line.contains("?") {
                let label = line.replacingOccurrences(of: "?", with: "").trimmingCharacters(in: .whitespaces)
                fields.append(DetectedField(id: UUID(), label: label + "?", type: .text, confidence: 0.6))
            }
        }

        detectedFields = fields
    }

    private func createForm() {
        let formFields = detectedFields.enumerated().map { index, field in
            FormFieldData(
                id: UUID().uuidString,
                type: field.type.rawValue,
                label: field.label,
                required: false,
                order: index
            )
        }

        _ = dataController.createForm(
            title: formTitle,
            fields: formFields
        )

        dismiss()
    }
}

// MARK: - Detected Field

struct DetectedField: Identifiable {
    let id: UUID
    let label: String
    let type: FieldType
    let confidence: Double
}

struct DetectedFieldRow: View {
    let field: DetectedField

    var body: some View {
        HStack {
            Image(systemName: field.type.icon)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(field.label)
                    .font(.subheadline)

                Text(field.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(Int(field.confidence * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Processing Overlay

struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Processing...")
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color(.systemGray5))
            .cornerRadius(16)
        }
    }
}

// MARK: - PDF Export View

struct PDFExportView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let fields: [FormFieldData]

    @State private var pdfData: Data?
    @State private var showingShare = false

    var body: some View {
        NavigationStack {
            VStack {
                if pdfData != nil {
                    Text("PDF Generated Successfully")
                        .font(.headline)

                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .padding()

                    Button {
                        showingShare = true
                    } label: {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                } else {
                    ProgressView("Generating PDF...")
                }
            }
            .navigationTitle("Export PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                generatePDF()
            }
            .sheet(isPresented: $showingShare) {
                if let data = pdfData {
                    ShareSheet(items: [data])
                }
            }
        }
    }

    private func generatePDF() {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        pdfData = renderer.pdfData { context in
            context.beginPage()

            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            title.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)

            // Fields
            var yPosition: CGFloat = 100

            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12)
            ]
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]

            for field in fields {
                if yPosition > 700 {
                    context.beginPage()
                    yPosition = 50
                }

                field.label.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: labelAttributes)
                yPosition += 18

                let value = field.value ?? "____________"
                value.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: valueAttributes)
                yPosition += 30
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    DocumentScannerLauncherView()
        .environmentObject(DataController.shared)
}
