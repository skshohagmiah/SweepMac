import SwiftUI
import Charts

struct DiskChartView: View {
    let diskInfo: DiskInfo

    var body: some View {
        ZStack {
            Chart {
                SectorMark(
                    angle: .value("Used", diskInfo.usedSpace),
                    innerRadius: .ratio(0.7),
                    angularInset: 2
                )
                .foregroundStyle(usageGradient)

                SectorMark(
                    angle: .value("Free", diskInfo.freeSpace),
                    innerRadius: .ratio(0.7),
                    angularInset: 2
                )
                .foregroundStyle(Color.green.opacity(0.3))
            }

            VStack(spacing: 2) {
                Text("\(Int(diskInfo.usedPercentage))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("used")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var usageGradient: some ShapeStyle {
        switch diskInfo.usageLevel {
        case .healthy:
            return AnyShapeStyle(Color.green.gradient)
        case .warning:
            return AnyShapeStyle(Color.orange.gradient)
        case .critical:
            return AnyShapeStyle(Color.red.gradient)
        }
    }
}
