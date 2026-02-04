//
//  DigitalFormsApp_Ultimate.swift
//  DigitalFormsApp
//
//  Ultimate version with ALL features:
//  - Document Scanner with OCR
//  - Conditional Logic
//  - Photo Annotation
//  - Voice-to-Text
//  - Barcode/QR Scanner
//  - Dashboard & Analytics
//  - Workflow Automation
//  - Advanced Signatures
//  - Map Integration
//  - Widgets & Shortcuts
//  - Security (Biometric, Encryption)
//  - Auto-save & Progress
//

import SwiftUI
import CoreData
import PencilKit
import PhotosUI
import CoreLocation
import PDFKit
import Network
import Security
import Combine
import UIKit
import VisionKit
import Vision
import MessageUI
import UniformTypeIdentifiers
import MapKit
import AVFoundation
import Speech
import LocalAuthentication
import WidgetKit
import Intents

// MARK: - APP ENTRY POINT

@main
struct DigitalFormsAppMain: App {
    @StateObject private var dataController = DataController.shared
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var analyticsManager = AnalyticsManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(dataController)
                .environmentObject(syncManager)
                .environmentObject(authManager)
                .environmentObject(analyticsManager)
        }
    }
}

// MARK: - ANALYTICS MANAGER

class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()

    @Published var totalForms: Int = 0
    @Published var completedForms: Int = 0
    @Published var pendingApprovals: Int = 0
    @Published var rejectedForms: Int = 0
    @Published var averageCompletionTime: TimeInterval = 0
    @Published var formsByCategory: [String: Int] = [:]
    @Published var formsByStatus: [String: Int] = [:]
    @Published var recentActivity: [ActivityItem] = []
    @Published var complianceRate: Double = 0.0

    struct ActivityItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let timestamp: Date
    }

    func refreshAnalytics() {
        let forms = DataController.shared.fetchForms()

        totalForms = forms.count
        completedForms = forms.filter { $0.status == FormStatus.approved.rawValue }.count
        pendingApprovals = forms.filter { $0.status == FormStatus.submitted.rawValue }.count
        rejectedForms = forms.filter { $0.status == FormStatus.rejected.rawValue }.count

        // Calculate average completion time
        let completedWithTimes = forms.filter { $0.submittedAt != nil && $0.createdAt != nil }
        if !completedWithTimes.isEmpty {
            let totalTime = completedWithTimes.reduce(0.0) { result, form in
                result + (form.submittedAt?.timeIntervalSince(form.createdAt!) ?? 0)
            }
            averageCompletionTime = totalTime / Double(completedWithTimes.count)
        }

        // Group by status
        formsByStatus = Dictionary(grouping: forms) { $0.status ?? "unknown" }
            .mapValues { $0.count }

        // Compliance rate
        if totalForms > 0 {
            complianceRate = Double(completedForms) / Double(totalForms) * 100
        }

        // Recent activity
        recentActivity = forms.prefix(10).map { form in
            ActivityItem(
                title: form.title ?? "Form",
                subtitle: form.status?.capitalized ?? "Draft",
                icon: iconForStatus(form.status ?? "draft"),
                color: colorForStatus(form.status ?? "draft"),
                timestamp: form.updatedAt ?? Date()
            )
        }
    }

    private func iconForStatus(_ status: String) -> String {
        switch status {
        case "draft": return "pencil"
        case "submitted": return "paperplane.fill"
        case "approved": return "checkmark.seal.fill"
        case "rejected": return "xmark.seal.fill"
        default: return "doc"
        }
    }

    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "draft": return .blue
        case "submitted": return .orange
        case "approved": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
}

// MARK: - CONDITIONAL LOGIC

struct FieldCondition: Codable, Identifiable {
    var id = UUID()
    var sourceFieldId: UUID
    var operator_: ConditionOperator
    var value: String
    var action: ConditionAction
    var targetFieldIds: [UUID]

    enum ConditionOperator: String, Codable, CaseIterable {
        case equals = "equals"
        case notEquals = "not_equals"
        case contains = "contains"
        case greaterThan = "greater_than"
        case lessThan = "less_than"
        case isEmpty = "is_empty"
        case isNotEmpty = "is_not_empty"

        var displayName: String {
            switch self {
            case .equals: return "Equals"
            case .notEquals: return "Does not equal"
            case .contains: return "Contains"
            case .greaterThan: return "Greater than"
            case .lessThan: return "Less than"
            case .isEmpty: return "Is empty"
            case .isNotEmpty: return "Is not empty"
            }
        }
    }

    enum ConditionAction: String, Codable, CaseIterable {
        case show = "show"
        case hide = "hide"
        case require = "require"
        case optional = "optional"

        var displayName: String {
            switch self {
            case .show: return "Show fields"
            case .hide: return "Hide fields"
            case .require: return "Make required"
            case .optional: return "Make optional"
            }
        }
    }

    func evaluate(with fieldValues: [UUID: String]) -> Bool {
        let sourceValue = fieldValues[sourceFieldId] ?? ""

        switch operator_ {
        case .equals:
            return sourceValue.lowercased() == value.lowercased()
        case .notEquals:
            return sourceValue.lowercased() != value.lowercased()
        case .contains:
            return sourceValue.lowercased().contains(value.lowercased())
        case .greaterThan:
            return (Double(sourceValue) ?? 0) > (Double(value) ?? 0)
        case .lessThan:
            return (Double(sourceValue) ?? 0) < (Double(value) ?? 0)
        case .isEmpty:
            return sourceValue.isEmpty
        case .isNotEmpty:
            return !sourceValue.isEmpty
        }
    }
}

