import AppKit

let size = NSSize(width: 1024, height: 1024)
let origin = NSPoint(x: 0, y: 0)
let fullRect = NSRect(origin: origin, size: size)
let SO = NSCompositingOperation.sourceOver
let SAT = NSCompositingOperation.sourceAtop

func buildArt() -> Data {
    let bg = NSImage(size: size)
    bg.lockFocus()
    NSGradient(colors: [
        NSColor(srgbRed: 0.13, green: 0.44, blue: 0.96, alpha: 1),
        NSColor(srgbRed: 0.05, green: 0.14, blue: 0.55, alpha: 1)
    ])!.draw(in: fullRect, angle: -90)
    bg.unlockFocus()

    let overlay = NSImage(size: size)
    func symbol(_ name: String, _ pt: CGFloat, _ rect: NSRect) {
        let cfg = NSImage.SymbolConfiguration(pointSize: pt, weight: .semibold)
        let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
        overlay.lockFocus()
        sym.draw(in: rect, from: NSRect.zero, operation: SO, fraction: 1.0)
        NSColor.white.set()
        fullRect.fill(using: SAT)
        overlay.unlockFocus()
    }
    symbol("phone.fill", 560, NSRect(x: 232, y: 240, width: 560, height: 560))
    symbol("magnifyingglass", 340, NSRect(x: 546, y: 118, width: 340, height: 340))

    let img = NSImage(size: size)
    img.lockFocus()
    bg.draw(at: origin, from: fullRect, operation: SO, fraction: 1.0)
    overlay.draw(at: origin, from: fullRect, operation: SO, fraction: 1.0)
    img.unlockFocus()

    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { fatalError() }
    return png
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
try! buildArt().write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
