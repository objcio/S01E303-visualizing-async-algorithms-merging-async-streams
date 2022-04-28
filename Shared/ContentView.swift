@preconcurrency import SwiftUI
import AsyncAlgorithms

enum Value: Hashable, Sendable {
    case int(Int)
    case string(String)
}

struct Event: Identifiable, Hashable, Sendable {
    var id: Int
    var time: TimeInterval
    var color: Color = .green
    var value: Value
}

var sampleInt: [Event] = [
    .init(id: 0, time:  0, color: .red, value: .int(1)),
    .init(id: 1, time:  1, color: .red, value: .int(2)),
    .init(id: 2, time:  2, color: .red, value: .int(3)),
    .init(id: 3, time:  5, color: .red, value: .int(4)),
    .init(id: 4, time:  8, color: .red, value: .int(5)),
]

var sampleString: [Event] = [
    .init(id: 100_0, time:  1.5, value: .string("a")),
    .init(id: 100_1, time:  2.5, value: .string("b")),
    .init(id: 100_2, time:  4.5, value: .string("c")),
    .init(id: 100_3, time:  6.5, value: .string("d")),
    .init(id: 100_4, time:  7.5, value: .string("e")),
]

extension Value: View {
    var body: some View {
        switch self {
        case .int(let i): Text("\(i)")
        case .string(let s): Text(s)
        }
    }
}

struct TimelineView: View {
    var events: [Event]
    var duration: TimeInterval
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary)
                    .frame(height: 1)
                ForEach(0..<Int(duration.rounded(.up))) { tick in
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(.secondary)
                        .alignmentGuide(.leading) { dim in
                            let relativeTime = CGFloat(tick) / duration
                            return -(proxy.size.width-30) * relativeTime
                        }
                }
                .offset(x: 15)
                ForEach(events) { event in
                    event.value
                        .frame(width: 30, height: 30)
                        .background {
                            Circle().fill(event.color)
                        }
                        .alignmentGuide(.leading) { dim in
                            let relativeTime = event.time / duration
                            return -(proxy.size.width-30) * relativeTime
                        }
                        .help("\(event.time)")
                }
            }
        }
        .frame(height: 30)
    }
}

extension Array where Element == Event {
    @MainActor
    func stream() -> AsyncStream<Event> {
        AsyncStream { cont in
            for event in self {
                Timer.scheduledTimer(withTimeInterval: event.time/10, repeats: false) { _ in
                    cont.yield(event)
                    if event == last {
                        cont.finish()
                    }
                }
            }
        }
    }
}

func runMerge(_ events1: [Event], _ events2: [Event]) async -> [Event] {
    let merged = await merge(events1.stream(), events2.stream())
    return await Array(merged)
}

struct ContentView: View {
    @State var result: [Event]? = nil
    
    var duration: TimeInterval {
        max(sampleInt.last!.time, sampleString.last!.time)
    }
    
    var body: some View {
        VStack {
            TimelineView(events: sampleInt, duration: duration)
            TimelineView(events: sampleString, duration: duration)
            TimelineView(events: result ?? [], duration: duration)
                .opacity(result == nil ? 0.5 : 1)
        }
        .padding(20)
        .task {
            result = await runMerge(sampleInt, sampleString)
        }
    }
}
