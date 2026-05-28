import SwiftUI

/// A scrollable transcript feed that highlights PUA phrases with yellow
/// background and red text.
struct TranscriptStreamView: View {
    let segments: [TranscriptSegment]
    let isRunning: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.tiffany)
                Text("語音串流")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Palette.tiffany)
                Spacer()
                Text("\(segments.count) 段")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.panel)

            Divider()
                .background(Palette.tiffany.opacity(0.15))

            if segments.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.2))
                    Text(isRunning ? "等待語音中..." : "開始偵測後將顯示語音內容")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 2) {
                            ForEach(segments.reversed()) { segment in
                                TranscriptRow(segment: segment)
                                    .id(segment.id)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .frame(maxHeight: 220)
                    .onChange(of: segments.count) { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(segments.last?.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Palette.panel.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Palette.tiffany.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

/// A single row in the transcript feed.
struct TranscriptRow: View {
    let segment: TranscriptSegment

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Timestamp
            Text(segment.formattedTime)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .frame(width: 52, alignment: .leading)

            // Highlighted text
            highlightedText
                .font(.system(size: 12, weight: .medium))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            // Score badge
            if segment.score >= 20 {
                Text("\(Int(segment.score))")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(scoreColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(scoreColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(segment.hasHits ? Palette.warning.opacity(0.08) : Color.clear)
    }

    /// Build the text with PUA hits highlighted in yellow + red.
    @ViewBuilder
    private var highlightedText: some View {
        if segment.hits.isEmpty {
            Text(segment.text)
                .foregroundColor(.white.opacity(0.45))
        } else {
            highlightBody
        }
    }

    private var highlightBody: some View {
        // Collect all hit ranges
        let text = segment.text
        let lowerText = text.lowercased()
        var ranges: [(range: Range<String.Index>, hit: PUAClassifier.Hit)] = []

        for hit in segment.hits {
            let lowerPattern = hit.phrase.lowercased()
            var searchStart = lowerText.startIndex
            while let found = lowerText[searchStart...].range(of: lowerPattern) {
                ranges.append((found, hit))
                searchStart = found.upperBound
            }
        }

        // Sort by position and merge overlapping ranges
        ranges.sort { $0.range.lowerBound < $1.range.lowerBound }
        var mergedRanges: [(range: ClosedRange<Int>, hit: PUAClassifier.Hit)] = []
        var currentStart: Int? = nil
        var currentEnd: Int = 0
        var currentHit: PUAClassifier.Hit? = nil

        for (range, hit) in ranges {
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let end = text.distance(from: text.startIndex, to: range.upperBound) - 1
            if currentStart == nil {
                currentStart = start
                currentEnd = end
                currentHit = hit
            } else if start <= currentEnd + 1 {
                currentEnd = max(currentEnd, end)
                // Pick the higher-weight hit for merged range
                if hit.weight > (currentHit?.weight ?? 0) {
                    currentHit = hit
                }
            } else {
                if let cs = currentStart, let ch = currentHit {
                    mergedRanges.append((cs...currentEnd, ch))
                }
                currentStart = start
                currentEnd = end
                currentHit = hit
            }
        }
        if let cs = currentStart, let ch = currentHit {
            mergedRanges.append((cs...currentEnd, ch))
        }

        // Build attributed-like text with highlighted ranges
        if mergedRanges.isEmpty {
            Text(text).foregroundColor(.white.opacity(0.45))
        } else {
            var result = Text("")
            var pos = 0
            let chars = Array(text)
            for mr in mergedRanges {
                // Normal text before
                if mr.range.lowerBound > pos {
                    let normal = String(chars[pos..<mr.range.lowerBound])
                    result = result + Text(normal).foregroundColor(.white.opacity(0.45))
                }
                // Highlighted text
                let highlighted = String(chars[mr.range.lowerBound...mr.range.upperBound])
                result = result + Text(highlighted)
                    .foregroundColor(.red)
                    .bold()
                    + Text("")
                pos = mr.range.upperBound + 1
            }
            // Remaining normal text
            if pos < chars.count {
                let remaining = String(chars[pos...])
                result = result + Text(remaining).foregroundColor(.white.opacity(0.45))
            }
            return result
        }
    }

    private var scoreColor: Color {
        if segment.score >= 86 { return Palette.danger }
        if segment.score >= 60 { return Palette.warning }
        return .white.opacity(0.3)
    }
}

extension TranscriptSegment {
    var hasHits: Bool { !hits.isEmpty }
}
