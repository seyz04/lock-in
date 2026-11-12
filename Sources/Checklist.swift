import SwiftUI
import AppKit

// Today's checklist: an after-class review for every class that meets today, plus dated to-dos
// from tasks.json and (optionally) the live Brightspace calendar feed. Checking things off plays
// a sound and fills a progress bar, so finished work is visible.

struct ClassMeeting {
    let course: Course?
    let label: String
    let days: [Int]
    let start: String
    let end: String
}

struct ChecklistItem: Identifiable {
    let id: String
    let course: Course?
    let title: String
    let detail: String
    let when: String      // short label: "after 1:45 PM", "due tomorrow"
    let sortKey: String
}

func clock(_ hhmm: String) -> String {
    let p = hhmm.split(separator: ":").compactMap { Int($0) }
    guard p.count == 2 else { return hhmm }
    let h = p[0] % 12 == 0 ? 12 : p[0] % 12
    return String(format: "%d:%02d %@", h, p[1], p[0] < 12 ? "AM" : "PM")
}

/// Guess the course from a Brightspace event title.
func courseFromText(_ s: String) -> Course? {
    let t = s.lowercased()
    if t.contains("fren") || t.contains("french") || t.contains("pour le") { return .french }
    if t.contains("macro") || t.contains("econ-ua") { return .macro }
    if t.contains("decision") || t.contains("mult-ub") { return .decision }
    if t.contains("math") || t.contains("mfe") { return .mfe }
    return nil
}

/// Minimal iCalendar reader: SUMMARY + DTSTART/DTEND of each VEVENT.
func parseICS(_ text: String) -> [(title: String, date: Date)] {
    let unfolded = text.replacingOccurrences(of: "\r\n ", with: "").replacingOccurrences(of: "\n ", with: "")
    var out: [(String, Date)] = []
    var title = "", date: Date? = nil
    let utc = DateFormatter(); utc.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; utc.timeZone = TimeZone(identifier: "UTC")
    let local = DateFormatter(); local.dateFormat = "yyyyMMdd'T'HHmmss"
    let day = DateFormatter(); day.dateFormat = "yyyyMMdd"
    for raw in unfolded.components(separatedBy: .newlines) {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line == "BEGIN:VEVENT" { title = ""; date = nil }
        else if line.hasPrefix("SUMMARY") { title = line.split(separator: ":", maxSplits: 1).last.map(String.init) ?? "" }
        else if line.hasPrefix("DTEND") || (line.hasPrefix("DTSTART") && date == nil) {
            let v = line.split(separator: ":").last.map(String.init) ?? ""
            date = utc.date(from: v) ?? local.date(from: v) ?? day.date(from: v) ?? date
        }
        else if line == "END:VEVENT", let d = date, !title.isEmpty {
            out.append((title.replacingOccurrences(of: "\\,", with: ","), d))
        }
    }
    return out
}

