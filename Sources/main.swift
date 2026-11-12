import SwiftUI
import AppKit
import CryptoKit
import ServiceManagement

// Lock In: one study app for French, Macro, Decision Models and Math MFE.
// Questions live in JSON files under banks/<course>/ (next to this project), loaded at launch,
// so adding questions never needs a rebuild. Missed questions come back with spaced review (Leitner boxes).

let appRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("School/Study Apps/LockIn")
let banksDir = appRoot.appendingPathComponent("banks")

// MARK: - Courses

enum Course: String, CaseIterable, Identifiable {
    case french, macro, decision, mfe
    var id: String { rawValue }
    var title: String {
        switch self {
        case .french: return "French"
        case .macro: return "Macro"
        case .decision: return "Decision Models"
        case .mfe: return "Math (MFE)"
        }
    }
    var icon: String {
        switch self {
        case .french: return "text.bubble"
        case .macro: return "chart.line.uptrend.xyaxis"
        case .decision: return "tablecells"
        case .mfe: return "function"
        }
    }
    var tint: Color {
        switch self {
        case .french: return .blue
        case .macro: return .green
        case .decision: return .orange
        case .mfe: return .purple
        }
    }
    /// Built-in practice mode for this course (formerly separate apps), if any.
    var practice: (title: String, icon: String)? {
        switch self {
        case .french: return ("Speaking", "mic.fill")
        case .mfe: return ("Calc problems", "function")
        case .decision: return ("Worked problems", "tablecells.badge.ellipsis")
        default: return nil
        }
    }

    @ViewBuilder var practiceView: some View {
        switch self {
        case .french: ShadowPracticeView()
        case .mfe: CalcPracticeView()
        case .decision: DMPracticeView()
        default: EmptyView()
        }
    }
}

// MARK: - Question model (mirrors the JSON)

struct Item: Identifiable {
    let id: String
    let deck: String
    let deckFile: String
    let stage: String         // past | current | ahead
    let topic: String?        // which lesson teaches this (lessons/<course>/<deck>.json), if any
    let type: String          // mc | fill | card | shift
    let q: String
    let choices: [String]
    let answerIndex: Int
    let accepted: [String]    // fill
    let steps: [String]       // card
    let answerText: String    // card
    let why: String
    let shift: [String: String] // shift: curve, dir, price, gdp
    let trap: String            // the small thing that usually trips you up
}

struct Deck: Identifiable {
    let id: String
    let name: String
    let stage: String
    let items: [Item]
}

// MARK: - Lessons (lessons/<course>/<deck file>.json): teach first, then practice

struct LessonStep { let doThis: String; let why: String }

struct LessonPage {
    let kind: String            // idea | example | check
    let title: String
    let text: String
    let q: String
    let steps: [LessonStep]
    let answer: String
    let choices: [String]
    let answerIndex: Int
    let why: String
}

struct Lesson: Identifiable {
    let id: String              // "<course>/<deck file>/<lesson id>"
    let topic: String
    let title: String
    let minutes: Int
    let pages: [LessonPage]
}

let lessonsDir = appRoot.appendingPathComponent("lessons")

/// deck file → lessons in teaching order
func loadLessons(_ course: Course) -> [String: [Lesson]] {
    let dir = lessonsDir.appendingPathComponent(course.rawValue)
    let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
        .filter { $0.pathExtension == "json" }
    var out: [String: [Lesson]] = [:]
    for url in files {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deck = obj["deck"] as? String,
              let raw = obj["lessons"] as? [[String: Any]] else { continue }
        out[deck] = raw.map { l in
            let topic = l["topic"] as? String ?? "main"
            let pages = (l["pages"] as? [[String: Any]] ?? []).map { p in
                LessonPage(kind: p["kind"] as? String ?? "idea",
                           title: p["title"] as? String ?? "",
                           text: p["text"] as? String ?? "",
                           q: p["q"] as? String ?? "",
                           steps: (p["steps"] as? [[String: String]] ?? []).map { LessonStep(doThis: $0["do"] ?? "", why: $0["why"] ?? "") },
                           answer: p["answer"] as? String ?? "",
                           choices: p["choices"] as? [String] ?? [],
                           answerIndex: p["answer_index"] as? Int ?? 0,
                           why: p["why"] as? String ?? "")
            }
            return Lesson(id: "\(course.rawValue)/\(deck)/\(topic)", topic: topic,
                          title: l["title"] as? String ?? "Lesson",
                          minutes: l["minutes"] as? Int ?? max(pages.count, 2), pages: pages)
        }
    }
    return out
}

// MARK: - Upcoming assessments (upcoming.json, refreshed from Google Calendar during the weekly tidy)

struct Assessment: Identifiable {
    let id = UUID()
    let course: Course
    let title: String
    let date: Date
    let estimated: Bool
    let decks: [String]

    var daysAway: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                        to: Calendar.current.startOfDay(for: date)).day ?? 0
    }
    var isThisWeek: Bool { daysAway <= 7 }
    var countdown: String {
        switch daysAway {
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "in \(daysAway) days"
        }
    }
}

func loadUpcoming() -> [Assessment] {
    guard let data = try? Data(contentsOf: appRoot.appendingPathComponent("upcoming.json")),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let events = obj["events"] as? [[String: Any]] else { return [] }
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    let today = Calendar.current.startOfDay(for: Date())
    return events.compactMap { e -> Assessment? in
        guard let c = (e["course"] as? String).flatMap(Course.init(rawValue:)),
              let title = e["title"] as? String,
              let date = (e["date"] as? String).flatMap(fmt.date(from:)),
              date >= today else { return nil }
        return Assessment(course: c, title: title, date: date,
                          estimated: e["estimated"] as? Bool ?? false,
                          decks: e["decks"] as? [String] ?? [])
    }
    .sorted { $0.date < $1.date }
}

// MARK: - Daily goals (schedule.json)

