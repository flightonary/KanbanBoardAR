import ARKit

extension SCNNode {
    var boundingWidth: Float {
        get {
            let (min, max) = boundingBox
            return Float(max.x - min.x) * scale.x
        }
    }
    
    var boundingHeight: Float {
        get {
            let (min, max) = boundingBox
            return Float(max.y - min.y) * scale.y
        }
    }
    
    func centerize() {
        centerizeHorizontal()
        centerizeVertical()
    }
    
    func centerizeHorizontal() {
        simdPosition.x = -(boundingWidth / 2)
    }
    
    func centerizeVertical() {
        simdPosition.y = -(boundingHeight / 2)
    }
}

extension Array where Element == String {
    var maxLength: Int {
        guard let maxstr = self.max(by: {$1.count > $0.count})
            else {return 0}
        
        return maxstr.count
    }
}

class KanbanBoard: SCNNode {
    
    let meshNode: SCNNode
    let boardNode: SCNNode
    
    init(anchor: ARPlaneAnchor, in sceneView: ARSCNView) {
        // Create a mesh to visualize the estimated shape of the plane.
        guard let meshGeometry = ARSCNPlaneGeometry(device: sceneView.device!)
            else { fatalError("Can't create plane geometry") }
        meshGeometry.update(from: anchor.geometry)
        meshNode = SCNNode(geometry: meshGeometry)
        
        // Create a node to visualize the plane's bounding rectangle.
        let boardWidth : Float = 1.0
        let boardHeight: Float = 1.0
        let extentPlane: SCNPlane = SCNPlane(width: CGFloat(boardWidth), height: CGFloat(boardHeight))
        boardNode = SCNNode(geometry: extentPlane)
        boardNode.simdPosition = anchor.center
        
        super.init()
        
        let boardTitle = LabelNode("Kanban Board", width: boardWidth/2, textColor: UIColor.black)
        let titleMargin = boardHeight/20
        boardTitle.simdPosition += float3(0, boardHeight/2 - boardTitle.boundingHeight/2 - titleMargin, 0.001)
        boardNode.addChildNode(boardTitle)
        
        let columns = ["ToDo", "Ongoing", "Done"]
        let stickyNoteTableNode = StickyNoteTableNode(width: boardWidth * 0.9, height: boardHeight * 0.7, columns: columns)
        let tableMargin = titleMargin * 2 + boardTitle.boundingHeight
        stickyNoteTableNode.simdPosition += float3(0, boardHeight/2 - stickyNoteTableNode.height/2 - tableMargin, 0.001)
        boardNode.addChildNode(stickyNoteTableNode)
        
        stickyNoteTableNode.addStickyNote("トイレット\nペーパー\n買う", column: 0, row: 1)
        stickyNoteTableNode.addStickyNote("車の点検", column: 2, row: 2)
        stickyNoteTableNode.addStickyNote("資料作成", column: 1, row: 3)
        stickyNoteTableNode.addStickyNote("風呂と\n洗面台\nそうじ", column: 1, row: 4)
        
        
        self.setupMeshVisualStyle()
        self.setupBoardVisualStyle()
        
        // Add the plane extent and plane geometry as child nodes so they appear in the scene.
        addChildNode(meshNode)
        addChildNode(boardNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMeshVisualStyle() {
        // Use color and blend mode to make planes stand out.
        guard let material = meshNode.geometry?.firstMaterial
            else { fatalError("ARSCNPlaneGeometry always has one material") }
        material.diffuse.contents = UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1)
        // Make the plane visualization semitransparent to clearly show real-world placement.
        meshNode.opacity = 0.0
    }
    
    private func setupBoardVisualStyle() {
        guard let material = boardNode.geometry?.firstMaterial
            else { fatalError("SCNPlane always has one material") }
        material.diffuse.contents = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        // Make the extent visualization semitransparent to clearly show real-world placement.
        boardNode.opacity = 0.9

        // `SCNPlane` is vertically oriented in its local coordinate space, so
        // rotate it to match the orientation of `ARPlaneAnchor`.
        boardNode.eulerAngles.x = -.pi / 2
    }
}

class StickyNoteTableNode: SCNNode {
    let width: Float
    let height: Float
    let columns: [String]
    let rowCount: Int