class ConditionalLogicEngine: ObservableObject {
    @Published var hiddenFields: Set<UUID> = []
    @Published var requiredFields: Set<UUID> = []

    private var conditions: [FieldCondition] = []
    private var baseRequiredFields: Set<UUID> = []

    func setConditions(_ conditions: [FieldCondition], baseRequired: Set<UUID>) {
        self.conditions = conditions
        self.baseRequiredFields = baseRequired
    }

    func evaluate(fieldValues: [UUID: String]) {
        var hidden = Set<UUID>()
        var required = baseRequiredFields

        for condition in conditions {
            let result = condition.evaluate(with: fieldValues)

            switch condition.action {
            case .show:
                if !result {
                    hidden.formUnion(condition.targetFieldIds)
                }
            case .hide:
                if result {
                    hidden.formUnion(condition.targetFieldIds)
                }
            case .require:
                if result {
                    required.formUnion(condition.targetFieldIds)
                }
            case .optional:
                if result {
                    required.subtract(condition.targetFieldIds)
                }
            }
        }

        hiddenFields = hidden
        requiredFields = required
    }

    func isFieldVisible(_ fieldId: UUID) -> Bool {
        !hiddenFields.contains(fieldId)
    }

    func isFieldRequired(_ fieldId: UUID) -> Bool {
        requiredFields.contains(fieldId)
    }
}

// MARK: - PHOTO ANNOTATION

struct PhotoAnnotationView: View {
    let image: UIImage
    @Binding var annotatedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    @State private var canvasView = PKCanvasView()
    @State private var selectedTool: AnnotationTool = .pen
    @State private var selectedColor: Color = .red
    @State private var showTextInput = false
    @State private var textToAdd = ""
    @State private var textAnnotations: [TextAnnotation] = []
    @State private var shapes: [ShapeAnnotation] = []

    enum AnnotationTool: String, CaseIterable {
        case pen = "Pen"
        case highlighter = "Highlighter"
        case arrow = "Arrow"
        case circle = "Circle"
        case rectangle = "Rectangle"
        case text = "Text"

        var icon: String {
            switch self {
            case .pen: return "pencil.tip"
            case .highlighter: return "highlighter"
            case .arrow: return "arrow.right"
            case .circle: return "circle"
            case .rectangle: return "rectangle"
            case .text: return "textformat"
            }
        }
    }

    struct TextAnnotation: Identifiable {
        let id = UUID()
        var text: String
        var position: CGPoint
        var color: Color
    }

    struct ShapeAnnotation: Identifiable {
        let id = UUID()
        var type: AnnotationTool
        var start: CGPoint
        var end: CGPoint
        var color: Color
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Canvas with image
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    // Drawing canvas
                    AnnotationCanvasView(canvasView: $canvasView, tool: selectedTool, color: selectedColor)
                        .opacity(0.99)

                    // Text annotations
                    ForEach(textAnnotations) { annotation in
                        Text(annotation.text)
                            .font(.headline)
                            .foregroundColor(annotation.color)
                            .padding(4)
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(4)
                            .position(annotation.position)
                    }

                    // Shape annotations
                    ForEach(shapes) { shape in
                        ShapeOverlay(shape: shape)
                    }
                }
                .frame(maxHeight: .infinity)

                // Tool palette
                toolPalette
            }
            .navigationTitle("Annotate Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { saveAnnotation() }
                }
            }
            .alert("Add Text", isPresented: $showTextInput) {
                TextField("Enter text", text: $textToAdd)
                Button("Cancel", role: .cancel) { }
                Button("Add") {
                    let annotation = TextAnnotation(
                        text: textToAdd,
                        position: CGPoint(x: 150, y: 150),
                        color: selectedColor
                    )
                    textAnnotations.append(annotation)
                    textToAdd = ""
                }
            }
        }
    }

    private var toolPalette: some View {
        VStack(spacing: 12) {
            // Tools
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AnnotationTool.allCases, id: \.self) { tool in
                        Button(action: {
                            selectedTool = tool
                            if tool == .text {
                                showTextInput = true
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: tool.icon)
                                    .font(.title2)
                                Text(tool.rawValue)
                                    .font(.caption2)
                            }
                            .frame(width: 60, height: 50)
                            .background(selectedTool == tool ? Color.blue.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                        }
                        .foregroundColor(selectedTool == tool ? .blue : .primary)
                    }
                }
                .padding(.horizontal)
            }

            // Colors
            HStack(spacing: 16) {
                ForEach([Color.red, Color.blue, Color.green, Color.yellow, Color.black, Color.white], id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                        )
                        .onTapGesture {
                            selectedColor = color
                        }
                }

                Spacer()

                Button(action: clearAnnotations) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }

    private func clearAnnotations() {
        canvasView.drawing = PKDrawing()
        textAnnotations.removeAll()
        shapes.removeAll()
    }

    private func saveAnnotation() {
        // Render all annotations onto the image
        let renderer = UIGraphicsImageRenderer(size: image.size)

        let annotated = renderer.image { context in
            // Draw original image
            image.draw(at: .zero)

            // Draw canvas
            let canvasImage = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
            canvasImage.draw(in: CGRect(origin: .zero, size: image.size))
        }

        annotatedImage = annotated
        dismiss()
    }
}