struct CourseSchedule {
    var meets: [Int] = []          // weekdays, 0 = Sunday
    var new: [Int] = Array(repeating: 5, count: 7)
    var extraDays: [Int] = []
    var extraText = ""
}

struct Schedule {
    var roundSize = 10
    var reviewCap = 20
    var examMultiplier = 2.0
    var secondsPerQuestion = 20.0
    var courses: [Course: CourseSchedule] = [:]
}

func loadSchedule() -> Schedule {
    var s = Schedule()
    guard let data = try? Data(contentsOf: appRoot.appendingPathComponent("schedule.json")),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return s }
    s.roundSize = obj["roundSize"] as? Int ?? s.roundSize
    s.reviewCap = obj["reviewCap"] as? Int ?? s.reviewCap
    s.examMultiplier = obj["examMultiplier"] as? Double ?? s.examMultiplier
    s.secondsPerQuestion = obj["secondsPerQuestion"] as? Double ?? s.secondsPerQuestion
    for (k, v) in obj["courses"] as? [String: [String: Any]] ?? [:] {
        guard let c = Course(rawValue: k) else { continue }
        var cs = CourseSchedule()
        cs.meets = v["meets"] as? [Int] ?? []
        if let n = v["new"] as? [Int], n.count == 7 { cs.new = n }
        if let e = v["extra"] as? [String: Any] {
            cs.extraDays = e["days"] as? [Int] ?? []
            cs.extraText = e["text"] as? String ?? ""
        }
        s.courses[c] = cs
    }
    return s
}

/// 0 = Sunday ... 6 = Saturday
var weekdayIndex: Int { Calendar.current.component(.weekday, from: Date()) - 1 }

func dayKey(_ d: Date = Date()) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: d)
}

func loadDecks(_ course: Course) -> [Deck] {
    let dir = banksDir.appendingPathComponent(course.rawValue)
    let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    return files.compactMap { url in
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = obj["items"] as? [[String: Any]] else { return nil }
        let name = obj["deck"] as? String ?? url.deletingPathExtension().lastPathComponent
        let stage = obj["stage"] as? String ?? "current"
        let file = url.lastPathComponent
        let items: [Item] = raw.compactMap { d in
            guard let type = d["type"] as? String, let q = d["q"] as? String else { return nil }
            let digest = SHA256.hash(data: Data((course.rawValue + "|" + q).utf8))
            let id = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
            var accepted: [String] = []
            var answerIndex = 0
            var answerText = ""
            if let a = d["answer"] as? Int { answerIndex = a }
            if let a = d["answer"] as? [String] { accepted = a }
            if let a = d["answer"] as? String { answerText = a; accepted = [a] }
            var shift: [String: String] = [:]
            for k in ["curve", "dir", "price", "gdp"] { if let v = d[k] as? String { shift[k] = v } }
            return Item(id: id, deck: name, deckFile: file, stage: stage, topic: d["topic"] as? String, type: type, q: q,
                        choices: d["choices"] as? [String] ?? [],
                        answerIndex: answerIndex, accepted: accepted,
                        steps: d["steps"] as? [String] ?? [], answerText: answerText,
                        why: d["why"] as? String ?? "", shift: shift, trap: d["trap"] as? String ?? "")
        }
        return Deck(id: file, name: name, stage: stage, items: items)
    }
}

// MARK: - Spaced review progress

struct Progress: Codable {
    var box = 0              // 0 = new, 1...6 = Leitner box
    var due = Date.distantPast
    var seen = 0
    var misses = 0
}

/// Days until a card in each box comes back after a correct answer.
let boxDays = [0, 1, 3, 7, 14, 30, 60]

final class ProgressStore: ObservableObject {
    @Published private(set) var map: [String: Progress] = [:]
    /// day ("yyyy-MM-dd") → course → ["new": n, "review": n]
    @Published private(set) var daily: [String: [String: [String: Int]]] = [:]
    private let url: URL
    private let dailyURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LockIn", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("progress.json")
        dailyURL = dir.appendingPathComponent("daily.json")
        if let data = try? Data(contentsOf: url),
           let m = try? JSONDecoder().decode([String: Progress].self, from: data) { map = m }
        if let data = try? Data(contentsOf: dailyURL),
           let d = try? JSONDecoder().decode([String: [String: [String: Int]]].self, from: data) { daily = d }
    }

    func today(_ c: Course) -> (new: Int, review: Int) {
        let d = daily[dayKey()]?[c.rawValue] ?? [:]
        return (d["new"] ?? 0, d["review"] ?? 0)
    }

    func bumpToday(_ c: Course, isNew: Bool) {
        daily[dayKey(), default: [:]][c.rawValue, default: [:]][isNew ? "new" : "review", default: 0] += 1
        if let data = try? JSONEncoder().encode(daily) { try? data.write(to: dailyURL, options: .atomic) }
    }

    /// Days this week (Mon-Sun) with at least one answer, as weekday indexes (0 = Sunday).
    var studiedThisWeek: Set<Int> {
        let cal = Calendar.current
        var out: Set<Int> = []
        for offset in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let wd = cal.component(.weekday, from: d) - 1
            if (daily[dayKey(d)] ?? [:]).values.contains(where: { $0.values.reduce(0, +) > 0 }) { out.insert(wd) }
            if wd == 1 { break } // stop at Monday
        }
        return out
    }

    subscript(id: String) -> Progress { map[id] ?? Progress() }

    func record(_ id: String, correct: Bool) {
        var p = self[id]
        p.seen += 1
        if correct {
            p.box = min(p.box + 1, boxDays.count - 1)
            p.due = Calendar.current.date(byAdding: .day, value: boxDays[p.box], to: Date()) ?? Date()
        } else {
            p.misses += 1
            p.box = 1
            p.due = Date() // due again right away (comes back later this session) and stays due until you get it
        }
        map[id] = p
        if let data = try? JSONEncoder().encode(map) { try? data.write(to: url, options: .atomic) }
    }

    func isDue(_ id: String) -> Bool {
        guard let p = map[id] else { return false }
        return p.due <= Date()
    }

    func isMissed(_ id: String) -> Bool { (map[id]?.misses ?? 0) > 0 && (map[id]?.box ?? 0) <= 1 }
}

