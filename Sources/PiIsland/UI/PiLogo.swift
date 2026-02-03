//
//  PiLogo.swift
//  PiIsland
//
//  Pi logo as a SwiftUI Shape
//

import SwiftUI

/// Pi logo shape - a stylized "Pi" mark
struct PiLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Scale to fit the rect (original viewBox is 800x800)
        let scale = min(rect.width, rect.height) / 800
        let offsetX = (rect.width - 800 * scale) / 2
        let offsetY = (rect.height - 800 * scale) / 2
        
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }
        
        // P shape outer boundary (clockwise)
        path.move(to: point(165.29, 165.29))
        path.addLine(to: point(517.36, 165.29))
        path.addLine(to: point(517.36, 400))
        path.addLine(to: point(400, 400))
        path.addLine(to: point(400, 517.36))
        path.addLine(to: point(282.65, 517.36))
        path.addLine(to: point(282.65, 634.72))
        path.addLine(to: point(165.29, 634.72))
        path.closeSubpath()
        
        // P shape inner hole (counter-clockwise for even-odd fill)
        path.move(to: point(282.65, 282.65))
        path.addLine(to: point(282.65, 400))
        path.addLine(to: point(400, 400))
        path.addLine(to: point(400, 282.65))
        path.closeSubpath()
        
        // i dot
        path.move(to: point(517.36, 400))
        path.addLine(to: point(634.72, 400))
        path.addLine(to: point(634.72, 634.72))
        path.addLine(to: point(517.36, 634.72))
        path.closeSubpath()
        
        return path
    }
}

/// Pi logo view with optional animation
struct PiLogo: View {
    let size: CGFloat
    var isAnimating: Bool = false
    var isPulsing: Bool = false  // For hint state - gentler pulse
    var bounce: Bool = false     // One-time bounce when response is ready
    var color: Color = .white

    @State private var bouncePhase: CGFloat = 0

    var body: some View {
        PiLogoShape()
            .fill(color.opacity(effectiveOpacity), style: FillStyle(eoFill: true))
            .frame(width: size, height: size)
            .scaleEffect(effectiveScale)
            .offset(y: bounceOffset)
            .animation(effectiveAnimation, value: isAnimating)
            .animation(effectiveAnimation, value: isPulsing)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: bouncePhase)
            .onChange(of: bounce) { _, shouldBounce in
                if shouldBounce {
                    performBounce()
                }
            }
    }

    private var effectiveOpacity: Double {
        if isAnimating || isPulsing {
            return 1.0
        }
        return 0.6
    }

    private var effectiveScale: CGFloat {
        if isAnimating {
            return 1.1
        } else if isPulsing {
            return 1.15
        }
        return 1.0
    }

    private var bounceOffset: CGFloat {
        // Subtle bounce - goes down slightly then back up
        bouncePhase * size * 0.15
    }

    private var effectiveAnimation: Animation {
        if isAnimating {
            return .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        } else if isPulsing {
            return .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
        }
        return .default
    }

    private func performBounce() {
        // Subtle down phase
        withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
            bouncePhase = 1.0
        }

        // Return to original position after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                bouncePhase = 0
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PiLogo(size: 64, isAnimating: false)
        PiLogo(size: 64, isAnimating: true)
        PiLogo(size: 32)
        PiLogo(size: 16)
    }
    .padding()
    .background(Color.black)
}