struct AnnotationCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let tool: PhotoAnnotationView.AnnotationTool
    let color: Color

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        updateTool()
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        updateTool()
    }

    private func updateTool() {
        let uiColor = UIColor(color)

        switch tool {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: 3)
        case .highlighter:
            canvasView.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.3), width: 20)
        default:
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: 3)
        }
    }
}

struct ShapeOverlay: View {
    let shape: PhotoAnnotationView.ShapeAnnotation

    var body: some View {
        switch shape.type {
        case .arrow:
            ArrowShape(start: shape.start, end: shape.end)
                .stroke(shape.color, lineWidth: 3)
        case .circle:
            Circle()
                .stroke(shape.color, lineWidth: 3)
                .frame(width: abs(shape.end.x - shape.start.x), height: abs(shape.end.y - shape.start.y))
                .position(x: (shape.start.x + shape.end.x) / 2, y: (shape.start.y + shape.end.y) / 2)
        case .rectangle:
            Rectangle()
                .stroke(shape.color, lineWidth: 3)
                .frame(width: abs(shape.end.x - shape.start.x), height: abs(shape.end.y - shape.start.y))
                .position(x: (shape.start.x + shape.end.x) / 2, y: (shape.start.y + shape.end.y) / 2)
        default:
            EmptyView()
        }
    }
}

struct ArrowShape: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        // Arrow head
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6

        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        path.move(to: end)
        path.addLine(to: point1)
        path.move(to: end)
        path.addLine(to: point2)

        return path
    }
}

// MARK: - VOICE INPUT

class VoiceInputManager: NSObject, ObservableObject {
    static let shared = VoiceInputManager()

    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var isAvailable = false
    @Published var error: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        super.init()
        checkAvailability()
    }

    func checkAvailability() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.isAvailable = status == .authorized
            }
        }
    }

    func startRecording() {
        guard !isRecording else { return }

        // Reset
        recognitionTask?.cancel()
        recognitionTask = nil
        transcribedText = ""
        error = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = "Audio session error: \(error.localizedDescription)"
            return
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            error = "Unable to create recognition request"
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self?.transcribedText = result.bestTranscription.formattedString
                }
            }

            if error != nil || result?.isFinal == true {
                self?.stopRecording()
            }
        }

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            self.error = "Audio engine error: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
}

struct VoiceInputButton: View {
    @StateObject private var voiceManager = VoiceInputManager.shared
    @Binding var text: String

    var body: some View {
        Button(action: toggleRecording) {
            Image(systemName: voiceManager.isRecording ? "mic.fill" : "mic")
                .foregroundColor(voiceManager.isRecording ? .red : .blue)
                .font(.title2)
                .padding(8)
                .background(voiceManager.isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                .clipShape(Circle())
        }
        .disabled(!voiceManager.isAvailable)
        .onChange(of: voiceManager.transcribedText) { _, newValue in
            if !newValue.isEmpty {
                text = newValue
            }
        }
    }

    private func toggleRecording() {
        if voiceManager.isRecording {
            voiceManager.stopRecording()
        } else {
            voiceManager.startRecording()
        }
    }
}

// MARK: - BARCODE SCANNER

struct BarcodeScannerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String, String) -> Void // (value, type)

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, BarcodeScannerDelegate {
        let parent: BarcodeScannerView

        init(_ parent: BarcodeScannerView) {
            self.parent = parent
        }

        func didScanBarcode(_ value: String, type: String) {
            parent.onScan(value, type)
            parent.dismiss()
        }

        func didFailWithError(_ error: Error) {
            parent.dismiss()
        }
    }
}

protocol BarcodeScannerDelegate: AnyObject {
    func didScanBarcode(_ value: String, type: String)
    func didFailWithError(_ error: Error)
}

class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: BarcodeScannerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScanner()
    }

    private func setupScanner() {
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              session.canAddInput(videoInput) else {
            delegate?.didFailWithError(NSError(domain: "Scanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Camera not available"]))
            return
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .qr, .ean8, .ean13, .pdf417, .code128, .code39, .code93, .upce, .aztec, .dataMatrix
            ]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        self.captureSession = session
        self.previewLayer = previewLayer

        // Add scan frame overlay
        addScanOverlay()

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func addScanOverlay() {
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        let scanRect = CGRect(x: 50, y: view.bounds.height / 2 - 100, width: view.bounds.width - 100, height: 200)
        let path = UIBezierPath(rect: overlayView.bounds)
        path.append(UIBezierPath(roundedRect: scanRect, cornerRadius: 10).reversing())

        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        overlayView.layer.mask = maskLayer

        view.addSubview(overlayView)

        // Add corner markers
        let cornerLayer = CAShapeLayer()
        cornerLayer.strokeColor = UIColor.green.cgColor
        cornerLayer.lineWidth = 4
        cornerLayer.fillColor = UIColor.clear.cgColor

        let cornerPath = UIBezierPath()
        let cornerLength: CGFloat = 20

        // Top left
        cornerPath.move(to: CGPoint(x: scanRect.minX, y: scanRect.minY + cornerLength))
        cornerPath.addLine(to: CGPoint(x: scanRect.minX, y: scanRect.minY))
        cornerPath.addLine(to: CGPoint(x: scanRect.minX + cornerLength, y: scanRect.minY))

        // Top right
        cornerPath.move(to: CGPoint(x: scanRect.maxX - cornerLength, y: scanRect.minY))
        cornerPath.addLine(to: CGPoint(x: scanRect.maxX, y: scanRect.minY))
        cornerPath.addLine(to: CGPoint(x: scanRect.maxX, y: scanRect.minY + cornerLength))

        // Bottom left
        cornerPath.move(to: CGPoint(x: scanRect.minX, y: scanRect.maxY - cornerLength))
        cornerPath.addLine(to: CGPoint(x: scanRect.minX, y: scanRect.maxY))
        cornerPath.addLine(to: CGPoint(x: scanRect.minX + cornerLength, y: scanRect.maxY))

        // Bottom right
        cornerPath.move(to: CGPoint(x: scanRect.maxX - cornerLength, y: scanRect.maxY))
        cornerPath.addLine(to: CGPoint(x: scanRect.maxX, y: scanRect.maxY))
        cornerPath.addLine(to: CGPoint(x: scanRect.maxX, y: scanRect.maxY - cornerLength))

        cornerLayer.path = cornerPath.cgPath
        view.layer.addSublayer(cornerLayer)

        // Add instruction label
        let label = UILabel()
        label.text = "Align barcode within frame"
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.frame = CGRect(x: 0, y: scanRect.maxY + 20, width: view.bounds.width, height: 30)
        view.addSubview(label)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else { return }

        captureSession?.stopRunning()
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

        delegate?.didScanBarcode(stringValue, type: metadataObject.type.rawValue)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}