// MARK: - Session

enum Mode: String, CaseIterable, Identifiable {
    case smart = "Lock in"      // exam decks this week → due misses → new (current, then ahead, then past) → rest
    case missed = "Missed only"
    case all = "Shuffle all"
    var id: String { rawValue }
}

final class Session: ObservableObject {
    let course: Course
    let store: ProgressStore
    @Published var decks: [Deck] = []
    @Published var deckFilter: String? = nil { didSet { restart() } }
    @Published var mode: Mode = .smart { didSet { restart() } }
    @Published var queue: [Item] = []
    @Published var current: Item?
    @Published var answered = false
    @Published var correct = false
    @Published var selected: Int? = nil
    @Published var typed = ""
    @Published var revealed = false
    @Published var hints = 0
    @Published var showSolution = false
    @Published var shiftPick: [String: String] = [:]
    @Published var accentNote = ""
    @Published var right = 0
    @Published var done = 0
    @Published var upcoming: [Assessment] = []
    @Published var roundAnswered = 0
    @Published var roundRight = 0
    @Published var showRoundDone = false
    @Published var bonus = false
    @Published var lessons: [String: [Lesson]] = [:]
    @Published var activeLesson: Lesson? = nil
    @Published var lessonsDone: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "lessonsDone") ?? [])
    var schedule = Schedule()

    /// The lesson that teaches this item, if it hasn't been done yet.
    func pendingLesson(for item: Item) -> Lesson? {
        guard let list = lessons[item.deckFile], !list.isEmpty else { return nil }
        // Tagged items get their topic's lesson; untagged items only get a deck-wide "main" lesson.
        guard let l = item.topic.flatMap({ t in list.first { $0.topic == t } }) ?? list.first(where: { $0.topic == "main" })
        else { return nil }
        return lessonsDone.contains(l.id) ? nil : l
    }

    func finishLesson() {
        if let l = activeLesson {
            lessonsDone.insert(l.id)
            UserDefaults.standard.set(Array(lessonsDone), forKey: "lessonsDone")
        }
        activeLesson = nil
    }

    var allLessons: [Lesson] {
        decks.flatMap { lessons[$0.id] ?? [] }
    }

    init(course: Course, store: ProgressStore) {
        self.course = course
        self.store = store
        reload()
    }

    // MARK: Today's plan

    var plan: CourseSchedule { schedule.courses[course] ?? CourseSchedule() }
    var examThisWeek: Assessment? { upcoming.first(where: \.isThisWeek) }
    var meetsToday: Bool { plan.meets.contains(weekdayIndex) }
    var meetsTomorrow: Bool { plan.meets.contains((weekdayIndex + 1) % 7) }

    var newTarget: Int {
        let base = plan.new[weekdayIndex]
        guard examThisWeek != nil else { return base }
        return max(Int((Double(base) * schedule.examMultiplier).rounded()), 8)
    }
    var reviewGoal: Int { min(store.today(course).review + dueCount, schedule.reviewCap) }
    var newLeft: Int { max(newTarget - store.today(course).new, 0) }
    var reviewLeft: Int { max(reviewGoal - store.today(course).review, 0) }
    var doneToday: Bool { newLeft == 0 && reviewLeft == 0 }
    var restDay: Bool { newTarget == 0 && reviewGoal == 0 }
    var minutesLeft: Int { Int((Double(newLeft + reviewLeft) * schedule.secondsPerQuestion / 60).rounded(.up)) }
    var extraToday: String? { plan.extraDays.contains(weekdayIndex) && !plan.extraText.isEmpty ? plan.extraText : nil }

    /// Short reason this class is on today's list.
    var reason: String {
        if let e = examThisWeek { return "\(e.title) \(e.countdown)" }
        if restDay { return "Rest day" }
        if meetsToday { return "Class today" }
        if meetsTomorrow { return "Prep for tomorrow's class" }
        return newTarget > 0 ? "Light review day" : "Reviews only"
    }

    /// Sort key for the Today list: exams this week, then class today, then the rest.
    var priority: Int {
        if let e = examThisWeek { return e.daysAway }
        if meetsToday { return 10 }
        if meetsTomorrow { return 11 }
        return 12
    }

    /// The next assessment for this course, if any.
    var next: Assessment? { upcoming.first }

    /// Decks to drill first: those listed for an assessment 7 days away or closer.
    var priorityDecks: Set<String> {
        Set(upcoming.filter(\.isThisWeek).flatMap(\.decks))
    }

    var pool: [Item] {
        decks.filter { deckFilter == nil || $0.id == deckFilter }.flatMap(\.items)
    }

    var dueCount: Int { decks.flatMap(\.items).filter { store.isDue($0.id) }.count }
    var newCount: Int { decks.flatMap(\.items).filter { store[$0.id].seen == 0 }.count }
    var missedCount: Int { decks.flatMap(\.items).filter { store.isMissed($0.id) }.count }

    func reload() {
        decks = loadDecks(course)
        upcoming = loadUpcoming().filter { $0.course == course }
        schedule = loadSchedule()
        lessons = loadLessons(course)
        restart()
    }

    func nextRound() {
        roundAnswered = 0
        roundRight = 0
        showRoundDone = false
        advance()
    }

    func startBonus() {
        bonus = true
        restart()
    }

    func restart() {
        let items = pool
        switch mode {
        case .smart:
            let hot = priorityDecks
            let stageRank = ["current": 0, "ahead": 1, "past": 2]
            func rank(_ i: Item) -> Int { hot.contains(i.deckFile) ? -1 : (stageRank[i.stage] ?? 0) }
            // Missed/due cards first (exam decks on top), then new cards moving forward:
            // exam decks → current → ahead → past. Already-known cards come last, soonest-due first.
            let due = items.filter { store.isDue($0.id) }.shuffled()
                .sorted { (hot.contains($0.deckFile) ? 0 : 1) < (hot.contains($1.deckFile) ? 0 : 1) }
            // New cards keep the deck's teaching order (lesson topic by topic), never shuffled.
            let deckOrder = Dictionary(uniqueKeysWithValues: decks.enumerated().map { ($1.id, $0) })
            // Within a deck, topic-tagged cards (the ones with lessons) come before untagged vocab.
            func tagged(_ i: Item) -> Int { i.topic == nil ? 1 : 0 }
            let new = items.enumerated().filter { store[$0.element.id].seen == 0 }
                .sorted { (rank($0.element), deckOrder[$0.element.deckFile] ?? 0, tagged($0.element), $0.offset) < (rank($1.element), deckOrder[$1.element.deckFile] ?? 0, tagged($1.element), $1.offset) }
                .map(\.element)
            let rest = items.filter { !store.isDue($0.id) && store[$0.id].seen > 0 }
                .sorted { store[$0.id].due < store[$1.id].due }
            // Today's plan only (capped reviews + today's new cards) unless a bonus round was asked for.
            var todayDue = bonus ? due : Array(due.prefix(reviewLeft))
            var todayNew = bonus ? new : Array(new.prefix(newLeft))
            // Teach first: if a new card opens an unfinished lesson, start with that lesson and its cards, before reviews.
            if let first = todayNew.first(where: { pendingLesson(for: $0) != nil }) {
                let sameTopic = { (i: Item) in i.deckFile == first.deckFile && i.topic == first.topic }
                todayDue = todayNew.filter(sameTopic) + todayDue
                todayNew.removeAll(where: sameTopic)
            }
            queue = todayDue + todayNew + (bonus ? rest : [])
        case .missed:
            queue = items.filter { store[$0.id].misses > 0 }
                .sorted { store[$0.id].box < store[$1.id].box }
        case .all:
            queue = items.shuffled()
        }
        right = 0
        done = 0
        roundAnswered = 0
        roundRight = 0
        showRoundDone = false
        advance()
    }

    func advance() {
        // Short rounds with a real stopping point, then a choice to continue.
        if roundAnswered >= schedule.roundSize && !queue.isEmpty {
            current = nil
            showRoundDone = true
            return
        }
        current = queue.isEmpty ? nil : queue.removeFirst()
        // First time meeting a topic: teach it before asking anything.
        if let c = current, store[c.id].seen == 0, mode != .missed, let l = pendingLesson(for: c) {
            activeLesson = l
        }
        answered = false
        correct = false
        selected = nil
        typed = ""
        revealed = false
        hints = 0
        showSolution = false
        shiftPick = [:]
        accentNote = ""
    }

    func grade(_ ok: Bool) {
        guard let item = current, !answered else { return }
        answered = true
        correct = ok
        done += 1
        roundAnswered += 1
        if ok { right += 1; roundRight += 1 }
        showSolution = !ok   // wrong → walk through the solution right away
        store.bumpToday(course, isNew: store[item.id].seen == 0)
        store.record(item.id, correct: ok)
        if !ok {
            // Bring it back a few cards later in this session.
            queue.insert(item, at: min(4, queue.count))
        }
    }

    func choose(_ i: Int) {
        guard let item = current, item.type == "mc", !answered, i < item.choices.count else { return }
        selected = i
        grade(i == item.answerIndex)
    }

    func checkTyped() {
        guard let item = current, item.type == "fill", !answered else { return }
        let t = norm(typed)
        if item.accepted.contains(where: { norm($0) == t }) {
            grade(true)
        } else if item.accepted.contains(where: { fold(norm($0)) == fold(t) }) {
            accentNote = "Watch the accents: \(item.accepted[0])"
            grade(true)
        } else {
            grade(false)
        }
    }

    func checkShift() {
        guard let item = current, item.type == "shift", !answered else { return }
        grade(["curve", "dir", "price", "gdp"].allSatisfy { shiftPick[$0] == item.shift[$0] })
    }

    private func norm(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: .punctuationCharacters)
    }

    private func fold(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
    }
}

