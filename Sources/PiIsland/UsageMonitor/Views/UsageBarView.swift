//
//  UsageBarView.swift
//  PiIsland
//
//  Usage bar visualization component
//

import SwiftUI

struct UsageBarView: View {
    let percentage: Double
    let height: CGFloat = 4

    private var statusColor: Color {
        switch percentage {
        case 0..<50: return .green
        case 50..<80: return .orange
        case 80..<95: return .yellow
        default: return .red
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.gray.opacity(0.2))

                // Fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(statusColor)
                    .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(percentage) / 100)))
            }
        }
        .frame(height: height)
    }
}

#Preview {
    VStack(spacing: 8) {
        UsageBarView(percentage: 25)
        UsageBarView(percentage: 55)
        UsageBarView(percentage: 85)
        UsageBarView(percentage: 95)
    }
    .padding()
    .frame(width: 200)
}
