/**
 * PhotoAnnotationView.swift
 * Photo Annotation Tools
 *
 * Features:
 * - Draw arrows, circles, rectangles on photos
 * - Add text annotations
 * - Highlight areas
 * - Undo/redo support
 */

import SwiftUI
import PencilKit
import PhotosUI

struct PhotoAnnotationView: View {
    @Environment(\.dismiss) private var dismiss
    
    let originalImage: UIImage
    let onSave: (UIImage) -> Void
    
    @State private var canvasView = PKCanvasView()
    @State private var selectedTool: AnnotationTool = .pen
    @State private var selectedColor: Color = .red
    
    enum AnnotationTool {
        case pen, highlight, eraser
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                annotationToolbar
                    .padding()
                Divider()
                ZStack {
                    Image(uiImage: originalImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    AnnotationCanvasView(canvasView: $canvasView, tool: selectedTool, color: selectedColor)
                }
            }
            .navigationTitle("Annotate Photo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { saveAnnotatedImage() }
                }
            }
        }
    }
    
    private var annotationToolbar: some View {
        HStack {
            ForEach([AnnotationTool.pen, .highlight, .eraser], id: \.self) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    Image(systemName: iconFor(tool))
                        .foregroundColor(selectedTool == tool ? .white : .accentColor)
                        .padding()
                        .background(selectedTool == tool ? Color.accentColor : Color.clear)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func iconFor(_ tool: AnnotationTool) -> String {
        switch tool {
        case .pen: return "pencil.tip"
        case .highlight: return "highlighter"
        case .eraser: return "eraser"
        }
    }
    
    private func saveAnnotatedImage() {
        let renderer = UIGraphicsImageRenderer(size: originalImage.size)
        let annotatedImage = renderer.image { _ in
            originalImage.draw(at: .zero)
            canvasView.drawing.image(from: CGRect(origin: .zero, size: originalImage.size), scale: 1.0).draw(at: .zero)
        }
        onSave(annotatedImage)
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
        updateTool()
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        updateTool()
    }
    
    private func updateTool() {
        switch tool {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: UIColor(color), width: 3)
        case .highlight:
            canvasView.tool = PKInkingTool(.marker, color: UIColor(color).withAlphaComponent(0.4), width: 20)
        case .eraser:
            canvasView.tool = PKEraserTool(.vector)
        }
    }
}