// MARK: - Views

/// Owns the progress store and one session per course, created once at launch.
final class Hub: ObservableObject {
    let store = ProgressStore()
    let sessions: [Course: Session]
    init() {
        var s: [Course: Session] = [:]
        for c in Course.allCases { s[c] = Session(course: c, store: store) }
        sessions = s
    }
}

enum Page: Hashable {
    case today
    case course(Course)
    case practice(Course)
}

struct RootView: View {
    @ObservedObject var hub: Hub
    @State private var selection: Page? = RootView.startPage()

    /// Opens on Today. `open -a "Lock In" --args -startPage practice-decision` (or course-macro, etc.) jumps straight to a page.
    static func startPage() -> Page {
        guard let raw = UserDefaults.standard.string(forKey: "startPage") else { return .today }
        let parts = raw.split(separator: "-").map(String.init)
        guard parts.count == 2, let c = Course(rawValue: parts[1]) else { return .today }
        return parts[0] == "practice" ? .practice(c) : .course(c)
    }

    var body: some View {
        SidebarAndDetail(hub: hub, store: hub.store, selection: $selection)
    }
}

struct SidebarAndDetail: View {
    let hub: Hub
    @ObservedObject var store: ProgressStore   // re-renders progress after every answer
    @Binding var selection: Page?
    @ObservedObject var asker = Asker.shared