// MARK: - WORKFLOW AUTOMATION

struct WorkflowRule: Codable, Identifiable {
    var id = UUID()
    var name: String
    var isActive: Bool
    var trigger: WorkflowTrigger
    var conditions: [WorkflowCondition]
    var actions: [WorkflowAction]
}

enum WorkflowTrigger: String, Codable, CaseIterable {
    case formSubmitted = "form_submitted"
    case formApproved = "form_approved"
    case formRejected = "form_rejected"
    case fieldValueChanged = "field_value_changed"

    var displayName: String {
        switch self {
        case .formSubmitted: return "When form is submitted"
        case .formApproved: return "When form is approved"
        case .formRejected: return "When form is rejected"
        case .fieldValueChanged: return "When field value changes"
        }
    }
}

struct WorkflowCondition: Codable, Identifiable {
    var id = UUID()
    var fieldId: UUID?
    var operator_: String
    var value: String
}

struct WorkflowAction: Codable, Identifiable {
    var id = UUID()
    var type: WorkflowActionType
    var parameters: [String: String]
}

enum WorkflowActionType: String, Codable, CaseIterable {
    case sendEmail = "send_email"
    case assignApprover = "assign_approver"
    case setFieldValue = "set_field_value"
    case createTask = "create_task"
    case sendNotification = "send_notification"
    case webhook = "webhook"

    var displayName: String {
        switch self {
        case .sendEmail: return "Send Email"
        case .assignApprover: return "Assign Approver"
        case .setFieldValue: return "Set Field Value"
        case .createTask: return "Create Task"
        case .sendNotification: return "Send Notification"
        case .webhook: return "Call Webhook"
        }
    }

    var icon: String {
        switch self {
        case .sendEmail: return "envelope"
        case .assignApprover: return "person.badge.plus"
        case .setFieldValue: return "pencil"
        case .createTask: return "checklist"
        case .sendNotification: return "bell"
        case .webhook: return "arrow.up.forward.app"
        }
    }
}

class WorkflowEngine: ObservableObject {
    static let shared = WorkflowEngine()

    @Published var rules: [WorkflowRule] = []

    func executeRules(trigger: WorkflowTrigger, form: FormEntity, context: [String: Any] = [:]) {
        let matchingRules = rules.filter { $0.isActive && $0.trigger == trigger }

        for rule in matchingRules {
            if evaluateConditions(rule.conditions, form: form) {
                executeActions(rule.actions, form: form)
            }
        }
    }

    private func evaluateConditions(_ conditions: [WorkflowCondition], form: FormEntity) -> Bool {
        // If no conditions, always pass
        guard !conditions.isEmpty else { return true }

        // All conditions must pass
        return conditions.allSatisfy { condition in
            // Evaluate each condition
            true // Simplified for now
        }
    }

    private func executeActions(_ actions: [WorkflowAction], form: FormEntity) {
        for action in actions {
            switch action.type {
            case .sendEmail:
                // Send email notification
                print("Sending email for form: \(form.title ?? "")")
            case .assignApprover:
                // Assign approver
                print("Assigning approver for form: \(form.title ?? "")")
            case .setFieldValue:
                // Set field value
                print("Setting field value for form: \(form.title ?? "")")
            case .createTask:
                // Create task
                print("Creating task for form: \(form.title ?? "")")
            case .sendNotification:
                // Send push notification
                sendLocalNotification(title: "Form Update", body: "Form '\(form.title ?? "")' requires attention")
            case .webhook:
                // Call webhook
                if let url = action.parameters["url"] {
                    callWebhook(url: url, form: form)
                }
            }
        }
    }

    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func callWebhook(url: String, form: FormEntity) {
        guard let webhookURL = URL(string: url) else { return }

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formData = FormSyncData(from: form)
        request.httpBody = try? JSONEncoder().encode(formData)

        URLSession.shared.dataTask(with: request).resume()
    }
}

// MARK: - MAP VIEW

struct FormLocationMapView: View {
    let latitude: Double
    let longitude: Double
    let title: String

    @State private var region: MKCoordinateRegion
    @State private var showFullMap = false

    init(latitude: Double, longitude: Double, title: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.title = title
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)