    init(width: Float, height: Float, columns: [String], rowCount: Int = 6) {
        self.width = width
        self.height = height
        self.columns = columns
        self.rowCount = rowCount
        super.init()
        
        let lineWeight: Float = 0.005
        let sizePerChar = columnWidth / Float(columns.maxLength) * 0.8

        for (index, status) in columns.enumerated() {
            let statusLabel = LabelNode(status, sizePerChar: sizePerChar, textColor: UIColor.black)
            let heightPosition = rowPosition(0)
            let widthPosition  = columnPosition(index)
            
            statusLabel.simdPosition += float3(widthPosition, heightPosition, 0)
            addChildNode(statusLabel)
            
            if index != columns.count - 1 {
                let verticalLine = PanelNode(width: lineWeight, height: height, planeColor: UIColor.black)
                verticalLine.simdPosition = float3(widthPosition + columnWidth / 2, 0, 0)
                addChildNode(verticalLine)
            }
        }
        
        let horizontalLine = PanelNode(width: width, height: lineWeight, planeColor: UIColor.black)
        horizontalLine.simdPosition = float3(0, height/2 - rowHeight, 0)
        addChildNode(horizontalLine)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func addStickyNote(_ text: String, column: Int, row: Int) {
        let stickyNoteSize = min(columnWidth, rowHeight) * 0.9
        let note = StickyNote(text, size: stickyNoteSize)
        note.simdPosition = float3(columnPosition(column), rowPosition(row), 0)
        addChildNode(note)
    }
    
    private var columnCount: Int {
        get {
            return columns.count
        }
    }
    
    private var columnWidth: Float {
        get {
            return width / Float(columnCount)
        }
    }
    
    private var rowHeight: Float {
        get {
            return height / Float(rowCount)
        }
    }
    
    private func columnPosition(_ column: Int) -> Float {
        var widthPosition : Float = 0.0

        let centerIndex = Float(columnCount - 1) / 2.0
        if Float(column) != centerIndex {
            widthPosition = (Float(column) - centerIndex) * columnWidth
        }

        return widthPosition
    }
    
    private func rowPosition(_ row: Int) -> Float {
        // 行番号を上から0, 1, 2とするために、indexを反転させる
        let rrow = rowCount - 1 - row
        
        var heightPosition : Float = 0.0
        
        let centerIndex = Float(rowCount - 1) / 2.0
        if Float(rrow) != centerIndex {
            heightPosition = (Float(rrow) - centerIndex) * rowHeight
        }
        
        return heightPosition
    }
}

class StickyNote: SCNNode {
    init(_ text: String, size: Float) {
        super.init()
        
        let paper = PanelNode(width: size, height: size, planeColor: UIColor(red: 0.0, green: 0.8, blue: 0.8, alpha: 1))
        addChildNode(paper)
        
        let textGeometry = SCNText(string: text, extrusionDepth: 0.0001)
        textGeometry.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: UIFont.Weight.regular)
        textGeometry.isWrapped = true
        
        let textNode = SCNNode(geometry: textGeometry)
        // set color
        textNode.geometry?.materials.first?.diffuse.contents = UIColor.black
        // scale down the size of the text
        let sizePerChar = size * 0.2
        let maxLength = text.components(separatedBy: "\n").maxLength
        let ratio = Float(maxLength) * sizePerChar / textNode.boundingWidth
        textNode.scale = SCNVector3(ratio, ratio, ratio)
        textNode.centerizeVertical()
        textNode.simdPosition += float3(-size/2, 0, 0.001)
        addChildNode(textNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LabelNode: SCNNode {
    
    init(_ text: String, width: Float, textColor: UIColor) {
        super.init()
        
        let textGeometry = SCNText(string: text, extrusionDepth: 0.0001)

        // 空間に描画される文字サイズがあまりにも大きいため、containerFrameやフォントサイズでは調整できない。そのため最後にscale downする。
        // 例えばcontainerFrameでは何も描画されない。
        // textGeometry.containerFrame = CGRect(x: 0, y: 0, width: CGFloat(0.4), height: CGFloat(0.4))
        // textGeometry.alignmentMode = "center"
        textGeometry.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: UIFont.Weight.regular)
    
        let textNode = SCNNode(geometry: textGeometry)
        // set color
        textNode.geometry?.materials.first?.diffuse.contents = textColor
        // scale down the size of the text
        let ratio = width / textNode.boundingWidth
        textNode.scale = SCNVector3(ratio, ratio, 1)
        textNode.centerize()
        addChildNode(textNode)
    }
    
    convenience init(_ text: String, sizePerChar: Float, textColor: UIColor) {
        let width = Float(text.count) * sizePerChar
        self.init(text, width: width, textColor: textColor)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class PanelNode: SCNNode {
    
    init(width: Float, height: Float, planeColor: UIColor) {
        super.init()
        
        let plane: SCNPlane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
        let planeNode = SCNNode(geometry: plane)
        planeNode.geometry?.materials.first?.diffuse.contents = planeColor
        addChildNode(planeNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