    func session(_ c: Course) -> Session { hub.sessions[c]! }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Today", systemImage: "sun.max").tag(Page.today)
                Section("Classes") {
                    ForEach(Course.allCases) { c in
                        let s = session(c)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Label(c.title, systemImage: c.icon)
                                if let n = s.next, n.daysAway <= 14 {
                                    Text("\(n.title) \(n.countdown)")
                                        .font(.caption2)
                                        .foregroundStyle(n.isThisWeek ? .red : .secondary)
                                        .padding(.leading, 26)
                                }
                            }
                            Spacer()
                            if s.restDay {
                                Image(systemName: "moon.zzz").foregroundStyle(.secondary)
                            } else if s.doneToday {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else {
                                Text("\(s.newLeft + s.reviewLeft)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Capsule().fill(c.tint.opacity(0.85)))
                                    .foregroundStyle(.white)
                            }
                        }
                        .tag(Page.course(c))
                    }
                }
                Section("Practice") {
                    ForEach(Course.allCases.filter { $0.practice != nil }) { c in
                        Label("\(c.title): \(c.practice!.title)", systemImage: c.practice!.icon)
                            .tag(Page.practice(c))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            HStack(spacing: 0) {
                detail
                if asker.open {
                    Divider()
                    AskPanel()
                }
            }
            .toolbar {
                Button { withAnimation { asker.open.toggle() } } label: {
                    Label("Ask", systemImage: "bubble.left.and.text.bubble.right")
                }
                .keyboardShortcut("k", modifiers: .command)
                .help("Ask a question about what's on screen (⌘K)")
            }
        }
        .environmentObject(store)
    }

    @ViewBuilder var detail: some View {
            switch selection {
            case .course(let c):
                CourseView(session: session(c), goToday: { selection = .today }, goPractice: { selection = .practice(c) })
                    .id(c)
            case .practice(let c):
                c.practiceView
                    .navigationTitle("\(c.title): \(c.practice?.title ?? "")")
                    .id("practice-\(c.rawValue)")
            default:
                TodayView(hub: hub, store: store, start: { c in
                    session(c).bonus = false
                    session(c).restart()
                    selection = .course(c)
                }, practice: { c in selection = .practice(c) })
                .onAppear { asker.setContext("", "") }
            }
    }
}

// MARK: - Today

struct TodayView: View {
    let hub: Hub
    @ObservedObject var store: ProgressStore
    let start: (Course) -> Void
    let practice: (Course) -> Void
    @StateObject private var checklist = Checklist()

    var ordered: [Session] {
        Course.allCases.map { hub.sessions[$0]! }
            .sorted { ($0.doneToday ? 1 : 0, $0.priority) < ($1.doneToday ? 1 : 0, $1.priority) }
    }

