import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var gridWindow: GridWindow!
    var globalMonitor: Any?
    var localMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("KeybrClicker starting...")
        NSApp.setActivationPolicy(.accessory)
        
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("WARNING: Accessibility permissions not granted. Hotkey may not work.")
            print("Go to System Settings > Privacy & Security > Accessibility and add this app.")
        }
        
        gridWindow = GridWindow()
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isHotkey(event) == true {
                print("Hotkey detected (global), showing grid")
                DispatchQueue.main.async {
                    self?.showGrid()
                }
            }
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isHotkey(event) == true {
                print("Hotkey detected (local), showing grid")
                self?.showGrid()
                return nil
            }
            return event
        }
        
        print("KeybrClicker ready. Press Cmd+Option+G to show grid.")
    }
    
    func isHotkey(_ event: NSEvent) -> Bool {
        let cmdOpt = NSEvent.ModifierFlags([.command, .option])
        return event.modifierFlags.contains(cmdOpt) && event.keyCode == 5
    }
    
    func showGrid() {
        gridWindow.show()
    }
}

class GridWindow: NSWindow {
    var gridView: GridView!
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    init() {
        let screenFrame = NSScreen.main!.frame
        super.init(contentRect: screenFrame, styleMask: .borderless, backing: .buffered, defer: false)
        
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        
        gridView = GridView(frame: NSRect(origin: .zero, size: screenFrame.size))
        contentView = gridView
    }
    
    func show() {
        guard let screen = NSScreen.main else {
            print("ERROR: No main screen found")
            return
        }
        setFrame(screen.frame, display: true)
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        makeFirstResponder(gridView)
        gridView.reset()
    }
    
    func hide() {
        orderOut(nil)
    }
}

class GridView: NSView {
    let columns = 10
    let rows = 7
    var inputBuffer = ""
    
    override var isFlipped: Bool { true }
    
    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        let cellWidth = bounds.width / CGFloat(columns)
        let cellHeight = bounds.height / CGFloat(rows)
        
        NSColor.lightGray.withAlphaComponent(0.85).setFill()
        bounds.fill()
        
        NSColor.darkGray.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.5
        
        for i in 0...columns {
            let x = CGFloat(i) * cellWidth
            path.move(to: NSPoint(x: x, y: 0))
            path.line(to: NSPoint(x: x, y: bounds.height))
        }
        
        for i in 0...rows {
            let y = CGFloat(i) * cellHeight
            path.move(to: NSPoint(x: 0, y: y))
            path.line(to: NSPoint(x: bounds.width, y: y))
        }
        
        path.stroke()
        
        let font = NSFont.boldSystemFont(ofSize: 28)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        for col in 0..<columns {
            for row in 0..<rows {
                let colLetter = String(UnicodeScalar(UInt32(UnicodeScalar("A").value) + UInt32(col))!)
                let rowLetter = String(UnicodeScalar(UInt32(UnicodeScalar("A").value) + UInt32(row))!)
                let label = colLetter + rowLetter
                
                let cellX = CGFloat(col) * cellWidth
                let cellY = CGFloat(row) * cellHeight
                let cellCenter = NSPoint(x: cellX + cellWidth / 2, y: cellY + cellHeight / 2)
                
                let textSize = label.size(withAttributes: attrs)
                let textRect = NSRect(
                    x: cellCenter.x - textSize.width / 2,
                    y: cellCenter.y - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                
                label.draw(in: textRect, withAttributes: attrs)
            }
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            print("Escape pressed, hiding grid")
            (window as? GridWindow)?.hide()
            return
        }
        
        guard let chars = event.characters?.uppercased(), chars.count == 1 else {
            print("WARNING: Could not get characters from key event")
            return
        }
        let char = chars[chars.startIndex]
        guard char >= "A" && char <= "Z" else {
            print("Ignored non-letter key: \(char)")
            return
        }
        
        inputBuffer.append(char)
        print("Input buffer: \(inputBuffer)")
        if inputBuffer.count == 2 {
            handleClick(code: inputBuffer)
            inputBuffer = ""
        }
    }
    
    func handleClick(code: String) {
        let colChar = code[code.startIndex]
        let rowChar = code[code.index(code.startIndex, offsetBy: 1)]
        
        guard colChar >= "A", colChar <= "J",
              rowChar >= "A", rowChar <= "G" else {
            print("Invalid code: \(code), hiding grid")
            (window as? GridWindow)?.hide()
            return
        }
        
        let col = Int(colChar.asciiValue! - Character("A").asciiValue!)
        let row = Int(rowChar.asciiValue! - Character("A").asciiValue!)
        
        let cellWidth = bounds.width / CGFloat(columns)
        let cellHeight = bounds.height / CGFloat(rows)
        
        let localX = CGFloat(col) * cellWidth + cellWidth / 2
        let localY = CGFloat(row) * cellHeight + cellHeight / 2
        
        let windowPoint = convert(NSPoint(x: localX, y: localY), to: nil)
        guard let screenRect = window?.convertToScreen(NSRect(origin: windowPoint, size: .zero)) else {
            print("ERROR: Could not convert to screen coordinates")
            (window as? GridWindow)?.hide()
            return
        }
        
        let clickPoint = screenRect.origin
        let screenHeight = NSScreen.main!.frame.height
        let cgClickPoint = CGPoint(x: clickPoint.x, y: screenHeight - clickPoint.y)
        print("Clicking at code: \(code), screen position: (\(cgClickPoint.x), \(cgClickPoint.y))")
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        guard let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: cgClickPoint, mouseButton: .left),
              let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: cgClickPoint, mouseButton: .left) else {
            print("ERROR: Could not create mouse events")
            (window as? GridWindow)?.hide()
            return
        }
        
        downEvent.post(tap: .cghidEventTap)
        upEvent.post(tap: .cghidEventTap)
        
        (window as? GridWindow)?.hide()
    }
    
    func reset() {
        inputBuffer = ""
    }
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
