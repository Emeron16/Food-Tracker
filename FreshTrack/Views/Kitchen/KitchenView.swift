//
//  KitchenView.swift
//  FreshTrack
//

import SwiftUI
import SwiftData
import SceneKit

// MARK: - Wall Style

enum KitchenWallStyle: String, CaseIterable, Hashable {
    case standard = "Standard"
    case modern   = "Modern"
    case scenic   = "Scenic"

    var icon: String {
        switch self {
        case .standard: return "paintbrush"
        case .modern:   return "square.grid.3x3.fill"
        case .scenic:   return "mountain.2.fill"
        }
    }

    var description: String {
        switch self {
        case .standard: return "Warm beige plaster"
        case .modern:   return "White subway tile backsplash"
        case .scenic:   return "Window view with waterfall & park"
        }
    }
}

// MARK: - SceneKit UIViewRepresentable

struct KitchenSceneView: UIViewRepresentable {
    let scene: SCNScene
    let onItemTapped: (String) -> Void       // passes grocery ID string
    let onApplianceTapped: (StorageLocation) -> Void

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = UIColor(red: 0.72, green: 0.72, blue: 0.74, alpha: 1)

        // Configure camera controller to orbit around the kitchen center,
        // not the SceneKit world origin. automaticTarget = false locks the
        // target to our explicit point so one-finger drag rotates around
        // the entire kitchen rather than drifting toward the origin.
        let ctrl = view.defaultCameraController
        ctrl.interactionMode = .orbitTurntable
        ctrl.target = SCNVector3(0, 1.8, -5)
        ctrl.automaticTarget = false
        ctrl.minimumVerticalAngle = -5
        ctrl.maximumVerticalAngle = 75

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Sync scene reference but do NOT reset pointOfView — that would snap
        // the camera back every time SwiftUI re-renders.
        if uiView.scene !== scene {
            uiView.scene = scene
        }
        // On first render the camera node exists; bind it so the controller
        // knows which camera to move. Subsequent calls are no-ops (same node).
        if uiView.pointOfView == nil,
           let camera = scene.rootNode.childNode(withName: "mainCamera", recursively: false) {
            uiView.pointOfView = camera
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onItemTapped: onItemTapped, onApplianceTapped: onApplianceTapped)
    }

    class Coordinator: NSObject {
        let onItemTapped: (String) -> Void
        let onApplianceTapped: (StorageLocation) -> Void

        init(onItemTapped: @escaping (String) -> Void,
             onApplianceTapped: @escaping (StorageLocation) -> Void) {
            self.onItemTapped = onItemTapped
            self.onApplianceTapped = onApplianceTapped
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let sceneView = gesture.view as? SCNView else { return }
            let location = gesture.location(in: sceneView)
            let hits = sceneView.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])

            for hit in hits {
                guard let name = hit.node.name else { continue }

                if name.hasPrefix("item.") {
                    let id = String(name.dropFirst("item.".count))
                    onItemTapped(id)
                    return
                }

                if name.hasPrefix("appliance.") {
                    let locationRaw = String(name.dropFirst("appliance.".count)).capitalized
                    if let loc = StorageLocation.allCases.first(where: { $0.rawValue.lowercased() == locationRaw.lowercased() }) {
                        onApplianceTapped(loc)
                    }
                    return
                }
            }
        }
    }
}

// MARK: - KitchenView

struct KitchenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Grocery> { !$0.isConsumed },
        sort: \Grocery.createdAt,
        order: .reverse
    ) private var activeGroceries: [Grocery]

    @AppStorage("kitchen.wallStyle") private var wallStyleRaw: String = KitchenWallStyle.standard.rawValue
    private var wallStyle: KitchenWallStyle {
        KitchenWallStyle(rawValue: wallStyleRaw) ?? .standard
    }

    @State private var scene = SCNScene()
    @State private var selectedGrocery: Grocery?
    @State private var selectedZone: StorageLocation?
    @State private var showingAddGrocery = false
    @State private var showingWallPicker = false

    var body: some View {
        NavigationStack {
            KitchenSceneView(
                scene: scene,
                onItemTapped: { idString in
                    let match = activeGroceries.first {
                        $0.notificationIdentifier == idString
                    }
                    if let match { selectedGrocery = match }
                },
                onApplianceTapped: { zone in
                    selectedZone = zone
                }
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Kitchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingWallPicker = true
                    } label: {
                        Image(systemName: "paintpalette")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddGrocery = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#endif
            }
            .sheet(item: $selectedGrocery) { grocery in
                EditGroceryView(grocery: grocery)
            }
            .sheet(item: $selectedZone) { zone in
                KitchenZoneDetailSheet(location: zone)
            }
            .sheet(isPresented: $showingAddGrocery) {
                AddGroceryView()
            }
            .sheet(isPresented: $showingWallPicker) {
                WallStylePickerSheet(selected: wallStyleRaw) { chosen in
                    wallStyleRaw = chosen.rawValue
                    KitchenSceneBuilder.shared.applyWallStyle(chosen, to: scene)
                }
            }
        }
        .onAppear {
            KitchenSceneBuilder.shared.buildScene(scene, groceries: activeGroceries)
            KitchenSceneBuilder.shared.applyWallStyle(wallStyle, to: scene)
        }
        .onChange(of: activeGroceries) {
            KitchenSceneBuilder.shared.buildScene(scene, groceries: activeGroceries)
        }
        .onReceive(NotificationCenter.default.publisher(for: .groceriesDidChange)) { _ in
            KitchenSceneBuilder.shared.buildScene(scene, groceries: activeGroceries)
        }
    }
}

// MARK: - Wall Style Picker Sheet

private struct WallStylePickerSheet: View {
    let selected: String
    let onSelect: (KitchenWallStyle) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(KitchenWallStyle.allCases, id: \.rawValue) { style in
                    WallStyleRow(style: style, isSelected: style.rawValue == selected) {
                        onSelect(style)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Wall Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

private struct WallStyleRow: View {
    let style: KitchenWallStyle
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: style.icon)
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(style.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
            .padding(.vertical, 4)
        }
    }
}


#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Grocery.self, configurations: config)
    return KitchenView()
        .modelContainer(container)
}