    var body: some View {
        let list = ordered
        let nextUp = list.first { !$0.doneToday && !$0.restDay }
        let totalLeft = list.reduce(0) { $0 + $1.minutesLeft }
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.largeTitle.bold())
                    Text(nextUp == nil ? "All done for today. Go do something fun." : "About \(totalLeft) min left today, in rounds of 10.")
                        .foregroundStyle(.secondary)
                    weekDots
                }

                ChecklistCard(list: checklist, open: start)

                if let s = nextUp {
                    Button { start(s.course) } label: {
                        HStack(spacing: 16) {
                            Image(systemName: s.course.icon).font(.system(size: 30))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Next up: \(s.course.title)").font(.title2.bold())
                                Text("\(s.reason) · \(s.newLeft) new + \(s.reviewLeft) review · ~\(s.minutesLeft) min")
                                    .font(.callout)
                            }
                            Spacer()
                            Text("Start ⏎").font(.headline)
                        }
                        .padding(20)
                        .foregroundStyle(.white)
                        .background(RoundedRectangle(cornerRadius: 14).fill(s.course.tint.gradient))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                }

                VStack(spacing: 10) {
                    ForEach(list, id: \.course) { s in row(s) }
                }

                let extras = list.compactMap { s in s.extraToday.map { (s.course, $0) } }
                if !extras.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Also today").font(.headline)
                        ForEach(extras, id: \.0) { c, text in
                            HStack {
                                Image(systemName: "plus.circle")
                                Text(text)
                                Spacer()
                                if c.practice != nil {
                                    Button("Open") { practice(c) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Today")
        .onAppear { checklist.reload() }
    }

    /// Mon-Sun dots: days studied this week. No streak to break, just a picture of the week.
    var weekDots: some View {
        let studied = store.studiedThisWeek
        let days = [(1, "M"), (2, "T"), (3, "W"), (4, "T"), (5, "F"), (6, "S"), (0, "S")]
        return HStack(spacing: 8) {
            ForEach(days, id: \.0) { wd, letter in
                VStack(spacing: 3) {
                    Circle()
                        .fill(studied.contains(wd) ? Color.green : Color.secondary.opacity(0.25))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(wd == weekdayIndex ? Color.primary : .clear, lineWidth: 1.5))
                    Text(letter).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text("\(studied.count) day\(studied.count == 1 ? "" : "s") this week").font(.caption).foregroundStyle(.secondary)
                .padding(.leading, 6)
        }
        .padding(.top, 4)
    }

    func row(_ s: Session) -> some View {
        let t = store.today(s.course)
        let goal = max(s.newTarget + s.reviewGoal, 1)
        let doneCount = min(t.new, s.newTarget) + min(t.review, s.reviewGoal)
        return Button { start(s.course) } label: {
            HStack(spacing: 14) {
                Image(systemName: s.course.icon).frame(width: 24).foregroundStyle(s.course.tint)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(s.course.title).font(.headline)
                        Text(s.reason).font(.caption).foregroundStyle(s.examThisWeek != nil ? .red : .secondary)
                    }
                    if s.restDay {
                        Text("Nothing due. Enjoy the break.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ProgressView(value: Double(doneCount), total: Double(goal)).tint(s.course.tint)
                    }
                }
                Spacer()
                if s.doneToday && !s.restDay {
                    Label("Done", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else if !s.restDay {
                    Text("\(doneCount)/\(goal)").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CourseView: View {
    @ObservedObject var session: Session
    @EnvironmentObject var store: ProgressStore
    let goToday: () -> Void
    let goPractice: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let n = session.next { banner(n) }
            header
            Divider()
            if let lesson = session.activeLesson {
                LessonView(lesson: lesson, tint: session.course.tint) { session.finishLesson() }
                    .id(lesson.id)
            } else if session.showRoundDone {
                roundDone
            } else if let item = session.current {
                ScrollView {
                    QuestionView(session: session, item: item)
                        .padding(28)
                        .frame(maxWidth: 820)
                        .frame(maxWidth: .infinity)
                }
            } else {
                emptyState
            }
        }
        .navigationTitle(session.course.title)
    }

    func banner(_ n: Assessment) -> some View {
        let names = session.decks.filter { n.decks.contains($0.id) }.map(\.name)
        return HStack(spacing: 10) {
            Image(systemName: n.isThisWeek ? "flame.fill" : "calendar")
            VStack(alignment: .leading, spacing: 2) {
                Text("\(n.title) \(n.countdown) · \(n.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))\(n.estimated ? " (date estimated, confirm in class)" : "")")
                    .font(.callout.bold())
                Text(n.isThisWeek
                     ? "Exam mode: Lock in drills \(names.joined(separator: ", ")) first."
                     : "Covers: \(names.joined(separator: ", ")). These move to the front 7 days before.")
                    .font(.caption)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .foregroundStyle(n.isThisWeek ? Color.white : Color.primary)
        .background(n.isThisWeek ? Color.red.opacity(0.85) : session.course.tint.opacity(0.15))
    }

    var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Picker("Deck", selection: $session.deckFilter) {
                    Text("All decks").tag(String?.none)
                    ForEach(session.decks) { d in
                        let mark = session.priorityDecks.contains(d.id) ? "🔥 " : (d.stage == "ahead" ? "→ " : "")
                        Text("\(mark)\(d.name) (\(d.items.count))").tag(String?.some(d.id))
                    }
                }
                .frame(minWidth: 260, maxWidth: 420)
                Spacer()
                Picker("", selection: $session.mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            HStack(spacing: 12) {
                if session.mode == .smart && !session.bonus {
                    Text(session.doneToday ? "Today: done ✓" : "Today: \(session.newLeft) new + \(session.reviewLeft) review left")
                        .font(.caption.bold()).foregroundStyle(session.doneToday ? .green : .secondary)
                    Text("Round: \(session.roundAnswered)/\(session.schedule.roundSize)")
                        .font(.caption.monospacedDigit()).foregroundStyle(session.course.tint)
                } else {
                    Text(session.bonus ? "Bonus round: no limit" : "\(session.missedCount) missed")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !session.allLessons.isEmpty {
                    Menu {
                        ForEach(session.allLessons) { l in
                            Button("\(session.lessonsDone.contains(l.id) ? "✓ " : "")\(l.title) (~\(l.minutes) min)") {
                                session.activeLesson = l
                            }
                        }
                    } label: { Label("Lessons", systemImage: "book") }
                    .fixedSize()
                }
                if let p = session.course.practice {
                    Button { goPractice() } label: { Label(p.title, systemImage: p.icon) }.fixedSize()
                }
                Button { session.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Reload question files")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    /// Shown after every round of 10: a real stopping point, then an easy choice.
    var roundDone: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(session.course.tint)
            Text("Round done: \(session.roundRight)/\(session.roundAnswered)").font(.title.bold())
            Text("\(session.newLeft) new + \(session.reviewLeft) review left in today's \(session.course.title).")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button { session.nextRound() } label: { Label("Next round (Space)", systemImage: "arrow.right") }
                    .keyboardShortcut(.space, modifiers: [])
                    .controlSize(.large)
                Button { goToday() } label: { Label("Back to Today", systemImage: "sun.max") }
                    .controlSize(.large)
            }
            Text("Stopping here is fine. What's left stays on today's list.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var emptyState: some View {
        let dayDone = session.mode == .smart && !session.bonus
        return VStack(spacing: 12) {
            Image(systemName: dayDone ? "checkmark.circle.fill" : (session.mode == .missed ? "checkmark.seal" : "tray"))
                .font(.system(size: 48)).foregroundStyle(dayDone ? .green : session.course.tint)
            Text(dayDone ? "\(session.course.title) is done for today" : (session.mode == .missed ? "Nothing missed here. Nice." : "No questions in this deck yet."))
                .font(.title2.bold())
            if session.done > 0 {
                Text("This session: \(session.right)/\(session.done) right").foregroundStyle(.secondary)
            }
            HStack {
                if dayDone {
                    Button { goToday() } label: { Label("Back to Today (Space)", systemImage: "sun.max") }
                        .keyboardShortcut(.space, modifiers: [])
                        .controlSize(.large)
                    Button("Bonus round") { session.startBonus() }
                        .controlSize(.large)
                } else {
                    Button("Go again") { session.restart() }.keyboardShortcut(.space, modifiers: [])
                    Button("Show question files") {
                        NSWorkspace.shared.open(banksDir.appendingPathComponent(session.course.rawValue))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func openApp(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}

struct QuestionView: View {
    @ObservedObject var session: Session
    @EnvironmentObject var store: ProgressStore
    let item: Item
    @FocusState private var typing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(item.deck).font(.caption).foregroundStyle(.secondary)
                if store[item.id].misses > 0 {
                    Label("missed \(store[item.id].misses)×", systemImage: "arrow.uturn.backward")
                        .font(.caption).foregroundStyle(.red)
                } else if store[item.id].seen == 0 {
                    Text("new").font(.caption).foregroundStyle(session.course.tint)
                }
                if session.priorityDecks.contains(item.deckFile) {
                    Label("on the exam", systemImage: "flame.fill").font(.caption).foregroundStyle(.red)
                } else if item.stage == "ahead" {
                    Label("ahead of class", systemImage: "forward.fill").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(item.q)
                .font(.system(size: 20, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            switch item.type {
            case "mc": mcBody
            case "fill": fillBody
            case "shift": shiftBody
            default: cardBody
            }

            if session.answered { feedback }
        }
        .onAppear { Asker.shared.setContext("\(session.course.title) card", item.askContext) }
        .onChange(of: item.id) { _ in Asker.shared.setContext("\(session.course.title) card", item.askContext) }
    }

    // Multiple choice: click or press 1-4.
    var mcBody: some View {
        VStack(spacing: 10) {
            ForEach(Array(item.choices.enumerated()), id: \.offset) { i, c in
                Button { session.choose(i) } label: {
                    HStack(alignment: .top) {
                        Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 16)
                        Text(c).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if session.answered && i == item.answerIndex { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        else if session.answered && i == session.selected { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 9).fill(color(i).opacity(session.answered ? 0.16 : 0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(color(i).opacity(0.5)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: [])
                .disabled(session.answered)
            }
        }
    }

    func color(_ i: Int) -> Color {
        guard session.answered else { return .secondary }
        if i == item.answerIndex { return .green }
        if i == session.selected { return .red }
        return .secondary
    }

    // Typed answer: Return to check.
    var fillBody: some View {
        HStack {
            TextField("Type your answer, then Return", text: $session.typed)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 18))
                .focused($typing)
                .onSubmit { session.answered ? session.advance() : session.checkTyped() }
                .disabled(session.answered)
            if !session.answered {
                Button("Check") { session.checkTyped() }
            }
        }
        .onAppear { typing = true }
    }

    // Worked card: think it through, reveal, then grade yourself honestly.
    var cardBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !session.revealed {
                // Work it out first: hints come one step at a time, then the full answer.
                ForEach(Array(item.steps.prefix(session.hints).enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top) {
                        Text("\(i + 1).").foregroundStyle(.secondary)
                        Text(s).fixedSize(horizontal: false, vertical: true)
                    }
                }
                // Brand-new cards walk you through the steps (Space = next step); seen ones quiz you first.
                let walk = store[item.id].seen == 0 && session.hints < item.steps.count
                HStack {
                    if session.hints < item.steps.count {
                        Button { session.hints += 1 } label: {
                            Label(walk ? (session.hints == 0 ? "Walk me through it (Space)" : "Next step (Space)")
                                       : (session.hints == 0 ? "Hint: first step (H)" : "Next step (H)"),
                                  systemImage: walk ? "figure.walk" : "lightbulb")
                        }
                        .keyboardShortcut(walk ? .space : "h", modifiers: [])
                    }
                    Button { session.revealed = true } label: {
                        Label(walk ? "Show answer" : "Reveal answer (Space)", systemImage: "eye")
                    }
                    .keyboardShortcut(walk ? "r" : .space, modifiers: [])
                }
                .controlSize(.large)
            } else {
                ForEach(Array(item.steps.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top) {
                        Text("\(i + 1).").foregroundStyle(.secondary)
                        Text(s).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(item.answerText)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 9).fill(session.course.tint.opacity(0.12)))
                if !session.answered {
                    HStack {
                        Button { session.grade(false) } label: { Label("Missed it (M)", systemImage: "xmark") }
                            .keyboardShortcut("m", modifiers: [])
                        Button { session.grade(true) } label: { Label("Got it (G)", systemImage: "checkmark") }
                            .keyboardShortcut("g", modifiers: [])
                    }
                    .controlSize(.large)
                }
            }
        }
    }

    // AD/AS shift: curve, direction, price level, real GDP.
    var shiftBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            shiftRow("Curve", key: "curve", options: [("AD", "AD"), ("AS", "AS")])
            shiftRow("Shifts", key: "dir", options: [("L", "Left"), ("R", "Right")])
            shiftRow("Price level", key: "price", options: [("U", "Up"), ("D", "Down")])
            shiftRow("Real GDP", key: "gdp", options: [("U", "Up"), ("D", "Down")])
            if !session.answered {
                Button("Check") { session.checkShift() }
                    .controlSize(.large)
                    .disabled(session.shiftPick.count < 4)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
    }

    func shiftRow(_ label: String, key: String, options: [(String, String)]) -> some View {
        HStack {
            Text(label).frame(width: 90, alignment: .leading).foregroundStyle(.secondary)
            ForEach(options, id: \.0) { value, title in
                let picked = session.shiftPick[key] == value
                let isAnswer = item.shift[key] == value
                Button(title) { if !session.answered { session.shiftPick[key] = value } }
                    .buttonStyle(.bordered)
                    .tint(session.answered ? (isAnswer ? .green : (picked ? .red : .gray)) : (picked ? session.course.tint : .gray))
            }
        }
    }

    var feedback: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(session.correct ? "Correct" : "Not quite. This one will come back.",
                  systemImage: session.correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                .foregroundStyle(session.correct ? .green : .red)
                .font(.headline)
            if item.type == "fill" && !session.correct {
                Text("Answer: \(item.accepted.joined(separator: " / "))").font(.body.bold())
            }
            if !session.accentNote.isEmpty { Text(session.accentNote).foregroundStyle(.orange) }
            if !item.why.isEmpty {
                Text(item.why).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if item.type != "card" && !item.steps.isEmpty {
                if session.showSolution {
                    solution
                } else {
                    Button { session.showSolution = true } label: { Label("See the full solution (S)", systemImage: "list.number") }
                        .keyboardShortcut("s", modifiers: [])
                }
            }
            if !item.trap.isEmpty && (session.showSolution || item.steps.isEmpty) { trapNote }
            Button { session.advance() } label: { Label("Next (Space)", systemImage: "arrow.right.circle.fill") }
                .controlSize(.large)
                .keyboardShortcut(.space, modifiers: [])
        }
        .padding(.top, 4)
    }

    /// Worked solution: every step written out, numbered.
    var solution: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How to solve it").font(.subheadline.bold())
            ForEach(Array(item.steps.enumerated()), id: \.offset) { i, s in
                HStack(alignment: .top) {
                    Text("\(i + 1).").foregroundStyle(.secondary).monospacedDigit()
                    Text(s).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(session.course.tint.opacity(0.1)))
    }

    var trapNote: some View {
        Label { Text(item.trap).fixedSize(horizontal: false, vertical: true) } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.1)))
    }
}

// MARK: - Lesson view: idea → worked example (one step at a time) → quick check

struct LessonView: View {
    let lesson: Lesson
    let tint: Color
    let onDone: () -> Void
    @State private var page = 0
    @State private var stepsShown = 0
    @State private var picked: Int? = nil

    var body: some View {
        let p = lesson.pages[min(page, lesson.pages.count - 1)]
        VStack(spacing: 0) {
            HStack {
                Label("Learn: \(lesson.title)", systemImage: "book.fill").font(.headline).foregroundStyle(tint)
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<lesson.pages.count, id: \.self) { i in
                        Capsule().fill(i <= page ? tint : Color.secondary.opacity(0.25)).frame(width: 18, height: 5)
                    }
                }
                Text("\(page + 1)/\(lesson.pages.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Button("Skip lesson") { onDone() }.buttonStyle(.borderless).font(.caption)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !p.title.isEmpty { Text(p.title).font(.title2.bold()) }
                    switch p.kind {
                    case "example": example(p)
                    case "check": check(p)
                    default:
                        Text(p.text).font(.system(size: 17)).lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    }
                    footer(p)
                }
                .padding(32)
                .frame(maxWidth: 780)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { Asker.shared.setContext("Lesson: \(lesson.title)", p.askContext) }
        .onChange(of: page) { _ in Asker.shared.setContext("Lesson: \(lesson.title)", lesson.pages[min(page, lesson.pages.count - 1)].askContext) }
    }

    func example(_ p: LessonPage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(p.q).font(.system(size: 19, weight: .medium)).padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))
                .textSelection(.enabled)
            ForEach(0..<stepsShown, id: \.self) { i in
                let s = p.steps[i]
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(.caption.bold()).foregroundStyle(.white)
                        .frame(width: 22, height: 22).background(Circle().fill(tint))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.doThis).font(.system(size: 16, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                        if !s.why.isEmpty {
                            Text(s.why).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if stepsShown == p.steps.count && !p.answer.isEmpty {
                Label(p.answer, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.green)
            }
        }
    }

    func check(_ p: LessonPage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick check").font(.caption.bold()).foregroundStyle(tint)
            Text(p.q).font(.system(size: 18, weight: .medium)).fixedSize(horizontal: false, vertical: true)
            ForEach(Array(p.choices.enumerated()), id: \.offset) { i, c in
                Button { picked = i } label: {
                    HStack {
                        Text(c).multilineTextAlignment(.leading)
                        Spacer()
                        if picked == i { Image(systemName: i == p.answerIndex ? "checkmark.circle.fill" : "xmark.circle.fill") }
                    }
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 8).fill(
                        picked == i ? (i == p.answerIndex ? Color.green : Color.red).opacity(0.18) : Color.secondary.opacity(0.08)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: [])
            }
            if let k = picked {
                Text(k == p.answerIndex ? "Yes. \(p.why)" : "Not quite, try another one. Hint: \(p.why)")
                    .foregroundStyle(k == p.answerIndex ? .green : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder func footer(_ p: LessonPage) -> some View {
        let last = page == lesson.pages.count - 1
        let stepping = p.kind == "example" && stepsShown < p.steps.count
        let blocked = p.kind == "check" && picked != p.answerIndex
        HStack {
            if page > 0 {
                Button { page -= 1; stepsShown = lesson.pages[page].steps.count; picked = nil } label: { Label("Back", systemImage: "chevron.left") }
            }
            Spacer()
            Button {
                if stepping { stepsShown += 1 }
                else if last { onDone() }
                else { page += 1; stepsShown = 0; picked = nil }
            } label: {
                Label(stepping ? (stepsShown == 0 ? "Show the first step (Space)" : "Next step (Space)")
                      : (last ? "Start practicing (Space)" : "Next (Space)"),
                      systemImage: stepping ? "figure.walk" : (last ? "play.fill" : "chevron.right"))
            }
            .controlSize(.large)
            .keyboardShortcut(.space, modifiers: [])
            .disabled(blocked)
        }
        .padding(.top, 10)
    }
}

// MARK: - Menu bar

struct MenuBarView: View {
    let hub: Hub
    @ObservedObject var store: ProgressStore
    @Environment(\.openWindow) private var openWindow
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        let upcoming = Course.allCases.compactMap { hub.sessions[$0]!.next }.sorted { $0.date < $1.date }
        if let n = upcoming.first {
            Text("Next: \(n.title) \(n.countdown)")
        }
        Divider()
        ForEach(Course.allCases) { c in
            let s = hub.sessions[c]!
            let status = s.restDay ? "rest day" : (s.doneToday ? "✓ done" : "\(s.newLeft + s.reviewLeft) left · ~\(s.minutesLeft) min")
            Button("\(c.title): \(status)") { open() }
        }
        Divider()
        Button("Open Lock In") { open() }.keyboardShortcut("o")
        Toggle("Open at login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { on in
                do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
                catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
            }
        Divider()
        Button("Quit Lock In") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }

    func open() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct LockInApp: App {
    @StateObject private var hub = Hub()

    var body: some Scene {
        WindowGroup("Lock In", id: "main") {
            RootView(hub: hub).frame(minWidth: 900, minHeight: 640)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("Lock In", systemImage: "lock.fill") {
            MenuBarView(hub: hub, store: hub.store)
        }
    }
}
