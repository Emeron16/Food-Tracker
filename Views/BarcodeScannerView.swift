//
//  BarcodeScannerView.swift
//  FreshTrack
//
//  Created by Prince Marcelle on 1/27/26.
//

import SwiftUI

#if os(iOS)
import Vision
import VisionKit

// MARK: - DataScanner UIViewControllerRepresentable

/// UIViewControllerRepresentable wrapper for DataScannerViewController.
/// Provides barcode scanning via the device camera.
struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var shouldStartScanning: Bool
    let onBarcodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [
                .ean13, .ean8, .upce, .code128, .code39, .code93, .itf14
            ])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if shouldStartScanning {
            if !uiViewController.isScanning, DataScannerViewController.isAvailable {
                try? uiViewController.startScanning()
            }
        } else {
            if uiViewController.isScanning {
                uiViewController.stopScanning()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerRepresentable

        init(parent: DataScannerRepresentable) {
            self.parent = parent
        }

        func dataScanner(
            _ scanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard let item = addedItems.first else { return }
            if case .barcode(let barcode) = item {
                if let barcodeValue = barcode.payloadStringValue {
                    scanner.stopScanning()
                    DispatchQueue.main.async {
                        self.parent.shouldStartScanning = false
                        self.parent.onBarcodeScanned(barcodeValue)
                    }
                }
            }
        }
    }
}

// MARK: - Barcode Scanner View

struct BarcodeScannerView: View {
    @Binding var selectedTab: Int
    @Environment(\.modelContext) private var modelContext
    @State private var scannedProduct: ScannedProduct? = nil
    @State private var scannedBarcodeOnly: String? = nil
    @State private var isShowingAddGrocery = false
    @State private var isLookingUp = false
    @State private var showNotFoundAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var lastScannedBarcode: String? = nil
    @State private var isScanningActive = false

    var body: some View {
        NavigationStack {
            ZStack {
                if DataScannerViewController.isSupported {
                    DataScannerRepresentable(
                        shouldStartScanning: $isScanningActive,
                        onBarcodeScanned: handleBarcode
                    )
                    .ignoresSafeArea()

                    // Scanning overlay
                    VStack {
                        Spacer()

                        if isLookingUp {
                            lookingUpOverlay
                        } else {
                            scanPromptOverlay
                        }
                    }
                    .padding(.bottom, 40)
                } else {
                    cameraUnavailableView
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingAddGrocery, onDismiss: resetScanner) {
                if let product = scannedProduct {
                    AddGroceryView(scannedProduct: product)
                } else {
                    AddGroceryView(scannedProduct: nil, barcode: scannedBarcodeOnly)
                }
            }
            .alert("Product Not Found", isPresented: $showNotFoundAlert) {
                Button("Add Manually") {
                    scannedBarcodeOnly = lastScannedBarcode
                    scannedProduct = nil
                    isShowingAddGrocery = true
                }
                Button("Scan Again", role: .cancel) {
                    resetScanner()
                }
            } message: {
                Text("This barcode wasn't found in our database. Would you like to add the item manually?")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("Try Again", role: .cancel) {
                    resetScanner()
                }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab == 1 {
                    // Scanner tab selected - restart scanning
                    resetScanner()
                } else {
                    // Left scanner tab - stop scanning
                    isScanningActive = false
                }
            }
            .onAppear {
                // Initial appearance
                if selectedTab == 1 {
                    resetScanner()
                }
            }
        }
    }

    // MARK: - Barcode Handler

    private func handleBarcode(_ barcode: String) {
        guard barcode != lastScannedBarcode else { return }
        lastScannedBarcode = barcode

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        isLookingUp = true
        Task {
            do {
                if let product = try await BarcodeAPIService.shared.lookupBarcode(barcode) {
                    scannedProduct = product
                    scannedBarcodeOnly = nil
                    isShowingAddGrocery = true
                } else {
                    showNotFoundAlert = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
            isLookingUp = false
        }
    }

    private func resetScanner() {
        lastScannedBarcode = nil
        scannedProduct = nil
        scannedBarcodeOnly = nil
        isScanningActive = true
    }

    // MARK: - Overlays

    private var lookingUpOverlay: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Looking up product...")
                .foregroundStyle(.white)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
    }

    private var scanPromptOverlay: some View {
        Text("Point camera at a barcode")
            .foregroundStyle(.white)
            .fontWeight(.medium)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
    }

    private var cameraUnavailableView: some View {
        ContentUnavailableView {
            Label("Camera Unavailable", systemImage: "camera.fill")
        } description: {
            Text("Barcode scanning requires a device with a camera.")
        }
    }

}

#endif
