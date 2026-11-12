// Draws the Lock In app icon at 1024px: gradient squircle + white padlock with a checkmark.
import AppKit
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
let shape = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow(); shadow.shadowBlurRadius = 30; shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35); shadow.set()
NSGradient(colors: [NSColor(red: 0.36, green: 0.20, blue: 0.85, alpha: 1), NSColor(red: 0.98, green: 0.45, blue: 0.25, alpha: 1)])!
    .draw(in: shape, angle: -55)
NSGraphicsContext.current?.restoreGraphicsState()
let cfg = NSImage.SymbolConfiguration(pointSize: 470, weight: .bold).applying(.init(paletteColors: [.white]))
if let sym = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
    let s = sym.size
    sym.draw(in: NSRect(x: (size - s.width)/2, y: (size - s.height)/2 + 10, width: s.width, height: s.height))
}
let ccfg = NSImage.SymbolConfiguration(pointSize: 150, weight: .heavy).applying(.init(paletteColors: [NSColor(red: 0.45, green: 0.25, blue: 0.85, alpha: 1)]))
if let chk = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?.withSymbolConfiguration(ccfg) {
    let s = chk.size
    chk.draw(in: NSRect(x: (size - s.width)/2, y: (size - s.height)/2 - 70, width: s.width, height: s.height))
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
