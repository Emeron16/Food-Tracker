//
//  KitchenSceneBuilder.swift
//  FreshTrack
//

import SceneKit
import SwiftData
import UIKit


final class KitchenSceneBuilder {
    static let shared = KitchenSceneBuilder()
    private init() {}

    private var textureCache: [String: UIImage] = [:]
    private var renderedIDs: Set<String> = []

    // MARK: - Stable ID
    private func stableID(_ grocery: Grocery) -> String {
        grocery.notificationIdentifier
    }

    static func itemNodeName(for id: String) -> String { "item.\(id)" }
    static func applianceNodeName(for location: StorageLocation) -> String {
        "appliance.\(location.rawValue.lowercased())"
    }

    // MARK: - Build full scene
    func buildScene(_ scene: SCNScene, groceries: [Grocery]) {
        // First build: construct everything from scratch
        if scene.rootNode.childNode(withName: "mainCamera", recursively: false) == nil {
            scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
            renderedIDs.removeAll()
            setupLighting(in: scene)
            setupCamera(in: scene)
            buildRoom(in: scene)
            buildAppliances(in: scene)
        }
        // Subsequent calls (triggered by property changes): only replace food items
        refreshItems(scene, groceries: groceries)
    }

    // Clears and replaces all food item nodes across every appliance zone.
    // Does NOT touch camera, lighting, room, or appliance geometry.
    private func refreshItems(_ scene: SCNScene, groceries: [Grocery]) {
        renderedIDs.removeAll()
        let grouped = Dictionary(grouping: groceries) { $0.storageLocation }
        for location in StorageLocation.allCases {
            let items = (grouped[location] ?? []).sorted {
                ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999)
            }
            placeItems(items, on: location, in: scene)
        }
        renderedIDs = Set(groceries.map { stableID($0) })
    }

    // MARK: - Incremental update
    func updateScene(_ scene: SCNScene, with groceries: [Grocery]) {
        let currentIDs = Set(groceries.map { stableID($0) })

        for oldID in renderedIDs where !currentIDs.contains(oldID) {
            scene.rootNode.childNode(withName: Self.itemNodeName(for: oldID), recursively: true)?
                .removeFromParentNode()
        }

        let grouped = Dictionary(grouping: groceries) { $0.storageLocation }
        for location in StorageLocation.allCases {
            let items = (grouped[location] ?? []).sorted {
                ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999)
            }
            placeItems(items, on: location, in: scene)
        }

        renderedIDs = currentIDs
    }

    // MARK: - Lighting
    private func setupLighting(in scene: SCNScene) {
        func addLight(name: String, type: SCNLight.LightType,
                      intensity: CGFloat, color: UIColor,
                      position: SCNVector3 = .init(0,0,0),
                      euler: SCNVector3 = .init(0,0,0)) {
            let node = SCNNode()
            let light = SCNLight()
            light.type = type
            light.intensity = intensity
            light.color = color
            node.light = light
            node.name = name
            node.position = position
            node.eulerAngles = euler
            scene.rootNode.addChildNode(node)
        }

        // Ambient — balanced brightness for the whole room
        addLight(name: "light.ambient", type: .ambient,
                 intensity: 600, color: UIColor(white: 1.0, alpha: 1))

        // Warm directional key from upper front
        addLight(name: "light.key", type: .directional,
                 intensity: 400, color: UIColor(red: 1.0, green: 0.97, blue: 0.90, alpha: 1),
                 position: SCNVector3(4, 10, 10),
                 euler: SCNVector3(-0.5, 0.3, 0))

        // Cool fill from the left
        addLight(name: "light.fill", type: .directional,
                 intensity: 200, color: UIColor(red: 0.90, green: 0.93, blue: 1.0, alpha: 1),
                 position: SCNVector3(-8, 6, 4),
                 euler: SCNVector3(-0.3, -0.4, 0))
    }

    // MARK: - Camera
    func setupCamera(in scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.name = "mainCamera"
        let camera = SCNCamera()
        camera.fieldOfView = 55
        camera.zNear = 0.1
        camera.zFar = 200
        camera.wantsHDR = false
        cameraNode.camera = camera
        // Wide isometric-ish shot encompassing whole kitchen
        cameraNode.position = SCNVector3(0, 8, 16)
        cameraNode.eulerAngles = SCNVector3(-0.45, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
    }

    // MARK: - Room
    private func buildRoom(in scene: SCNScene) {
        // Floor with subtle tile pattern
        let floorGeo = SCNFloor()
        floorGeo.reflectivity = 0.06
        floorGeo.reflectionFalloffEnd = 8
        let floorMat = SCNMaterial()
        floorMat.lightingModel = .lambert
        floorMat.diffuse.contents = checkerboardImage(
            size: CGSize(width: 512, height: 512),
            color1: UIColor(red: 0.94, green: 0.92, blue: 0.88, alpha: 1),
            color2: UIColor(red: 0.88, green: 0.86, blue: 0.82, alpha: 1),
            tiles: 8
        )
        floorGeo.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floorGeo))

        // Back wall
        let wallGeo = SCNPlane(width: 34, height: 12)
        wallGeo.materials = [wallMaterial(for: .standard)]
        let wallNode = SCNNode(geometry: wallGeo)
        wallNode.name = "backWall"
        wallNode.position = SCNVector3(0, 6, -8.1)
        scene.rootNode.addChildNode(wallNode)

        // Baseboard / floor trim strip
        let baseGeo = SCNBox(width: 34, height: 0.12, length: 0.12, chamferRadius: 0.02)
        let baseMat = SCNMaterial()
        baseMat.lightingModel = .physicallyBased
        baseMat.diffuse.contents = UIColor(white: 0.92, alpha: 1)
        baseMat.roughness.contents = 0.3
        baseGeo.materials = [baseMat]
        let baseNode = SCNNode(geometry: baseGeo)
        baseNode.position = SCNVector3(0, 0.06, -8.0)
        scene.rootNode.addChildNode(baseNode)
    }

    // MARK: - Appliances (PBR)
    private func buildAppliances(in scene: SCNScene) {
        // Fridge
        addAppliance(to: scene, location: .refrigerator,
                     size: SCNVector3(2.0, 3.2, 1.0),
                     position: SCNVector3(-7.0, 1.6, -7.0),
                     diffuse: UIColor(red: 0.82, green: 0.84, blue: 0.87, alpha: 1),
                     metalness: 0.55, roughness: 0.25,
                     label: "Fridge")

        // Freezer
        addAppliance(to: scene, location: .freezer,
                     size: SCNVector3(1.6, 2.4, 1.0),
                     position: SCNVector3(-4.5, 1.2, -7.0),
                     diffuse: UIColor(red: 0.78, green: 0.88, blue: 0.96, alpha: 1),
                     metalness: 0.45, roughness: 0.30,
                     label: "Freezer")

        // Pantry cabinet
        addAppliance(to: scene, location: .pantry,
                     size: SCNVector3(2.4, 3.4, 1.0),
                     position: SCNVector3(7.0, 1.7, -7.0),
                     diffuse: UIColor(red: 0.56, green: 0.38, blue: 0.20, alpha: 1),
                     metalness: 0.05, roughness: 0.80,
                     label: "Pantry")
        addPantryCabinets(to: scene)

        // Counter top (marble look)
        addAppliance(to: scene, location: .counter,
                     size: SCNVector3(7.0, 0.15, 1.4),
                     position: SCNVector3(0, 1.05, -3.5),
                     diffuse: marbleImage(size: CGSize(width: 512, height: 256)),
                     metalness: 0.05, roughness: 0.18,
                     label: "Counter")

        // Counter base cabinet
        let baseGeo = SCNBox(width: 6.8, height: 1.0, length: 1.2, chamferRadius: 0.04)
        let baseMat = SCNMaterial()
        baseMat.lightingModel = .physicallyBased
        baseMat.diffuse.contents = UIColor(red: 0.52, green: 0.47, blue: 0.41, alpha: 1)
        baseMat.roughness.contents = 0.75
        baseMat.metalness.contents = 0.02
        baseGeo.materials = [baseMat]
        let baseNode = SCNNode(geometry: baseGeo)
        baseNode.position = SCNVector3(0, 0.5, -3.5)
        scene.rootNode.addChildNode(baseNode)

        // Counter handles (small metallic bars)
        addCounterHandles(to: scene)
    }

    private func addAppliance(to scene: SCNScene, location: StorageLocation,
                               size: SCNVector3, position: SCNVector3,
                               diffuse: Any, metalness: Double, roughness: Double,
                               label: String) {
        let geo = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y),
                         length: CGFloat(size.z), chamferRadius: 0.06)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = diffuse
        mat.metalness.contents = metalness
        mat.roughness.contents = roughness
        geo.materials = [mat]

        let node = SCNNode(geometry: geo)
        node.name = Self.applianceNodeName(for: location)
        node.position = position
        scene.rootNode.addChildNode(node)

        addLabel(label, above: node, applianceHeight: size.y, scene: scene)

        // Handle bar on fridge/freezer/pantry
        if location != .counter {
            addHandle(to: node, applianceSize: size)
        }
    }

    private func addHandle(to applianceNode: SCNNode, applianceSize: SCNVector3) {
        let handleGeo = SCNBox(width: 0.08, height: CGFloat(applianceSize.y) * 0.35,
                               length: 0.08, chamferRadius: 0.03)
        let handleMat = SCNMaterial()
        handleMat.lightingModel = .physicallyBased
        handleMat.diffuse.contents = UIColor(red: 0.70, green: 0.70, blue: 0.72, alpha: 1)
        handleMat.metalness.contents = 0.95
        handleMat.roughness.contents = 0.10
        handleGeo.materials = [handleMat]
        let handleNode = SCNNode(geometry: handleGeo)
        handleNode.position = SCNVector3(Float(applianceSize.x) * 0.38,
                                         Float(applianceSize.y) * 0.08,
                                         Float(applianceSize.z) * 0.56)
        applianceNode.addChildNode(handleNode)
    }

    private func addPantryCabinets(to scene: SCNScene) {
        // Add decorative door panels to pantry
        for i in 0..<2 {
            let panelGeo = SCNPlane(width: 0.9, height: 1.4)
            let panelMat = SCNMaterial()
            panelMat.lightingModel = .physicallyBased
            panelMat.diffuse.contents = UIColor(red: 0.50, green: 0.34, blue: 0.17, alpha: 1)
            panelMat.roughness.contents = 0.85
            panelMat.metalness.contents = 0.02
            panelGeo.materials = [panelMat]
            let panelNode = SCNNode(geometry: panelGeo)
            panelNode.position = SCNVector3(Float(i) * 1.0 - 0.5, 0.3, 0.52)
            scene.rootNode.childNode(withName: Self.applianceNodeName(for: .pantry), recursively: false)?
                .addChildNode(panelNode)
        }
    }

    private func addCounterHandles(to scene: SCNScene) {
        let positions: [Float] = [-2.8, -0.9, 0.9, 2.8]
        guard let baseNode = scene.rootNode.childNodes.first(where: { $0.position.y < 0.8 && $0.position.z < -3 }) else { return }
        _ = baseNode // suppress unused warning
        for x in positions {
            let hGeo = SCNBox(width: 0.5, height: 0.06, length: 0.06, chamferRadius: 0.02)
            let hMat = SCNMaterial()
            hMat.lightingModel = .physicallyBased
            hMat.diffuse.contents = UIColor(red: 0.60, green: 0.60, blue: 0.62, alpha: 1)
            hMat.metalness.contents = 0.90
            hMat.roughness.contents = 0.15
            hGeo.materials = [hMat]
            let hNode = SCNNode(geometry: hGeo)
            hNode.position = SCNVector3(x, 1.0, -2.9)
            scene.rootNode.addChildNode(hNode)
        }
    }

    private func addLabel(_ text: String, above node: SCNNode,
                           applianceHeight: Float, scene: SCNScene) {
        let textGeo = SCNText(string: text, extrusionDepth: 0.02)
        textGeo.font = UIFont.systemFont(ofSize: 0.28, weight: .semibold)
        textGeo.flatness = 0.004
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(white: 0.18, alpha: 1)
        textGeo.materials = [mat]

        let textNode = SCNNode(geometry: textGeo)
        let (minB, maxB) = textNode.boundingBox
        let dx = (maxB.x - minB.x) / 2
        textNode.pivot = SCNMatrix4MakeTranslation(dx, 0, 0)
        textNode.position = SCNVector3(
            node.position.x,
            node.position.y + applianceHeight / 2 + 0.18,
            node.position.z + 0.52
        )
        scene.rootNode.addChildNode(textNode)
    }

    // MARK: - Place food item planes
    private func placeItems(_ items: [Grocery], on location: StorageLocation, in scene: SCNScene) {
        guard let applianceNode = scene.rootNode.childNode(
            withName: Self.applianceNodeName(for: location), recursively: false) else { return }

        applianceNode.childNodes
            .filter { $0.name?.hasPrefix("item.") == true || $0.name == "overflow.label" }
            .forEach { $0.removeFromParentNode() }

        let maxVisible = 12
        let visible = Array(items.prefix(maxVisible))
        let overflow = items.count - visible.count
        let cols = 4
        let tileSize: Float = 0.44
        let padding: Float = 0.08

        for (i, grocery) in visible.enumerated() {
            let col = i % cols
            let row = i / cols
            let itemNode = makeItemPlane(grocery: grocery, location: location,
                                         col: col, row: row, tileSize: tileSize, padding: padding)
            applianceNode.addChildNode(itemNode)
            loadTexture(for: grocery, into: itemNode)
        }

        if overflow > 0 {
            let usedRows = (visible.count + cols - 1) / cols
            addOverflowLabel("+\(overflow) more", to: applianceNode,
                             rows: usedRows, tileSize: tileSize, padding: padding)
        }
    }

    private func makeItemPlane(grocery: Grocery, location: StorageLocation,
                                col: Int, row: Int,
                                tileSize: Float, padding: Float) -> SCNNode {
        let step = tileSize + padding
        let startX: Float = -1.5 * step

        switch location {
        case .counter:
            // Delegate to the 3D compound-shape builder
            return makeItemNode3D(grocery: grocery, col: col, row: row,
                                  tileSize: tileSize, padding: padding)

        case .refrigerator, .freezer, .pantry:
            // Flat image plane on vertical appliance face — unchanged
            let symbolImage = coloredSymbolImage(for: grocery.category.icon,
                                                  tint: tintColor(for: grocery.category),
                                                  size: CGSize(width: 128, height: 128))
            let plane = SCNPlane(width: CGFloat(tileSize), height: CGFloat(tileSize))
            plane.cornerRadius = 0.06
            let mat = SCNMaterial()
            mat.diffuse.contents = symbolImage
            mat.isDoubleSided = true
            mat.lightingModel = .constant
            if grocery.expirationStatus == .critical {
                mat.emission.contents = UIColor.red.withAlphaComponent(0.15)
            } else if grocery.expirationStatus == .expired {
                mat.transparency = 0.55
            }
            plane.materials = [mat]
            let node = SCNNode(geometry: plane)
            node.name = Self.itemNodeName(for: stableID(grocery))
            node.position = SCNVector3(
                startX + Float(col) * step,
                0.9 - Float(row) * step,
                0.52
            )
            return node
        }
    }

    // MARK: - 3D counter item

    private func makeItemNode3D(grocery: Grocery, col: Int, row: Int,
                                 tileSize: Float, padding: Float) -> SCNNode {
        let step = tileSize + padding
        let startX: Float = -1.5 * step

        let root = SCNNode()
        root.name = Self.itemNodeName(for: stableID(grocery))

        let shapeGroup = categoryShapeNode(for: grocery, tileSize: tileSize)
        propagateItemName(root.name!, to: shapeGroup)
        applyExpirationEffect(status: grocery.expirationStatus, to: shapeGroup)
        root.addChildNode(shapeGroup)

        let h = shapeHeight(for: resolveShapeType(for: grocery))
        root.position = SCNVector3(
            startX + Float(col) * step,
            0.095 + h / 2,
            -0.25 + Float(row) * step
        )
        return root
    }

    // MARK: - Food shape type — drives both geometry and color

    /// Describes the visual shape class for a food item, resolved from name then category.
    private enum FoodShapeType {
        // Round fruits / vegetables
        case roundFruit(color: UIColor)      // apple, peach, plum, nectarine, kiwi…
        case citrus(color: UIColor)          // orange, lemon, lime, grapefruit
        case berry(color: UIColor)           // strawberry, tomato, cherry, grape
        // Elongated produce
        case banana
        case carrot
        case broccoli
        case corn
        // Packaged / dairy
        case milkCarton(color: UIColor)      // milk, oat milk, almond milk
        case bottle(color: UIColor)          // water, juice, soda, wine
        case can(color: UIColor)             // canned goods, soda can, beer
        case egg
        // Meat / protein
        case meatPackage(color: UIColor)
        case fish
        // Bakery
        case breadLoaf
        case baguette
        // Generic fallbacks
        case flatBox(color: UIColor)         // frozen meals, packaged items
        case tallBox(color: UIColor)         // cereal, pasta boxes
        case bag(color: UIColor)             // chips, snack bags
        case squeezeBottle(color: UIColor)   // condiment bottles
        case genericSphere(color: UIColor)   // anything else round
    }

    /// Resolve the best FoodShapeType for a grocery item.
    /// Checks name keywords first (most specific), then falls back to category.
    private func resolveShapeType(for grocery: Grocery) -> FoodShapeType {
        let n = grocery.name.lowercased()
        let cat = grocery.category

        // ── Round fruits ──────────────────────────────────────────────────
        if n.contains("apple")  { return .roundFruit(color: UIColor(red:0.85,green:0.15,blue:0.10,alpha:1)) }
        if n.contains("peach")  { return .roundFruit(color: UIColor(red:0.95,green:0.55,blue:0.25,alpha:1)) }
        if n.contains("plum")   { return .roundFruit(color: UIColor(red:0.45,green:0.10,blue:0.45,alpha:1)) }
        if n.contains("cherry") { return .berry(color:  UIColor(red:0.80,green:0.08,blue:0.12,alpha:1)) }
        if n.contains("grape")  { return .berry(color:  UIColor(red:0.45,green:0.12,blue:0.65,alpha:1)) }
        if n.contains("strawberry") { return .berry(color: UIColor(red:0.90,green:0.15,blue:0.18,alpha:1)) }
        if n.contains("tomato") { return .berry(color:  UIColor(red:0.88,green:0.18,blue:0.10,alpha:1)) }
        if n.contains("kiwi")   { return .roundFruit(color: UIColor(red:0.20,green:0.58,blue:0.12,alpha:1)) }
        if n.contains("mango")  { return .roundFruit(color: UIColor(red:0.95,green:0.60,blue:0.10,alpha:1)) }
        if n.contains("avocado"){ return .roundFruit(color: UIColor(red:0.22,green:0.38,blue:0.14,alpha:1)) }
        if n.contains("pear")   { return .roundFruit(color: UIColor(red:0.70,green:0.82,blue:0.22,alpha:1)) }

        // ── Citrus ────────────────────────────────────────────────────────
        if n.contains("orange")     { return .citrus(color: UIColor(red:0.95,green:0.50,blue:0.08,alpha:1)) }
        if n.contains("lemon")      { return .citrus(color: UIColor(red:0.96,green:0.90,blue:0.18,alpha:1)) }
        if n.contains("lime")       { return .citrus(color: UIColor(red:0.35,green:0.78,blue:0.22,alpha:1)) }
        if n.contains("grapefruit") { return .citrus(color: UIColor(red:0.95,green:0.45,blue:0.40,alpha:1)) }
        if n.contains("tangerine") || n.contains("mandarin") {
            return .citrus(color: UIColor(red:0.95,green:0.55,blue:0.12,alpha:1))
        }

        // ── Elongated produce ─────────────────────────────────────────────
        if n.contains("banana")  { return .banana }
        if n.contains("carrot")  { return .carrot }
        if n.contains("broccoli") || n.contains("cauliflower") { return .broccoli }
        if n.contains("corn")    { return .corn }

        // ── Dairy ─────────────────────────────────────────────────────────
        if n.contains("milk") || n.contains("oat milk") || n.contains("almond milk") ||
           n.contains("cream") || n.contains("half and half") {
            return .milkCarton(color: UIColor(red:0.92,green:0.94,blue:0.97,alpha:1))
        }
        if n.contains("egg") || n.contains("eggs") { return .egg }
        if n.contains("cheese") || n.contains("butter") || n.contains("yogurt") ||
           n.contains("sour cream") || n.contains("cream cheese") {
            return .flatBox(color: UIColor(red:0.95,green:0.88,blue:0.55,alpha:1))
        }

        // ── Beverages ─────────────────────────────────────────────────────
        if n.contains("water")   { return .bottle(color: UIColor(red:0.75,green:0.88,blue:0.97,alpha:1)) }
        if n.contains("juice")   { return .bottle(color: UIColor(red:0.95,green:0.65,blue:0.15,alpha:1)) }
        if n.contains("soda") || n.contains("cola") || n.contains("sprite") || n.contains("pepsi") {
            return .can(color: UIColor(red:0.80,green:0.10,blue:0.10,alpha:1))
        }
        if n.contains("beer") || n.contains("ale") || n.contains("lager") {
            return .can(color: UIColor(red:0.85,green:0.68,blue:0.15,alpha:1))
        }
        if n.contains("wine")    { return .bottle(color: UIColor(red:0.55,green:0.10,blue:0.30,alpha:1)) }
        if n.contains("coffee")  { return .can(color: UIColor(red:0.32,green:0.18,blue:0.08,alpha:1)) }
        if n.contains("tea")     { return .bottle(color: UIColor(red:0.40,green:0.65,blue:0.35,alpha:1)) }

        // ── Meat & seafood ────────────────────────────────────────────────
        if n.contains("chicken") || n.contains("beef") || n.contains("pork") ||
           n.contains("steak") || n.contains("turkey") || n.contains("lamb") ||
           n.contains("sausage") || n.contains("bacon") || n.contains("ham") {
            return .meatPackage(color: UIColor(red:0.78,green:0.25,blue:0.22,alpha:1))
        }
        if n.contains("fish") || n.contains("salmon") || n.contains("tuna") ||
           n.contains("shrimp") || n.contains("lobster") || n.contains("crab") ||
           n.contains("tilapia") || n.contains("cod") || n.contains("halibut") {
            return .fish
        }

        // ── Bakery ────────────────────────────────────────────────────────
        if n.contains("baguette") || n.contains("french bread") { return .baguette }
        if n.contains("bread") || n.contains("loaf") || n.contains("roll") ||
           n.contains("bun") || n.contains("bagel") || n.contains("muffin") ||
           n.contains("croissant") || n.contains("cake") || n.contains("cookie") {
            return .breadLoaf
        }

        // ── Condiments ────────────────────────────────────────────────────
        if n.contains("ketchup") || n.contains("mustard") || n.contains("mayo") ||
           n.contains("sauce") || n.contains("syrup") || n.contains("hot sauce") ||
           n.contains("dressing") || n.contains("honey") {
            return .squeezeBottle(color: tintColor(for: cat))
        }

        // ── Snacks ────────────────────────────────────────────────────────
        if n.contains("chip") || n.contains("crisp") || n.contains("popcorn") ||
           n.contains("pretzel") || n.contains("cracker") || n.contains("cookie") ||
           n.contains("granola") || n.contains("nut") || n.contains("trail mix") {
            return .bag(color: tintColor(for: cat))
        }

        // ── Canned / pantry ───────────────────────────────────────────────
        if n.contains("can") || n.contains("canned") || n.contains("beans") ||
           n.contains("soup") || n.contains("pasta") || n.contains("rice") ||
           n.contains("cereal") || n.contains("oats") || n.contains("flour") ||
           n.contains("sugar") || n.contains("salt") || n.contains("oil") {
            return .can(color: tintColor(for: cat))
        }

        // ── Category fallbacks ────────────────────────────────────────────
        switch cat {
        case .produce:    return .roundFruit(color: tintColor(for: cat))
        case .dairy:      return .milkCarton(color: UIColor(red:0.92,green:0.94,blue:0.97,alpha:1))
        case .meat:       return .meatPackage(color: tintColor(for: cat))
        case .seafood:    return .fish
        case .bakery:     return .breadLoaf
        case .frozen:     return .flatBox(color: tintColor(for: cat))
        case .pantry:     return .can(color: tintColor(for: cat))
        case .beverages:  return .bottle(color: tintColor(for: cat))
        case .condiments: return .squeezeBottle(color: tintColor(for: cat))
        case .snacks:     return .bag(color: tintColor(for: cat))
        case .other:      return .genericSphere(color: tintColor(for: cat))
        }
    }

    // Height lookup keyed by shape type (for positioning on counter surface)
    private func shapeHeight(for type: FoodShapeType) -> Float {
        switch type {
        case .roundFruit, .citrus, .berry, .genericSphere: return 0.30
        case .banana:          return 0.12
        case .carrot:          return 0.38
        case .broccoli:        return 0.36
        case .corn:            return 0.40
        case .milkCarton:      return 0.42
        case .bottle:          return 0.48
        case .can:             return 0.30
        case .egg:             return 0.20
        case .meatPackage:     return 0.10
        case .fish:            return 0.18
        case .breadLoaf:       return 0.20
        case .baguette:        return 0.10
        case .flatBox:         return 0.12
        case .tallBox:         return 0.38
        case .bag:             return 0.27
        case .squeezeBottle:   return 0.32
        }
    }

    // Wrapper that resolves shape type from the grocery, then delegates
    private func categoryShapeNode(for grocery: Grocery, tileSize: Float) -> SCNNode {
        // USDZ override — active when .usdz files are bundled with matching category name
        if let usdzNode = loadUSDZModel(named: grocery.category.rawValue.lowercased()) {
            let s = tileSize * 0.5
            usdzNode.scale = SCNVector3(s, s, s)
            let wrapper = SCNNode(); wrapper.addChildNode(usdzNode)
            return wrapper
        }
        let shapeType = resolveShapeType(for: grocery)
        return buildShapeNode(shapeType)
    }

    // Builds the actual geometry for each shape type.
    // Local origin is at the bottom center of the shape.
    private func buildShapeNode(_ type: FoodShapeType) -> SCNNode {
        let group = SCNNode()

        func pbr(_ color: UIColor, roughness: Double = 0.55, metalness: Double = 0.05) -> SCNMaterial {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = color
            m.roughness.contents = roughness
            m.metalness.contents = metalness
            return m
        }

        func addStem(to parent: SCNNode, atY y: Float, color: UIColor = UIColor(red:0.32,green:0.18,blue:0.05,alpha:1)) {
            let geo = SCNBox(width: 0.018, height: 0.055, length: 0.018, chamferRadius: 0.006)
            geo.materials = [pbr(color, roughness: 0.85)]
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(0.008, y + 0.027, 0.008)
            parent.addChildNode(node)
        }

        func addLabelFace(to parent: SCNNode, width: CGFloat, height: CGFloat,
                          zOff: CGFloat, yOff: CGFloat, icon: String, tint: UIColor) {
            let plane = SCNPlane(width: width, height: height)
            plane.cornerRadius = 0.01
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = coloredSymbolImage(for: icon, tint: tint,
                                                       size: CGSize(width: 128, height: 128))
            mat.isDoubleSided = false
            plane.materials = [mat]
            let n = SCNNode(geometry: plane)
            n.name = "labelFace"
            n.position = SCNVector3(0, Float(yOff), Float(zOff))
            parent.addChildNode(n)
        }

        switch type {

        // ── Round fruit (apple, peach, mango, pear, kiwi…) ───────────────
        case .roundFruit(let color):
            let r: CGFloat = 0.13
            let sphere = SCNSphere(radius: r); sphere.segmentCount = 28
            sphere.materials = [pbr(color, roughness: 0.38)]
            let body = SCNNode(geometry: sphere); body.position = SCNVector3(0, Float(r), 0)
            group.addChildNode(body)
            addStem(to: group, atY: Float(r * 2))

        // ── Citrus (orange, lemon, lime…) — slightly oblate sphere ────────
        case .citrus(let color):
            let sphere = SCNSphere(radius: 0.13); sphere.segmentCount = 28
            sphere.materials = [pbr(color, roughness: 0.50)]
            let body = SCNNode(geometry: sphere)
            body.scale = SCNVector3(1.0, 0.88, 1.0)  // slightly squished top-bottom
            body.position = SCNVector3(0, 0.115, 0)
            group.addChildNode(body)
            addStem(to: group, atY: 0.23)

        // ── Berry / small round (strawberry, tomato, cherry…) ────────────
        case .berry(let color):
            let sphere = SCNSphere(radius: 0.10); sphere.segmentCount = 24
            sphere.materials = [pbr(color, roughness: 0.42)]
            let body = SCNNode(geometry: sphere); body.position = SCNVector3(0, 0.10, 0)
            group.addChildNode(body)
            addStem(to: group, atY: 0.20,
                    color: UIColor(red:0.18,green:0.55,blue:0.12,alpha:1))

        // ── Banana — horizontal capsule with curve suggestion ─────────────
        case .banana:
            let capsule = SCNCapsule(capRadius: 0.05, height: 0.32); capsule.radialSegmentCount = 20
            capsule.materials = [pbr(UIColor(red:0.95,green:0.88,blue:0.15,alpha:1), roughness: 0.55)]
            let body = SCNNode(geometry: capsule)
            body.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            body.position = SCNVector3(0, 0.06, 0)
            // Slight upward tilt at one end to suggest curve
            body.eulerAngles = SCNVector3(0.18, 0, Float.pi / 2)
            // Dark tip
            let tipGeo = SCNSphere(radius: 0.025); tipGeo.segmentCount = 10
            tipGeo.materials = [pbr(UIColor(red:0.22,green:0.14,blue:0.05,alpha:1), roughness: 0.8)]
            let tip = SCNNode(geometry: tipGeo); tip.position = SCNVector3(0.18, 0.07, -0.02)
            group.addChildNode(body); group.addChildNode(tip)

        // ── Carrot — orange cone ──────────────────────────────────────────
        case .carrot:
            let cone = SCNCone(topRadius: 0.0, bottomRadius: 0.07, height: 0.32)
            cone.radialSegmentCount = 20
            cone.materials = [pbr(UIColor(red:0.95,green:0.50,blue:0.08,alpha:1), roughness: 0.65)]
            let body = SCNNode(geometry: cone); body.position = SCNVector3(0, 0.16, 0)
            // Leafy top (green cylinder tuft)
            let leafGeo = SCNCylinder(radius: 0.025, height: 0.08)
            leafGeo.materials = [pbr(UIColor(red:0.18,green:0.62,blue:0.12,alpha:1), roughness: 0.7)]
            let leaf = SCNNode(geometry: leafGeo); leaf.position = SCNVector3(0, 0.36, 0)
            group.addChildNode(body); group.addChildNode(leaf)

        // ── Broccoli — green sphere on stalk ─────────────────────────────
        case .broccoli:
            let stalkGeo = SCNCylinder(radius: 0.04, height: 0.18)
            stalkGeo.materials = [pbr(UIColor(red:0.28,green:0.52,blue:0.18,alpha:1), roughness: 0.75)]
            let stalk = SCNNode(geometry: stalkGeo); stalk.position = SCNVector3(0, 0.09, 0)
            let headGeo = SCNSphere(radius: 0.13); headGeo.segmentCount = 20
            headGeo.materials = [pbr(UIColor(red:0.15,green:0.48,blue:0.12,alpha:1), roughness: 0.80)]
            let head = SCNNode(geometry: headGeo)
            head.scale = SCNVector3(1.0, 0.75, 1.0)  // slightly flat dome
            head.position = SCNVector3(0, 0.26, 0)
            group.addChildNode(stalk); group.addChildNode(head)

        // ── Corn — yellow cylinder with husk ─────────────────────────────
        case .corn:
            let cobGeo = SCNCylinder(radius: 0.07, height: 0.28); cobGeo.radialSegmentCount = 20
            cobGeo.materials = [pbr(UIColor(red:0.96,green:0.86,blue:0.20,alpha:1), roughness: 0.65)]
            let cob = SCNNode(geometry: cobGeo); cob.position = SCNVector3(0, 0.20, 0)
            let huskGeo = SCNCone(topRadius: 0.04, bottomRadius: 0.08, height: 0.14)
            huskGeo.materials = [pbr(UIColor(red:0.30,green:0.60,blue:0.12,alpha:1), roughness: 0.72)]
            let husk = SCNNode(geometry: huskGeo); husk.position = SCNVector3(0, 0.07, 0)
            group.addChildNode(cob); group.addChildNode(husk)

        // ── Milk carton ───────────────────────────────────────────────────
        case .milkCarton(let color):
            let bodyGeo = SCNBox(width: 0.18, height: 0.34, length: 0.14, chamferRadius: 0.015)
            bodyGeo.materials = [pbr(color, roughness: 0.5)]
            let body = SCNNode(geometry: bodyGeo); body.position = SCNVector3(0, 0.17, 0)
            let peakGeo = SCNBox(width: 0.18, height: 0.07, length: 0.14, chamferRadius: 0.07)
            peakGeo.materials = [pbr(color.withAlphaComponent(0.7), roughness: 0.4)]
            let peak = SCNNode(geometry: peakGeo); peak.position = SCNVector3(0, 0.375, 0)
            group.addChildNode(body); group.addChildNode(peak)
            addLabelFace(to: group, width: 0.15, height: 0.20, zOff: 0.073, yOff: 0.15,
                         icon: "drop.fill", tint: UIColor(red:0.30,green:0.60,blue:0.95,alpha:1))

        // ── Bottle (water, juice, wine…) ──────────────────────────────────
        case .bottle(let color):
            let bodyGeo = SCNCylinder(radius: 0.09, height: 0.32); bodyGeo.radialSegmentCount = 24
            bodyGeo.materials = [pbr(color, roughness: 0.25, metalness: 0.05)]
            let body = SCNNode(geometry: bodyGeo); body.position = SCNVector3(0, 0.16, 0)
            let neckGeo = SCNCylinder(radius: 0.045, height: 0.10)
            neckGeo.materials = [pbr(color.withAlphaComponent(0.8), roughness: 0.30)]
            let neck = SCNNode(geometry: neckGeo); neck.position = SCNVector3(0, 0.37, 0)
            let capGeo = SCNCylinder(radius: 0.05, height: 0.04)
            capGeo.materials = [pbr(UIColor(red:0.70,green:0.70,blue:0.72,alpha:1), roughness:0.15, metalness:0.85)]
            let cap = SCNNode(geometry: capGeo); cap.position = SCNVector3(0, 0.44, 0)
            group.addChildNode(body); group.addChildNode(neck); group.addChildNode(cap)
            addLabelFace(to: group, width: 0.16, height: 0.18, zOff: 0.094, yOff: 0.16,
                         icon: "cup.and.saucer.fill", tint: UIColor(red:0.40,green:0.30,blue:0.80,alpha:1))

        // ── Can (soup, soda, beans…) ──────────────────────────────────────
        case .can(let color):
            let body = SCNCylinder(radius: 0.10, height: 0.26); body.radialSegmentCount = 24
            body.materials = [pbr(color, roughness: 0.55)]
            let bodyNode = SCNNode(geometry: body); bodyNode.position = SCNVector3(0, 0.13, 0)
            for yOff: Float in [0.263, 0.003] {
                let rimGeo = SCNCylinder(radius: 0.104, height: 0.012)
                rimGeo.materials = [pbr(UIColor(red:0.70,green:0.70,blue:0.72,alpha:1), roughness:0.15, metalness:0.90)]
                let rim = SCNNode(geometry: rimGeo); rim.position = SCNVector3(0, yOff, 0)
                group.addChildNode(rim)
            }
            group.addChildNode(bodyNode)
            addLabelFace(to: group, width: 0.18, height: 0.16, zOff: 0.103, yOff: 0.13,
                         icon: "cabinet.fill", tint: UIColor(red:0.65,green:0.45,blue:0.25,alpha:1))

        // ── Egg — white capsule standing upright ──────────────────────────
        case .egg:
            let capsule = SCNCapsule(capRadius: 0.07, height: 0.10); capsule.radialSegmentCount = 20
            capsule.materials = [pbr(UIColor(red:0.97,green:0.96,blue:0.94,alpha:1), roughness: 0.35)]
            let body = SCNNode(geometry: capsule)
            body.scale = SCNVector3(1.0, 1.15, 0.88)  // slight egg-oval
            body.position = SCNVector3(0, 0.12, 0)
            group.addChildNode(body)

        // ── Meat package — flat tray ──────────────────────────────────────
        case .meatPackage(let color):
            let trayGeo = SCNBox(width: 0.28, height: 0.06, length: 0.22, chamferRadius: 0.015)
            trayGeo.materials = [pbr(UIColor(red:0.90,green:0.88,blue:0.86,alpha:1), roughness:0.5)]
            let tray = SCNNode(geometry: trayGeo); tray.position = SCNVector3(0, 0.03, 0)
            let meatGeo = SCNBox(width: 0.24, height: 0.045, length: 0.18, chamferRadius: 0.02)
            meatGeo.materials = [pbr(color, roughness: 0.65)]
            let meat = SCNNode(geometry: meatGeo); meat.position = SCNVector3(0, 0.08, 0)
            let wrapGeo = SCNBox(width: 0.29, height: 0.003, length: 0.23, chamferRadius: 0.01)
            let wrapMat = SCNMaterial(); wrapMat.lightingModel = .physicallyBased
            wrapMat.diffuse.contents = UIColor(white:1.0,alpha:0.30)
            wrapMat.roughness.contents = 0.05; wrapMat.metalness.contents = 0.08
            wrapGeo.materials = [wrapMat]
            let wrap = SCNNode(geometry: wrapGeo); wrap.position = SCNVector3(0, 0.103, 0)
            group.addChildNode(tray); group.addChildNode(meat); group.addChildNode(wrap)

        // ── Fish — horizontal body with tail ─────────────────────────────
        case .fish:
            let capsule = SCNCapsule(capRadius: 0.065, height: 0.28); capsule.radialSegmentCount = 22
            capsule.materials = [pbr(UIColor(red:0.55,green:0.70,blue:0.82,alpha:1), roughness:0.45, metalness:0.15)]
            let body = SCNNode(geometry: capsule)
            body.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            body.position = SCNVector3(0, 0.08, 0)
            // Tail fin
            let tailGeo = SCNBox(width: 0.06, height: 0.10, length: 0.015, chamferRadius: 0.025)
            tailGeo.materials = [pbr(UIColor(red:0.45,green:0.60,blue:0.75,alpha:1), roughness: 0.5)]
            let tail = SCNNode(geometry: tailGeo); tail.position = SCNVector3(-0.17, 0.09, 0)
            // Dorsal fin
            let dorsalGeo = SCNBox(width: 0.06, height: 0.06, length: 0.012, chamferRadius: 0.02)
            dorsalGeo.materials = [pbr(UIColor(red:0.45,green:0.60,blue:0.75,alpha:1), roughness: 0.5)]
            let dorsal = SCNNode(geometry: dorsalGeo); dorsal.position = SCNVector3(0.03, 0.14, 0)
            group.addChildNode(body); group.addChildNode(tail); group.addChildNode(dorsal)

        // ── Bread loaf ────────────────────────────────────────────────────
        case .breadLoaf:
            let loafGeo = SCNBox(width: 0.26, height: 0.18, length: 0.20, chamferRadius: 0.09)
            loafGeo.materials = [pbr(UIColor(red:0.78,green:0.52,blue:0.24,alpha:1), roughness: 0.80)]
            let loaf = SCNNode(geometry: loafGeo); loaf.position = SCNVector3(0, 0.09, 0)
            for xOff: Float in [-0.065, 0.0, 0.065] {
                let scoreGeo = SCNBox(width: 0.005, height: 0.16, length: 0.20, chamferRadius: 0.002)
                scoreGeo.materials = [pbr(UIColor(red:0.55,green:0.32,blue:0.08,alpha:1), roughness: 0.88)]
                let score = SCNNode(geometry: scoreGeo); score.position = SCNVector3(xOff, 0.09, 0)
                group.addChildNode(score)
            }
            group.addChildNode(loaf)

        // ── Baguette — long horizontal loaf ──────────────────────────────
        case .baguette:
            let geo = SCNCapsule(capRadius: 0.04, height: 0.36); geo.radialSegmentCount = 16
            geo.materials = [pbr(UIColor(red:0.82,green:0.58,blue:0.22,alpha:1), roughness: 0.80)]
            let body = SCNNode(geometry: geo)
            body.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            body.position = SCNVector3(0, 0.05, 0)
            group.addChildNode(body)

        // ── Flat box (frozen meal, packaged item) ─────────────────────────
        case .flatBox(let color):
            let boxGeo = SCNBox(width: 0.28, height: 0.10, length: 0.22, chamferRadius: 0.02)
            boxGeo.materials = [pbr(color, roughness: 0.40, metalness: 0.12)]
            let box = SCNNode(geometry: boxGeo); box.position = SCNVector3(0, 0.05, 0)
            group.addChildNode(box)
            addLabelFace(to: group, width: 0.24, height: 0.08, zOff: 0.114, yOff: 0.05,
                         icon: "snowflake", tint: UIColor(red:0.45,green:0.75,blue:0.95,alpha:1))

        // ── Tall box (cereal, pasta) ──────────────────────────────────────
        case .tallBox(let color):
            let boxGeo = SCNBox(width: 0.20, height: 0.36, length: 0.10, chamferRadius: 0.02)
            boxGeo.materials = [pbr(color, roughness: 0.50)]
            let box = SCNNode(geometry: boxGeo); box.position = SCNVector3(0, 0.18, 0)
            group.addChildNode(box)
            addLabelFace(to: group, width: 0.17, height: 0.22, zOff: 0.053, yOff: 0.18,
                         icon: "cabinet.fill", tint: color)

        // ── Bag (chips, snacks) ────────────────────────────────────────────
        case .bag(let color):
            let bagGeo = SCNBox(width: 0.24, height: 0.22, length: 0.10, chamferRadius: 0.04)
            bagGeo.materials = [pbr(color, roughness: 0.70)]
            let bag = SCNNode(geometry: bagGeo); bag.position = SCNVector3(0, 0.11, 0)
            let sealGeo = SCNBox(width: 0.22, height: 0.025, length: 0.08, chamferRadius: 0.01)
            sealGeo.materials = [pbr(color.withAlphaComponent(0.60), roughness: 0.6)]
            let seal = SCNNode(geometry: sealGeo); seal.position = SCNVector3(0, 0.235, 0)
            group.addChildNode(bag); group.addChildNode(seal)
            addLabelFace(to: group, width: 0.20, height: 0.16, zOff: 0.054, yOff: 0.11,
                         icon: "popcorn.fill", tint: color)

        // ── Squeeze bottle (condiments) ────────────────────────────────────
        case .squeezeBottle(let color):
            let bodyGeo = SCNCapsule(capRadius: 0.07, height: 0.22); bodyGeo.radialSegmentCount = 20
            bodyGeo.materials = [pbr(color, roughness: 0.50)]
            let body = SCNNode(geometry: bodyGeo); body.position = SCNVector3(0, 0.18, 0)
            let nozzleGeo = SCNCylinder(radius: 0.022, height: 0.04)
            nozzleGeo.materials = [pbr(UIColor(white:0.85,alpha:1), roughness:0.35, metalness:0.4)]
            let nozzle = SCNNode(geometry: nozzleGeo); nozzle.position = SCNVector3(0, 0.31, 0)
            group.addChildNode(body); group.addChildNode(nozzle)
            addLabelFace(to: group, width: 0.12, height: 0.14, zOff: 0.073, yOff: 0.16,
                         icon: "takeoutbag.and.cup.and.straw.fill",
                         tint: UIColor(red:0.95,green:0.55,blue:0.10,alpha:1))

        // ── Generic sphere (unknown items) ────────────────────────────────
        case .genericSphere(let color):
            let sphere = SCNSphere(radius: 0.12); sphere.segmentCount = 20
            sphere.materials = [pbr(color, roughness: 0.55)]
            let body = SCNNode(geometry: sphere); body.position = SCNVector3(0, 0.12, 0)
            group.addChildNode(body)
        }

        return group
    }

    // MARK: - Hit-test name propagation

    /// Stamps the item name on every geometry-bearing descendant so hitTest always
    /// resolves to the correct grocery item regardless of which sub-node is struck.
    private func propagateItemName(_ name: String, to node: SCNNode) {
        if node.geometry != nil && node.name != "labelFace" {
            node.name = name
        }
        node.childNodes.forEach { propagateItemName(name, to: $0) }
    }

    // MARK: - Expiration effect

    private func applyExpirationEffect(status: ExpirationStatus, to node: SCNNode) {
        switch status {
        case .critical:
            node.enumerateChildNodes { child, _ in
                child.geometry?.materials.forEach {
                    $0.emission.contents = UIColor.red.withAlphaComponent(0.20)
                }
            }
        case .expired:
            node.enumerateChildNodes { child, _ in
                child.geometry?.materials.forEach { $0.transparency = 0.45 }
            }
        default: break
        }
    }

    // MARK: - USDZ override (future — no-op until .usdz files are bundled)

    private func loadUSDZModel(named name: String) -> SCNNode? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz"),
              let scene = try? SCNScene(url: url, options: nil) else { return nil }
        let node = SCNNode()
        scene.rootNode.childNodes.forEach { node.addChildNode($0.clone()) }
        return node
    }

    private func addOverflowLabel(_ text: String, to applianceNode: SCNNode,
                                   rows: Int, tileSize: Float, padding: Float) {
        let textGeo = SCNText(string: text, extrusionDepth: 0.01)
        textGeo.font = UIFont.systemFont(ofSize: 0.22, weight: .medium)
        textGeo.flatness = 0.005
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(white: 0.3, alpha: 1)
        textGeo.materials = [mat]
        let textNode = SCNNode(geometry: textGeo)
        textNode.name = "overflow.label"
        let step = tileSize + padding
        textNode.position = SCNVector3(-0.4, 0.9 - Float(rows) * step - 0.15, 0.52)
        applianceNode.addChildNode(textNode)
    }

    // MARK: - Texture loading

    private func spoonacularURL(for name: String) -> URL? {
        let slug = name
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: .punctuationCharacters).joined()
        guard !slug.isEmpty else { return nil }
        return URL(string: "https://img.spoonacular.com/ingredients_250x250/\(slug).jpg")
    }

    private func loadTexture(for grocery: Grocery, into node: SCNNode) {
        let key = stableID(grocery)

        if let cached = textureCache[key] {
            applyImage(cached, to: node)
            return
        }

        var urls: [URL] = []
        if let raw = grocery.productImageURL, let u = URL(string: raw) {
            urls.append(u)
        }
        if let u = spoonacularURL(for: grocery.name) {
            urls.append(u)
        }
        if let u = spoonacularURL(for: grocery.category.rawValue) {
            urls.append(u)
        }

        loadFirstSuccessfulImage(from: urls) { [weak self, weak node] image in
            guard let self, let image else { return }
            self.textureCache[key] = image
            guard let node else { return }
            self.applyImage(image, to: node)
        }
    }

    /// Applies a loaded image to the correct material face.
    /// Compound 3D shapes (counter): root has no geometry — find the "labelFace" child.
    /// SCNPlane (fridge/pantry/freezer): firstMaterial.
    private func applyImage(_ image: UIImage, to node: SCNNode) {
        if node.geometry == nil {
            // Compound counter item — apply to the labelFace child plane
            if let labelNode = node.childNode(withName: "labelFace", recursively: true),
               let mat = labelNode.geometry?.firstMaterial {
                mat.diffuse.contents = image
                mat.lightingModel = .constant
            }
            return
        }
        // SCNPlane (fridge/freezer/pantry)
        node.geometry?.firstMaterial?.diffuse.contents = image
    }

    private func loadFirstSuccessfulImage(from urls: [URL], index: Int = 0,
                                           completion: @escaping (UIImage?) -> Void) {
        guard index < urls.count else { completion(nil); return }
        URLSession.shared.dataTask(with: urls[index]) { [weak self] data, response, _ in
            let statusOK = (response as? HTTPURLResponse)?.statusCode == 200
            if let data, statusOK,
               let image = UIImage(data: data),
               image.size.width > 10 {  // reject tiny placeholder images
                DispatchQueue.main.async { completion(image) }
            } else {
                self?.loadFirstSuccessfulImage(from: urls, index: index + 1, completion: completion)
            }
        }.resume()
    }

    // MARK: - Image generation helpers

    /// Renders an SF Symbol with a colored tint on a rounded-rect card background.
    /// Uses `.constant` lighting so colors are never darkened by the 3D scene lights.
    private func coloredSymbolImage(for symbolName: String, tint: UIColor,
                                     size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Card background
            let bg = tint.withAlphaComponent(0.15)
            bg.setFill()
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: size.width * 0.18).fill()

            // Symbol
            let cfg = UIImage.SymbolConfiguration(pointSize: size.width * 0.48, weight: .medium)
            let symbol = UIImage(systemName: symbolName, withConfiguration: cfg)
                ?? UIImage(systemName: "cart.fill", withConfiguration: cfg)
                ?? UIImage()
            let rendered = symbol.withTintColor(tint, renderingMode: .alwaysOriginal)
            let imgSize = rendered.size
            let origin = CGPoint(x: (size.width - imgSize.width) / 2,
                                 y: (size.height - imgSize.height) / 2)
            rendered.draw(at: origin)
        }
    }

    private func tintColor(for category: FoodCategory) -> UIColor {
        switch category {
        case .dairy:      return UIColor(red: 0.30, green: 0.60, blue: 0.95, alpha: 1)
        case .meat:       return UIColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1)
        case .seafood:    return UIColor(red: 0.20, green: 0.55, blue: 0.80, alpha: 1)
        case .produce:    return UIColor(red: 0.25, green: 0.72, blue: 0.30, alpha: 1)
        case .bakery:     return UIColor(red: 0.85, green: 0.60, blue: 0.20, alpha: 1)
        case .frozen:     return UIColor(red: 0.45, green: 0.75, blue: 0.95, alpha: 1)
        case .pantry:     return UIColor(red: 0.65, green: 0.45, blue: 0.25, alpha: 1)
        case .beverages:  return UIColor(red: 0.40, green: 0.30, blue: 0.80, alpha: 1)
        case .condiments: return UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1)
        case .snacks:     return UIColor(red: 0.90, green: 0.40, blue: 0.60, alpha: 1)
        case .other:      return UIColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1)
        }
    }

    /// Procedurally generated marble-like texture
    private func marbleImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            // Base color
            UIColor(red: 0.93, green: 0.91, blue: 0.89, alpha: 1).setFill()
            c.fill(CGRect(origin: .zero, size: size))

            // Veins
            UIColor(red: 0.75, green: 0.70, blue: 0.68, alpha: 0.35).setStroke()
            for i in stride(from: 0, to: size.height, by: size.height / 5) {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: i + CGFloat.random(in: -10...10)))
                path.addCurve(
                    to: CGPoint(x: size.width, y: i + CGFloat.random(in: -20...20)),
                    controlPoint1: CGPoint(x: size.width * 0.3, y: i + CGFloat.random(in: -30...30)),
                    controlPoint2: CGPoint(x: size.width * 0.7, y: i + CGFloat.random(in: -30...30))
                )
                path.lineWidth = CGFloat.random(in: 0.5...2.5)
                path.stroke()
            }
        }
    }

    /// Checkerboard floor tile texture
    private func checkerboardImage(size: CGSize, color1: UIColor, color2: UIColor, tiles: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let tileW = size.width / CGFloat(tiles)
            let tileH = size.height / CGFloat(tiles)
            for row in 0..<tiles {
                for col in 0..<tiles {
                    let isLight = (row + col) % 2 == 0
                    (isLight ? color1 : color2).setFill()
                    c.fill(CGRect(x: CGFloat(col) * tileW, y: CGFloat(row) * tileH,
                                  width: tileW, height: tileH))
                }
            }
        }
    }

    // MARK: - Wall style

    /// Applies the chosen wall style to the named "backWall" node in the scene.
    func applyWallStyle(_ style: KitchenWallStyle, to scene: SCNScene) {
        guard let wallNode = scene.rootNode.childNode(withName: "backWall", recursively: false) else { return }
        wallNode.geometry?.firstMaterial = wallMaterial(for: style)
    }

    private func wallMaterial(for style: KitchenWallStyle) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.isDoubleSided = true
        switch style {

        case .standard:
            // Warm beige plaster — the default
            mat.lightingModel = .physicallyBased
            mat.diffuse.contents = UIColor(red: 0.94, green: 0.92, blue: 0.88, alpha: 1)
            mat.roughness.contents = 0.9
            mat.metalness.contents = 0.0

        case .modern:
            // Large-format white/grey subway tiles
            mat.lightingModel = .physicallyBased
            mat.diffuse.contents = modernTileImage(size: CGSize(width: 512, height: 512))
            mat.roughness.contents = 0.25
            mat.metalness.contents = 0.05

        case .scenic:
            // Window-like scenic backdrop — layered gradient with park/nature feel
            mat.lightingModel = .constant  // unlit so it looks like a bright outdoor view
            mat.diffuse.contents = scenicWindowImage(size: CGSize(width: 1024, height: 512))
        }
        return mat
    }

    /// Large-format grey tile pattern (modern kitchen backsplash style)
    private func modernTileImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            // Tile base — off-white
            UIColor(red: 0.93, green: 0.93, blue: 0.94, alpha: 1).setFill()
            c.fill(CGRect(origin: .zero, size: size))

            // Grout lines
            UIColor(red: 0.72, green: 0.72, blue: 0.74, alpha: 1).setStroke()
            c.setLineWidth(3)

            // Horizontal grout lines every ~80px (large subway tile proportions)
            let tileH: CGFloat = 80
            var y: CGFloat = 0
            var row = 0
            while y <= size.height {
                c.move(to: CGPoint(x: 0, y: y))
                c.addLine(to: CGPoint(x: size.width, y: y))
                c.strokePath()
                // Offset every other row for brick pattern
                let tileW: CGFloat = 160
                let offset: CGFloat = (row % 2 == 0) ? 0 : tileW / 2
                var x = offset - tileW
                while x <= size.width + tileW {
                    c.move(to: CGPoint(x: x, y: y))
                    c.addLine(to: CGPoint(x: x, y: y + tileH))
                    c.strokePath()
                    x += tileW
                }
                y += tileH
                row += 1
            }

            // Subtle tile gloss highlight on each tile
            UIColor(white: 1.0, alpha: 0.18).setFill()
            row = 0; y = 2
            while y < size.height {
                let tileW: CGFloat = 160
                let offset: CGFloat = (row % 2 == 0) ? 0 : tileW / 2
                var x = offset - tileW + 2
                while x < size.width {
                    c.fill(CGRect(x: x + 2, y: y + 2, width: tileW - 7, height: tileH / 2 - 4))
                    x += tileW
                }
                y += tileH
                row += 1
            }
        }
    }

    /// Scenic backdrop — sky gradient at top, green parkland at bottom,
    /// with a large window frame overlay suggesting you're looking outside.
    private func scenicWindowImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Sky gradient — top bright blue fading to lighter blue
            let skyColors = [
                UIColor(red: 0.42, green: 0.68, blue: 0.92, alpha: 1).cgColor,
                UIColor(red: 0.72, green: 0.88, blue: 0.98, alpha: 1).cgColor
            ]
            let skyGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: skyColors as CFArray,
                                     locations: [0.0, 1.0])!
            c.drawLinearGradient(skyGrad,
                                 start: CGPoint(x: 0, y: 0),
                                 end: CGPoint(x: 0, y: size.height * 0.62),
                                 options: [])

            // Ground / grass gradient
            let groundColors = [
                UIColor(red: 0.25, green: 0.58, blue: 0.22, alpha: 1).cgColor,
                UIColor(red: 0.35, green: 0.70, blue: 0.28, alpha: 1).cgColor
            ]
            let groundGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: groundColors as CFArray,
                                        locations: [0.0, 1.0])!
            c.drawLinearGradient(groundGrad,
                                 start: CGPoint(x: 0, y: size.height * 0.62),
                                 end: CGPoint(x: 0, y: size.height),
                                 options: [])

            // Distant tree line (dark green silhouette)
            UIColor(red: 0.15, green: 0.42, blue: 0.14, alpha: 0.85).setFill()
            let treeLine = UIBezierPath()
            treeLine.move(to: CGPoint(x: 0, y: size.height * 0.62))
            // Bumpy tree canopy
            let steps = 18
            let stepW = size.width / CGFloat(steps)
            for i in 0...steps {
                let x = CGFloat(i) * stepW
                let bumpH = size.height * CGFloat.random(in: 0.06...0.14)
                treeLine.addLine(to: CGPoint(x: x, y: size.height * 0.62 - bumpH))
            }
            treeLine.addLine(to: CGPoint(x: size.width, y: size.height * 0.62))
            treeLine.close()
            treeLine.fill()

            // Waterfall — thin white cascading strip near center-right
            let fallX = size.width * 0.68
            let fallW: CGFloat = 18
            let fallColors = [
                UIColor(white: 1.0, alpha: 0.85).cgColor,
                UIColor(white: 0.85, alpha: 0.50).cgColor
            ]
            let fallGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: fallColors as CFArray,
                                      locations: [0.0, 1.0])!
            c.saveGState()
            c.clip(to: CGRect(x: fallX, y: size.height * 0.18, width: fallW, height: size.height * 0.44))
            c.drawLinearGradient(fallGrad,
                                 start: CGPoint(x: fallX, y: size.height * 0.18),
                                 end: CGPoint(x: fallX, y: size.height * 0.62),
                                 options: [])
            c.restoreGState()
            // Mist pool at base of waterfall
            UIColor(white: 1.0, alpha: 0.30).setFill()
            c.fillEllipse(in: CGRect(x: fallX - 14, y: size.height * 0.58,
                                      width: fallW + 28, height: 18))

            // Sun
            UIColor(red: 1.0, green: 0.95, blue: 0.70, alpha: 0.90).setFill()
            c.fillEllipse(in: CGRect(x: size.width * 0.18, y: size.height * 0.06,
                                      width: 52, height: 52))
            // Sun glow
            UIColor(red: 1.0, green: 0.95, blue: 0.70, alpha: 0.22).setFill()
            c.fillEllipse(in: CGRect(x: size.width * 0.18 - 16, y: size.height * 0.06 - 16,
                                      width: 84, height: 84))

            // Window frame overlay — white border around the whole image
            let frameW: CGFloat = 22
            UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1).setFill()
            // Top frame
            c.fill(CGRect(x: 0, y: 0, width: size.width, height: frameW))
            // Bottom frame
            c.fill(CGRect(x: 0, y: size.height - frameW, width: size.width, height: frameW))
            // Left frame
            c.fill(CGRect(x: 0, y: 0, width: frameW, height: size.height))
            // Right frame
            c.fill(CGRect(x: size.width - frameW, y: 0, width: frameW, height: size.height))
            // Center vertical mullion
            c.fill(CGRect(x: size.width / 2 - 8, y: 0, width: 16, height: size.height))
            // Center horizontal mullion
            c.fill(CGRect(x: 0, y: size.height * 0.48, width: size.width, height: 14))
        }
    }
}
