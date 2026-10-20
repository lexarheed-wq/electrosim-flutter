import AppKit
import Foundation

let inputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let cases = [
  "f9_compact_properties",
  "g12rq_real_industrial_set0",
  "g12rq_premium_rcd2p_palette_board",
  "g5_industrial_off_on_trip",
]
let cellWidth: CGFloat = 560
let cellHeight: CGFloat = 440
let canvas = NSImage(size: NSSize(width: cellWidth * 2, height: cellHeight * CGFloat(cases.count)))

canvas.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: canvas.size).fill()

for (caseIndex, name) in cases.enumerated() {
  for (imageIndex, suffix) in ["masterImage", "testImage"].enumerated() {
    let imageURL = inputDirectory.appendingPathComponent("\(name)_\(suffix).png")
    guard let image = NSImage(contentsOf: imageURL) else {
      continue
    }
    let column = imageIndex
    let row = caseIndex
    let x = CGFloat(column) * cellWidth
    let y = CGFloat(cases.count - row - 1) * cellHeight
    let title = "\(name) · \(suffix == "masterImage" ? "reference" : "runner")"
    let titleStyle: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 16, weight: .bold),
      .foregroundColor: NSColor.black,
    ]
    (title as NSString).draw(at: NSPoint(x: x + 12, y: y + cellHeight - 28), withAttributes: titleStyle)

    let sourceSize = image.size
    let available = NSRect(x: x + 12, y: y + 12, width: cellWidth - 24, height: cellHeight - 50)
    let scale = min(available.width / sourceSize.width, available.height / sourceSize.height)
    let destination = NSRect(
      x: available.midX - sourceSize.width * scale / 2,
      y: available.midY - sourceSize.height * scale / 2,
      width: sourceSize.width * scale,
      height: sourceSize.height * scale
    )
    image.draw(in: destination, from: .zero, operation: .copy, fraction: 1)
  }
}

canvas.unlockFocus()
guard
  let tiff = canvas.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.62])
else {
  fatalError("Could not encode visual diagnostic contact sheet.")
}
try jpeg.write(to: outputURL)
