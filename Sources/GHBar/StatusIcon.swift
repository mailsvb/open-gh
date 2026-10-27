import AppKit

enum StatusIcon {
  /// Draws the Lucide `git-pull-request-arrow` icon as an 18x18 NSImage. Without a badge
  /// it is a template image; with one it can't be (the dot needs its color), so the
  /// strokes use textColor (opaque, unlike labelColor, so overlapping strokes don't
  /// darken), which the drawing handler resolves per appearance.
  static func make(badge: NSColor?) -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
      let scale: CGFloat = 18.0 / 24.0

      (badge == nil ? NSColor.black : NSColor.textColor).setStroke()

      let strokeWidth: CGFloat = 2.0 * scale
      let lineJoin: NSBezierPath.LineJoinStyle = .round
      let lineCap: NSBezierPath.LineCapStyle = .round

      func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: x * scale, y: (24.0 - y) * scale)
      }

      // 1) Circle at (5, 6) r=3
      let c1Center = p(5, 6)
      let c1Radius = 3.0 * scale
      let circle1 = NSBezierPath(
        ovalIn: NSRect(
          x: c1Center.x - c1Radius, y: c1Center.y - c1Radius,
          width: c1Radius * 2, height: c1Radius * 2
        )
      )
      circle1.lineWidth = strokeWidth
      circle1.lineJoinStyle = lineJoin
      circle1.stroke()

      // 2) Line from (5, 9) to (5, 21)
      let line1 = NSBezierPath()
      line1.move(to: p(5, 9))
      line1.line(to: p(5, 21))
      line1.lineWidth = strokeWidth
      line1.lineCapStyle = lineCap
      line1.stroke()

      // 3) Circle at (19, 18) r=3
      let c2Center = p(19, 18)
      let c2Radius = 3.0 * scale
      let circle2 = NSBezierPath(
        ovalIn: NSRect(
          x: c2Center.x - c2Radius, y: c2Center.y - c2Radius,
          width: c2Radius * 2, height: c2Radius * 2
        )
      )
      circle2.lineWidth = strokeWidth
      circle2.lineJoinStyle = lineJoin
      circle2.stroke()

      // 4) Arrow: M15,9 L12,6 L15,3
      let arrow = NSBezierPath()
      arrow.move(to: p(15, 9))
      arrow.line(to: p(12, 6))
      arrow.line(to: p(15, 3))
      arrow.lineWidth = strokeWidth
      arrow.lineCapStyle = lineCap
      arrow.lineJoinStyle = lineJoin
      arrow.stroke()

      // 5) Path: M12,6 h5 a2,2 0 0 1 2,2 v7
      let connector = NSBezierPath()
      connector.move(to: p(12, 6))
      connector.line(to: p(17, 6))
      let arcCenter = p(17, 8)
      let arcRadius = 2.0 * scale
      connector.appendArc(
        withCenter: arcCenter,
        radius: arcRadius,
        startAngle: 90,
        endAngle: 0,
        clockwise: true
      )
      connector.line(to: p(19, 15))
      connector.lineWidth = strokeWidth
      connector.lineCapStyle = lineCap
      connector.lineJoinStyle = lineJoin
      connector.stroke()

      // 6) Status dot in the top-right corner, knocked out of the strokes beneath it
      if let badge {
        let dotRadius: CGFloat = 2.5
        let gap: CGFloat = 0.75
        let dotCenter = NSPoint(x: rect.maxX - dotRadius, y: rect.maxY - dotRadius)
        let knockoutRadius = dotRadius + gap
        let knockout = NSBezierPath(ovalIn: NSRect(
          x: dotCenter.x - knockoutRadius, y: dotCenter.y - knockoutRadius,
          width: knockoutRadius * 2, height: knockoutRadius * 2
        ))
        NSGraphicsContext.current?.compositingOperation = .clear
        knockout.fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        badge.setFill()
        NSBezierPath(ovalIn: NSRect(
          x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius,
          width: dotRadius * 2, height: dotRadius * 2
        )).fill()
      }

      return true
    }
    image.isTemplate = badge == nil

    return image
  }
}
