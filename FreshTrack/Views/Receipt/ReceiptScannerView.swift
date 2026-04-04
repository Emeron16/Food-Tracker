//
//  ReceiptScannerView.swift
//  FreshTrack
//
//  Camera / photo picker entry point for receipt scanning.
//

import SwiftUI

struct ReceiptScannerView: View {
    @StateObject private var service = ReceiptScannerService()
    @Environment(\.dismiss) private var dismiss
    @State private var imagePickerSourceType: UIImagePickerController.SourceType? = nil
    @State private var navigateToReview = false

    var body: some View {
        NavigationStack {
            Group {
                if service.isProcessing {
                    processingView
                } else if let image = service.selectedImage {
                    previewView(image: image)
                } else {
                    welcomeView
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(item: $imagePickerSourceType) { source in
                ImagePicker(sourceType: source) { image in
                    service.selectedImage = image
                }
                .ignoresSafeArea()
            }
            .navigationDestination(isPresented: $navigateToReview) {
                ReceiptReviewView(service: service, onDone: { dismiss() })
                    .onDisappear {
                        // Reset when user navigates back so re-scanning works
                        navigateToReview = false
                        service.reset()
                    }
            }
            .onChange(of: service.processingComplete) {
                if service.processingComplete {
                    navigateToReview = true
                }
            }
            .alert("Scan Failed", isPresented: Binding(
                get: { service.errorMessage != nil },
                set: { if !$0 { service.errorMessage = nil } }
            )) {
                Button("OK") { service.errorMessage = nil }
            } message: {
                Text(service.errorMessage ?? "")
            }
        }
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Scan a Receipt")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Photograph a grocery receipt to bulk-add items to your pantry.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
#if targetEnvironment(simulator)
                Button {
                    imagePickerSourceType = .photoLibrary
                } label: {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
#else
                Button {
                    imagePickerSourceType = .camera
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)

                Button {
                    imagePickerSourceType = .photoLibrary
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal)
#endif
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Image Preview

    private func previewView(image: UIImage) -> some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 400)
                .clipped()
                .padding()

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await service.processReceipt() }
                } label: {
                    Label("Scan This Receipt", systemImage: "doc.text.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)

                Button {
                    service.reset()
                } label: {
                    Text("Choose Different Photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Reading receipt...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - UIImagePickerController.SourceType + Identifiable

extension UIImagePickerController.SourceType: @retroactive Identifiable {
    public var id: Int { rawValue }
}

// MARK: - ImagePicker

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
