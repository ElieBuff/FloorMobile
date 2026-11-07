//
//  SignaturePad.swift
//  FloorMobile
//

import PencilKit
import SwiftUI

/// Where a person signs with their finger, or a Pencil: black ink on white,
/// above a baseline. The drawing goes out through `drawing`, and setting it
/// empty clears the pad.
///
/// PencilKit's canvas, since SwiftUI has no drawing surface: one pen, no tool
/// palette — a signature needs neither colours nor an eraser, "Clear" starts
/// again. Forced light: PencilKit turns black ink white in dark mode, which
/// on the pad's white ground would be invisible. Turn the drawing into the
/// image that is sent with `PKDrawing.signaturePNG(scale:)`.
struct SignaturePad: View {
    @Binding var drawing: PKDrawing

    var body: some View {
        PencilCanvas(drawing: $drawing)
            .background(.white)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(.OnSurface.borderSubtle))
                    .frame(height: 1)
                    .padding(.horizontal, AppSpacing.cardInset)
                    .padding(.bottom, 48)
                    .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: AppRadius.large, style: .continuous))
            .accessibilityElement()
            // Under VoiceOver, a finger draws instead of swiping to the next element.
            .accessibilityAddTraits(.allowsDirectInteraction)
            .accessibilityLabel(String(localized: "Signature area"))
            .accessibilityHint(String(localized: "Ask the client to sign with their finger"))
    }

    /// The PencilKit canvas itself, set up for a signature.
    private struct PencilCanvas: UIViewRepresentable {
        @Binding var drawing: PKDrawing

        func makeUIView(context: Context) -> PKCanvasView {
            let canvas = PKCanvasView()
            canvas.drawingPolicy = .anyInput
            canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
            canvas.backgroundColor = .white
            canvas.isOpaque = true
            canvas.overrideUserInterfaceStyle = .light
            canvas.isScrollEnabled = false
            canvas.drawing = drawing
            canvas.delegate = context.coordinator
            return canvas
        }

        func updateUIView(_ canvas: PKCanvasView, context: Context) {
            // Only when the binding changed from outside — "Clear" — never
            // back onto the strokes the canvas just reported.
            if canvas.drawing != drawing {
                canvas.drawing = drawing
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(drawing: $drawing)
        }

        /// Hands each stroke back to the binding.
        final class Coordinator: NSObject, PKCanvasViewDelegate {
            private let drawing: Binding<PKDrawing>

            init(drawing: Binding<PKDrawing>) {
                self.drawing = drawing
            }

            func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
                drawing.wrappedValue = canvas.drawing
            }
        }
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var drawing = PKDrawing()

    VStack(spacing: 12) {
        SignaturePad(drawing: $drawing)
            .frame(height: 220)
        Button("Clear") { drawing = PKDrawing() }
    }
    .padding(24)
    .background(Color(.Base.canvas))
}
