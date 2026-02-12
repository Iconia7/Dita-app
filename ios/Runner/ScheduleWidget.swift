import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), image: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), image: getImage())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleEntry(date: Date(), image: getImage())
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }

    func getImage() -> UIImage? {
        let userDefaults = UserDefaults(suiteName: "group.dita_app")
        if let imagePath = userDefaults?.string(forKey: "widget_image") {
            return UIImage(contentsOfFile: imagePath)
        }
        return nil
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let image: UIImage?
}

struct ScheduleWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                VStack {
                    Text("DITA")
                        .font(.headline)
                    Text("No Schedule Data")
                        .font(.caption)
                }
            }
        }
    }
}

struct ScheduleWidget: Widget {
    let kind: String = "ScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ScheduleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("DITA Schedule")
        .description("View your daily class schedule.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