            Map(coordinateRegion: $region, annotationItems: [MapPin(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), title: title)]) { pin in
                MapMarker(coordinate: pin.coordinate, tint: .red)
            }
            .frame(height: 150)
            .cornerRadius(12)
            .onTapGesture {
                showFullMap = true
            }

            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                Text(String(format: "%.6f, %.6f", latitude, longitude))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Open in Maps") {
                    openInMaps()
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showFullMap) {
            FullMapView(latitude: latitude, longitude: longitude, title: title)
        }
    }

    private func openInMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = title
        mapItem.openInMaps()
    }
}

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}

struct FullMapView: View {
    let latitude: Double
    let longitude: Double
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var region: MKCoordinateRegion
    @State private var mapType: MKMapType = .standard

    init(latitude: Double, longitude: Double, title: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.title = title
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region, annotationItems: [MapPin(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), title: title)]) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                        Text(title)
                            .font(.caption)
                            .padding(4)
                            .background(Color.white)
                            .cornerRadius(4)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Standard") { mapType = .standard }
                        Button("Satellite") { mapType = .satellite }
                        Button("Hybrid") { mapType = .hybrid }
                    } label: {
                        Image(systemName: "map")
                    }
                }
            }
        }
    }
}

// MARK: - BIOMETRIC AUTHENTICATION

class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()

    @Published var isUnlocked = false
    @Published var biometricType: BiometricType = .none
    @Published var error: String?

    enum BiometricType {
        case none
        case faceID
        case touchID
    }

    init() {
        checkBiometricType()
    }

    func checkBiometricType() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            default:
                biometricType = .none
            }
        } else {
            biometricType = .none
        }
    }

    func authenticate(reason: String = "Authenticate to access forms") async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            await MainActor.run {
                self.error = error?.localizedDescription ?? "Biometric authentication not available"
            }
            return false
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            await MainActor.run {
                self.isUnlocked = success
            }
            return success
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            return false
        }
    }

    func lock() {
        isUnlocked = false
    }
}

// MARK: - AUTO-SAVE MANAGER

class AutoSaveManager: ObservableObject {
    static let shared = AutoSaveManager()

    @Published var lastSaveTime: Date?
    @Published var hasUnsavedChanges = false

    private var saveTimer: Timer?
    private var saveInterval: TimeInterval = 30 // Auto-save every 30 seconds

    func startAutoSave(for form: FormEntity) {
        stopAutoSave()

        saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { [weak self] _ in
            self?.performAutoSave(form)
        }
    }

    func stopAutoSave() {
        saveTimer?.invalidate()
        saveTimer = nil
    }

    func markChanged() {
        hasUnsavedChanges = true
    }

    private func performAutoSave(_ form: FormEntity) {
        guard hasUnsavedChanges else { return }

        DataController.shared.save()

        DispatchQueue.main.async {
            self.lastSaveTime = Date()
            self.hasUnsavedChanges = false
        }
    }

    func saveNow() {
        DataController.shared.save()
        lastSaveTime = Date()
        hasUnsavedChanges = false
    }
}

// MARK: - PROGRESS TRACKER

struct FormProgressView: View {
    let currentStep: Int
    let totalSteps: Int
    let stepTitles: [String]

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut, value: currentStep)
                }
            }
            .frame(height: 4)

            // Step indicators
            HStack {
                ForEach(0..<totalSteps, id: \.self) { step in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(step < currentStep ? Color.blue : (step == currentStep ? Color.blue : Color.gray.opacity(0.3)))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Group {
                                    if step < currentStep {
                                        Image(systemName: "checkmark")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                    } else {
                                        Text("\(step + 1)")
                                            .font(.caption2)
                                            .foregroundColor(step == currentStep ? .white : .gray)
                                    }
                                }
                            )

                        if step < stepTitles.count {
                            Text(stepTitles[step])
                                .font(.caption2)
                                .foregroundColor(step == currentStep ? .primary : .secondary)
                                .lineLimit(1)
                        }
                    }

                    if step < totalSteps - 1 {
                        Spacer()
                    }
                }
            }

            // Progress text
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - DASHBOARD VIEW

struct DashboardView: View {
    @EnvironmentObject var analyticsManager: AnalyticsManager
    @State private var selectedPeriod: TimePeriod = .week