final class Checklist: ObservableObject {
    @Published var items: [ChecklistItem] = []
    @Published var checked: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "checklistDone") ?? [])
    @Published var justChecked: String? = nil

    var doneCount: Int { items.filter { checked.contains($0.id) }.count }

    func toggle(_ item: ChecklistItem) {
        if checked.contains(item.id) {
            checked.remove(item.id)
        } else {
            checked.insert(item.id)
            justChecked = item.id
            NSSound(named: doneCount == items.count ? "Hero" : "Glass")?.play()
        }
        UserDefaults.standard.set(Array(checked), forKey: "checklistDone")
    }

    func reload() {
        guard let data = try? Data(contentsOf: appRoot.appendingPathComponent("tasks.json")),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { items = []; return }
        let today = dayKey()
        let tomorrow = dayKey(Date().addingTimeInterval(86400))
        let reviewText = obj["review"] as? String ?? "Review what you just learned"
        var list: [ChecklistItem] = []

        // After-class reviews: catching it right after class is when it clicks.
        for c in obj["classes"] as? [[String: Any]] ?? [] {
            let m = ClassMeeting(course: Course(rawValue: c["course"] as? String ?? ""), label: c["label"] as? String ?? "Class",
                                 days: c["days"] as? [Int] ?? [], start: c["start"] as? String ?? "", end: c["end"] as? String ?? "")
            guard m.days.contains(weekdayIndex) else { continue }
            list.append(ChecklistItem(id: "review-\(m.label)-\(today)", course: m.course, title: "After \(m.label): 15-min review",
                                      detail: reviewText, when: "after \(clock(m.end))", sortKey: "1-\(m.end)"))
        }

        // Dated to-dos: due today or tomorrow, or overdue and still unchecked.
        for t in obj["tasks"] as? [[String: Any]] ?? [] {
            guard let id = t["id"] as? String, let due = t["due"] as? String else { continue }
            let overdue = due < today && !checked.contains(id)
            guard due == today || due == tomorrow || overdue else { continue }
            list.append(ChecklistItem(id: id, course: Course(rawValue: t["course"] as? String ?? ""), title: t["title"] as? String ?? "",
                                      detail: t["detail"] as? String ?? "",
                                      when: overdue ? "overdue" : (due == today ? "due today" : "due tomorrow"),
                                      sortKey: (overdue ? "0-" : due == today ? "2-" : "3-") + id))
        }
        items = list.sorted { $0.sortKey < $1.sortKey }

        // Live Brightspace calendar, if a subscription link is set.
        if let s = obj["brightspaceICS"] as? String, let url = URL(string: s), !s.isEmpty {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data, let text = String(data: data, encoding: .utf8) else { return }
                let events = parseICS(text).filter { dayKey($0.date) == today || dayKey($0.date) == tomorrow }
                DispatchQueue.main.async {
                    let known = Set(self.items.map { $0.title.lowercased() })
                    for e in events where !known.contains(e.title.lowercased()) {
                        let due = dayKey(e.date)
                        self.items.append(ChecklistItem(id: "bs-\(due)-\(e.title)", course: courseFromText(e.title), title: e.title,
                                                        detail: "From Brightspace", when: due == today ? "due today" : "due tomorrow",
                                                        sortKey: (due == today ? "2-" : "3-") + e.title))
                    }
                    self.items.sort { $0.sortKey < $1.sortKey }
                }
            }.resume()
        }
    }
}

struct ChecklistCard: View {
    @ObservedObject var list: Checklist
    let open: (Course) -> Void

    var body: some View {
        if !list.items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Today's checklist").font(.headline)
                    Spacer()
                    Text(list.doneCount == list.items.count ? "All done 🎉" : "\(list.doneCount) of \(list.items.count) ✓")
                        .font(.callout.bold().monospacedDigit())
                        .foregroundStyle(list.doneCount == list.items.count ? .green : .secondary)
                }
                ProgressView(value: Double(list.doneCount), total: Double(list.items.count))
                    .tint(.green)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: list.doneCount)
                ForEach(list.items) { item in row(item) }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        }
    }

    func row(_ item: ChecklistItem) -> some View {
        let done = list.checked.contains(item.id)
        let pop = list.justChecked == item.id
        return HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { list.toggle(item) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { if list.justChecked == item.id { list.justChecked = nil } }
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(done ? .green : (item.course?.tint ?? .secondary))
                    .scaleEffect(pop ? 1.35 : 1)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).strikethrough(done).foregroundStyle(done ? .secondary : .primary)
                Text(item.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.when).font(.caption.bold())
                .foregroundStyle(item.when == "overdue" ? .red : item.when == "due today" ? .orange : .secondary)
            if let c = item.course, item.id.hasPrefix("review-") {
                Button("Start") { open(c) }.font(.caption)
            }
        }
        .opacity(done ? 0.6 : 1)
    }
}
