import SwiftUI
import UIKit

// MARK: - Colors

enum BlopColor {
    static let background = Color(uiColor: .blopBackground)
    static let ink        = Color(uiColor: .blopInk)
    static let accent     = Color(uiColor: .blopAccent)
    static let faint      = Color(uiColor: .blopFaint)
    static let warning    = Color(uiColor: .blopWarning)
    static let surface    = Color(uiColor: .blopSurface)
}

extension UIColor {
    static let blopBackground = UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "#1A1918") : UIColor(hex: "#F5F0E8")
    })
    static let blopInk = UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "#F0EBE1") : UIColor(hex: "#1C1B1A")
    })
    static let blopAccent = UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "#C4A882") : UIColor(hex: "#5C4A3A")
    })
    static let blopFaint = UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "#3A3632") : UIColor(hex: "#E8E2D9")
    })
    static let blopWarning  = UIColor(hex: "#C87941")
    static let blopSurface  = UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "#231F1C") : UIColor(hex: "#EDE8DF")
    })

    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// Keep Color(hex:) for any callsites that still use it
extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex)) }
}

// MARK: - Typography

enum BlopFont {
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func body(_ size: CGFloat = 16) -> Font { serif(size) }
    static let signifier: Font = mono(16, weight: .medium)
    static let dateHeader: Font = serif(22, weight: .semibold)
    static let sectionHeader: Font = mono(11, weight: .medium)
}

// MARK: - Spacing

enum BlopSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - Background

struct DotGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 20
            let dotSize: CGFloat = 1.5
            var x: CGFloat = spacing
            while x < size.width {
                var y: CGFloat = spacing
                while y < size.height {
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(BlopColor.faint))
                    y += spacing
                }
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }
}