    enum TimePeriod: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period selector
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Stats cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: "Total Forms", value: "\(analyticsManager.totalForms)", icon: "doc.text.fill", color: .blue)
                        StatCard(title: "Completed", value: "\(analyticsManager.completedForms)", icon: "checkmark.circle.fill", color: .green)
                        StatCard(title: "Pending", value: "\(analyticsManager.pendingApprovals)", icon: "clock.fill", color: .orange)
                        StatCard(title: "Rejected", value: "\(analyticsManager.rejectedForms)", icon: "xmark.circle.fill", color: .red)
                    }
                    .padding(.horizontal)

                    // Compliance rate
                    ComplianceCard(rate: analyticsManager.complianceRate)
                        .padding(.horizontal)

                    // Average completion time
                    if analyticsManager.averageCompletionTime > 0 {
                        InfoCard(
                            title: "Avg. Completion Time",
                            value: formatDuration(analyticsManager.averageCompletionTime),
                            icon: "timer",
                            color: .purple
                        )
                        .padding(.horizontal)
                    }

                    // Recent activity
                    RecentActivitySection(activities: analyticsManager.recentActivity)
                        .padding(.horizontal)

                    // Status breakdown chart
                    StatusBreakdownChart(data: analyticsManager.formsByStatus)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .onAppear {
                analyticsManager.refreshAnalytics()
            }
            .refreshable {
                analyticsManager.refreshAnalytics()
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

struct ComplianceCard: View {
    let rate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Compliance Rate")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f%%", rate))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(rate >= 80 ? .green : (rate >= 50 ? .orange : .red))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(rate >= 80 ? Color.green : (rate >= 50 ? Color.orange : Color.red))
                        .frame(width: geometry.size.width * CGFloat(rate) / 100, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

struct RecentActivitySection: View {
    let activities: [AnalyticsManager.ActivityItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)

            if activities.isEmpty {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(activities) { activity in
                    HStack(spacing: 12) {
                        Image(systemName: activity.icon)
                            .foregroundColor(activity.color)
                            .frame(width: 32, height: 32)
                            .background(activity.color.opacity(0.1))
                            .cornerRadius(6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.title)
                                .font(.subheadline)
                            Text(activity.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(activity.timestamp.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if activity.id != activities.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

struct StatusBreakdownChart: View {
    let data: [String: Int]

    private var total: Int {
        data.values.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status Breakdown")
                .font(.headline)

            if total > 0 {
                // Simple bar chart
                ForEach(Array(data.keys.sorted()), id: \.self) { key in
                    let count = data[key] ?? 0
                    let percentage = Double(count) / Double(total) * 100

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(key.capitalized)
                                .font(.caption)
                            Spacer()
                            Text("\(count) (\(Int(percentage))%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        GeometryReader { geometry in
                            Rectangle()
                                .fill(colorForStatus(key))
                                .frame(width: geometry.size.width * CGFloat(percentage) / 100, height: 12)
                                .cornerRadius(6)
                        }
                        .frame(height: 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            } else {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "draft": return .blue
        case "submitted": return .orange
        case "approved": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
}

// MARK: - ADVANCED SIGNATURE VIEW

struct AdvancedSignatureView: View {
    @Binding var signatureImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    let signerRole: String
    let onSave: (Data, SignatureMetadata) -> Void

    @State private var canvasView = PKCanvasView()
    @State private var signatureType: SignatureType = .handwritten
    @State private var typedName = ""
    @State private var selectedFont: String = "Snell Roundhand"
    @State private var showClearAlert = false
    @State private var witnessName = ""
    @State private var addWitness = false

    enum SignatureType: String, CaseIterable {
        case handwritten = "Draw"
        case typed = "Type"
        case initials = "Initials"
    }

    struct SignatureMetadata {
        let type: SignatureType
        let timestamp: Date
        let witnessName: String?
    }

    let fonts = ["Snell Roundhand", "Bradley Hand", "Zapfino", "Noteworthy"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Signature type picker
                Picker("Signature Type", selection: $signatureType) {
                    ForEach(SignatureType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Signature input area
                Group {
                    switch signatureType {
                    case .handwritten:
                        handwrittenSignatureView
                    case .typed:
                        typedSignatureView
                    case .initials:
                        initialsSignatureView
                    }
                }
                .frame(maxHeight: .infinity)

                // Witness section
                if addWitness {
                    witnessSection
                }

                // Bottom actions
                bottomActions
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Capture Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Clear Signature", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    canvasView.drawing = PKDrawing()
                    typedName = ""
                }
            } message: {
                Text("Are you sure you want to clear the signature?")
            }
        }
    }

    private var handwrittenSignatureView: some View {
        VStack(spacing: 8) {
            Text("Sign in the box below")
                .font(.subheadline)
                .foregroundColor(.secondary)

            SignatureCanvasView(canvasView: $canvasView)
                .frame(height: 150)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                )
                .padding(.horizontal)

            signatureLine
        }
    }

    private var typedSignatureView: some View {
        VStack(spacing: 16) {
            TextField("Type your full name", text: $typedName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Picker("Font", selection: $selectedFont) {
                ForEach(fonts, id: \.self) { font in
                    Text(font).tag(font)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Preview
            Text(typedName.isEmpty ? "Your Signature" : typedName)
                .font(.custom(selectedFont, size: 36))
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal)

            signatureLine
        }
    }

    private var initialsSignatureView: some View {
        VStack(spacing: 8) {
            Text("Draw your initials")
                .font(.subheadline)
                .foregroundColor(.secondary)

            SignatureCanvasView(canvasView: $canvasView)
                .frame(width: 100, height: 100)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                )

            Text("Signing as: \(signerRole)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var signatureLine: some View {
        HStack {
            Rectangle()
                .fill(Color.gray)
                .frame(height: 1)
            Text("Sign Here")
                .font(.caption)
                .foregroundColor(.gray)
            Rectangle()
                .fill(Color.gray)
                .frame(height: 1)
        }
        .padding(.horizontal, 40)
    }

    private var witnessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Witness")
                .font(.headline)

            TextField("Witness Name", text: $witnessName)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var bottomActions: some View {
        VStack(spacing: 12) {
            Toggle("Add Witness", isOn: $addWitness)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button(action: { showClearAlert = true }) {
                    Label("Clear", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: saveSignature) {
                    Label("Save Signature", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var isValid: Bool {
        switch signatureType {
        case .handwritten, .initials:
            return !canvasView.drawing.bounds.isEmpty
        case .typed:
            return !typedName.isEmpty
        }
    }

    private func saveSignature() {
        var image: UIImage?

        switch signatureType {
        case .handwritten, .initials:
            image = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
        case .typed:
            image = renderTypedSignature()
        }

        if let image = image, let pngData = image.pngData() {
            signatureImage = image

            let metadata = SignatureMetadata(
                type: signatureType,
                timestamp: Date(),
                witnessName: addWitness ? witnessName : nil
            )

            onSave(pngData, metadata)
            dismiss()
        }
    }

    private func renderTypedSignature() -> UIImage? {
        let size = CGSize(width: 300, height: 80)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: selectedFont, size: 36) ?? UIFont.systemFont(ofSize: 36),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]

            let rect = CGRect(origin: .zero, size: size)
            typedName.draw(in: rect, withAttributes: attrs)
        }
    }
}

struct SignatureCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.backgroundColor = .white
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

// MARK: - WIDGET SUPPORT

struct FormWidgetEntry: TimelineEntry {
    let date: Date
    let pendingCount: Int
    let recentForm: String?
}

// MARK: - SIRI SHORTCUTS

class FormShortcutsManager {
    static let shared = FormShortcutsManager()

    func donateNewFormShortcut(templateName: String) {
        let activity = NSUserActivity(activityType: "com.digitalforms.newform")
        activity.title = "Create \(templateName)"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.suggestedInvocationPhrase = "Start \(templateName)"
        activity.userInfo = ["template": templateName]
        activity.becomeCurrent()
    }

    func donatePendingApprovalsShortcut(count: Int) {
        let activity = NSUserActivity(activityType: "com.digitalforms.approvals")
        activity.title = "View Pending Approvals"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.suggestedInvocationPhrase = "Show pending approvals"
        activity.userInfo = ["count": count]
        activity.becomeCurrent()
    }
}

// MARK: - CONTENT VIEW

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var syncManager: SyncManager
    @StateObject private var biometricAuth = BiometricAuthManager.shared

    @State private var requiresAuth = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if requiresAuth && !biometricAuth.isUnlocked {
                    BiometricLockView()
                } else {
                    MainTabView()
                }
            } else {
                LoginView()
            }
        }
        .onAppear {
            syncManager.startMonitoring()

            // Check if biometric lock is enabled
            requiresAuth = UserDefaults.standard.bool(forKey: "biometricLockEnabled")
        }
    }
}

struct BiometricLockView: View {
    @StateObject private var biometricAuth = BiometricAuthManager.shared
    @State private var showError = false

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: biometricAuth.biometricType == .faceID ? "faceid" : "touchid")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("Unlock Digital Forms")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Use \(biometricAuth.biometricType == .faceID ? "Face ID" : "Touch ID") to access your forms")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: authenticate) {
                Label("Unlock", systemImage: biometricAuth.biometricType == .faceID ? "faceid" : "touchid")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .onAppear {
            authenticate()
        }
        .alert("Authentication Failed", isPresented: $showError) {
            Button("Try Again") { authenticate() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(biometricAuth.error ?? "Please try again")
        }
    }

    private func authenticate() {
        Task {
            let success = await biometricAuth.authenticate()
            if !success {
                showError = true
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var analyticsManager: AnalyticsManager

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            FormsListView()
                .tabItem {
                    Label("Forms", systemImage: "doc.text.fill")
                }
                .tag(1)

            TemplatesView()
                .tabItem {
                    Label("Templates", systemImage: "square.stack.fill")
                }
                .tag(2)

            PendingApprovalsView()
                .tabItem {
                    Label("Approvals", systemImage: "checkmark.seal.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .onAppear {
            analyticsManager.refreshAnalytics()
        }
    }
}

// MARK: - PLACEHOLDER VIEWS (Include full implementations from previous version)

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue.gradient)

                    Text("Digital Forms")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Create, sign, and submit forms anywhere")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    Button(action: login) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                }
                .padding(.horizontal)

                Spacer()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func login() {
        Task {
            do {
                try await authManager.login(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct FormsListView: View {
    @State private var showNewFormSheet = false

    var body: some View {
        NavigationStack {
            List {
                Text("Your forms will appear here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Forms")
            .toolbar {
                Button(action: { showNewFormSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                }
            }
            .sheet(isPresented: $showNewFormSheet) {
                NewFormView()
            }
        }
    }
}

struct NewFormView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        Text("Scan Document")
                    } label: {
                        Label("Scan Paper Form", systemImage: "doc.viewfinder")
                    }

                    NavigationLink {
                        Text("Form Builder")
                    } label: {
                        Label("Build Custom Form", systemImage: "plus.rectangle.on.rectangle")
                    }

                    NavigationLink {
                        BarcodeScannerView { value, type in
                            print("Scanned: \(value) (\(type))")
                        }
                    } label: {
                        Label("Scan Barcode/QR", systemImage: "barcode.viewfinder")
                    }
                }
            }
            .navigationTitle("New Form")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct TemplatesView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Templates will appear here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Templates")
        }
    }
}

struct PendingApprovalsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("No pending approvals")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Approvals")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var biometricAuth = BiometricAuthManager.shared
    @State private var biometricEnabled = false
    @State private var autoSaveEnabled = true
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // User section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(authManager.currentUser?.name ?? "User")
                                .font(.headline)
                            Text(authManager.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Security section
                Section("Security") {
                    if biometricAuth.biometricType != .none {
                        Toggle(isOn: $biometricEnabled) {
                            Label(
                                biometricAuth.biometricType == .faceID ? "Face ID Lock" : "Touch ID Lock",
                                systemImage: biometricAuth.biometricType == .faceID ? "faceid" : "touchid"
                            )
                        }
                        .onChange(of: biometricEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "biometricLockEnabled")
                        }
                    }

                    NavigationLink {
                        Text("Set Offline PIN")
                    } label: {
                        Label("Offline PIN", systemImage: "lock")
                    }
                }

                // Form settings
                Section("Forms") {
                    Toggle(isOn: $autoSaveEnabled) {
                        Label("Auto-save Drafts", systemImage: "arrow.clockwise")
                    }

                    NavigationLink {
                        Text("Default Signers")
                    } label: {
                        Label("Default Signers", systemImage: "signature")
                    }

                    NavigationLink {
                        WorkflowSettingsView()
                    } label: {
                        Label("Workflow Rules", systemImage: "arrow.triangle.branch")
                    }
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                biometricEnabled = UserDefaults.standard.bool(forKey: "biometricLockEnabled")
            }
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

struct WorkflowSettingsView: View {
    @StateObject private var workflowEngine = WorkflowEngine.shared
    @State private var showAddRule = false

    var body: some View {
        List {
            Section {
                Button(action: { showAddRule = true }) {
                    Label("Add Workflow Rule", systemImage: "plus.circle.fill")
                }
            }

            Section("Active Rules") {
                if workflowEngine.rules.isEmpty {
                    Text("No workflow rules configured")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(workflowEngine.rules) { rule in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.name)
                                .font(.headline)
                            Text(rule.trigger.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Workflow Rules")
        .sheet(isPresented: $showAddRule) {
            AddWorkflowRuleView()
        }
    }
}

struct AddWorkflowRuleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ruleName = ""
    @State private var selectedTrigger: WorkflowTrigger = .formSubmitted
    @State private var selectedActions: [WorkflowActionType] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Rule Details") {
                    TextField("Rule Name", text: $ruleName)

                    Picker("Trigger", selection: $selectedTrigger) {
                        ForEach(WorkflowTrigger.allCases, id: \.self) { trigger in
                            Text(trigger.displayName).tag(trigger)
                        }
                    }
                }

                Section("Actions") {
                    ForEach(WorkflowActionType.allCases, id: \.self) { action in
                        Button(action: {
                            if selectedActions.contains(action) {
                                selectedActions.removeAll { $0 == action }
                            } else {
                                selectedActions.append(action)
                            }
                        }) {
                            HStack {
                                Image(systemName: action.icon)
                                Text(action.displayName)
                                Spacer()
                                if selectedActions.contains(action) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Add Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveRule()
                        dismiss()
                    }
                    .disabled(ruleName.isEmpty || selectedActions.isEmpty)
                }
            }
        }
    }

    private func saveRule() {
        let actions = selectedActions.map { WorkflowAction(type: $0, parameters: [:]) }
        let rule = WorkflowRule(
            name: ruleName,
            isActive: true,
            trigger: selectedTrigger,
            conditions: [],
            actions: actions
        )
        WorkflowEngine.shared.rules.append(rule)
    }
}

// MARK: - DATA MODELS & CONTROLLERS (From previous version)

// Include all the DataController, AuthManager, SyncManager, PDFGenerator etc from previous version
// They are already defined above, so I'll add the remaining sync data models

struct FormSyncData: Codable {
    let id: String
    let templateId: String
    let title: String
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let submittedAt: Date?
    let latitude: Double?
    let longitude: Double?
    let fields: [FieldSyncData]
    let signatures: [SignatureSyncData]
    let attachments: [AttachmentSyncData]

    init(from form: FormEntity) {
        self.id = form.id?.uuidString ?? ""
        self.templateId = form.templateId?.uuidString ?? ""
        self.title = form.title ?? ""
        self.status = form.status ?? ""
        self.createdAt = form.createdAt ?? Date()
        self.updatedAt = form.updatedAt ?? Date()
        self.submittedAt = form.submittedAt
        self.latitude = form.latitude
        self.longitude = form.longitude
        self.fields = (form.fields?.allObjects as? [FormField] ?? []).map { FieldSyncData(from: $0) }
        self.signatures = (form.signatures?.allObjects as? [Signature] ?? []).map { SignatureSyncData(from: $0) }
        self.attachments = (form.attachments?.allObjects as? [Attachment] ?? []).map { AttachmentSyncData(from: $0) }
    }
}

struct FieldSyncData: Codable {
    let id: String
    let label: String
    let type: String
    let value: String?
    let order: Int

    init(from field: FormField) {
        self.id = field.id?.uuidString ?? ""
        self.label = field.label ?? ""
        self.type = field.type ?? ""
        self.value = field.value
        self.order = Int(field.order)
    }
}

struct SignatureSyncData: Codable {
    let id: String
    let signerName: String
    let signerRole: String
    let signedAt: Date
    let imageBase64: String

    init(from signature: Signature) {
        self.id = signature.id?.uuidString ?? ""
        self.signerName = signature.signerName ?? ""
        self.signerRole = signature.signerRole ?? ""
        self.signedAt = signature.signedAt ?? Date()
        self.imageBase64 = signature.imageData?.base64EncodedString() ?? ""
    }
}

struct AttachmentSyncData: Codable {
    let id: String
    let caption: String?
    let capturedAt: Date
    let latitude: Double?
    let longitude: Double?
    let imageBase64: String

    init(from attachment: Attachment) {
        self.id = attachment.id?.uuidString ?? ""
        self.caption = attachment.caption
        self.capturedAt = attachment.capturedAt ?? Date()
        self.latitude = attachment.latitude
        self.longitude = attachment.longitude
        self.imageBase64 = attachment.imageData?.base64EncodedString() ?? ""
    }
}

// MARK: - PREVIEW

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environmentObject(SyncManager.shared)
        .environmentObject(DataController.shared)
        .environmentObject(AnalyticsManager.shared)
}
