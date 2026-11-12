import SwiftUI
import AppKit

// Ask: a tutor panel on the right of every page (⌘K), so a quick "wait, why?" doesn't mean
// switching apps. It runs the local `claude` CLI headless (Sey's own Claude login, no API key)
// and sends whatever is on screen (card, lesson page, calc problem) as context.

final class Asker: ObservableObject {
    static let shared = Asker()

    struct Message: Identifiable {
        let id = UUID()
        let fromMe: Bool
        let text: String
    }

    @Published var open = false
    @Published var messages: [Message] = []
    @Published var busy = false
    /// What's on screen right now; pages update this as they change.
    @Published var context = ""
    @Published var contextTitle = ""

    private var process: Process?

    static let tutor = """
    You are a patient math and study tutor inside Sey's study app. Sey is a college student (Econ + Philosophy) \
    taking MFE (calculus for economics), Macro, Decision Models and French. Sey skipped a lot of high-school math, \
    so fractions, exponents, roots and logs can be shaky: never assume those steps are obvious, show them. \
    Sey has inattentive ADHD: keep answers short and concrete. Lead with the one-line answer, then numbered steps \
    (each step one small move, with a few words on why), then one tiny check-yourself question if useful. \
    Write math in plain text with Unicode (x², √x, ½, eˣ, ln x, →), never LaTeX. Use **bold** sparingly. \
    If the question is about the material on screen, use that context. Don't lecture beyond what was asked.
    """

    func setContext(_ title: String, _ text: String) {
        contextTitle = title
        context = text
    }

    func newChat() {
        process?.terminate()
        messages = []
        busy = false
    }

    static func claudePath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func ask(_ question: String) {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !busy else { return }
        messages.append(Message(fromMe: true, text: q))
        guard let exe = Asker.claudePath() else {
            messages.append(Message(fromMe: false, text: "Couldn't find the `claude` command. Install Claude Code, then try again."))
            return
        }

        // One-shot CLI, so the whole conversation goes in each prompt.
        var prompt = ""
        if !context.isEmpty { prompt += "ON SCREEN (\(contextTitle)):\n\(context)\n\n" }
        if messages.count > 1 {
            prompt += "CONVERSATION SO FAR:\n"
            for m in messages.dropLast() { prompt += (m.fromMe ? "Sey: " : "Tutor: ") + m.text + "\n" }
            prompt += "\n"
        }
        prompt += "Sey asks: \(q)"

        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = ["-p", "--model", "sonnet", "--tools", "", "--no-session-persistence", "--system-prompt", Asker.tutor]
        p.currentDirectoryURL = FileManager.default.temporaryDirectory
        let input = Pipe(), output = Pipe()
        p.standardInput = input
        p.standardOutput = output
        p.standardError = Pipe()
        p.terminationHandler = { [weak self] proc in
            let data = output.fileHandleForReading.readDataToEndOfFile()
            var text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty || proc.terminationStatus != 0 {
                text = text.isEmpty ? "No answer came back. If Claude Code says you're logged out, run `claude auth login` in Terminal." : text
            }
            DispatchQueue.main.async {
                guard let self, self.process === proc else { return }
                self.messages.append(Message(fromMe: false, text: text))
                self.busy = false
                self.process = nil
            }
        }
        do {
            try p.run()
            process = p
            busy = true
            input.fileHandleForWriting.write(prompt.data(using: .utf8)!)
            try? input.fileHandleForWriting.close()
        } catch {
            messages.append(Message(fromMe: false, text: "Couldn't start Claude: \(error.localizedDescription)"))
        }
    }
}

/// Inline markdown (bold, italics, code) per paragraph, keeping line breaks.
func markdownText(_ s: String) -> Text {
    let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    if let a = try? AttributedString(markdown: s, options: opts) { return Text(a) }
    return Text(s)
}

struct AskPanel: View {
    @ObservedObject var asker = Asker.shared
    @State private var draft = ""
    @FocusState private var focused: Bool

    let quick = ["Explain this step by step", "Why does this step work?", "Give me an easier example first", "What's the trap here?"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Ask", systemImage: "bubble.left.and.text.bubble.right.fill").font(.headline)
                Spacer()
                Button { asker.newChat() } label: { Image(systemName: "square.and.pencil") }
                    .buttonStyle(.borderless).help("New chat")
                Button { asker.open = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).help("Close (⌘K)")
            }
            .padding(12)
            if !asker.contextTitle.isEmpty {
                Text("Sees: \(asker.contextTitle)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.bottom, 8)
            }
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if asker.messages.isEmpty {
                            Text("Stuck? Ask about what's on screen, or anything (fractions, logs, a French rule…).")
                                .font(.callout).foregroundStyle(.secondary)
                            ForEach(quick, id: \.self) { q in
                                Button(q) { asker.ask(q) }.buttonStyle(.bordered).disabled(asker.busy)
                            }
                        }
                        ForEach(asker.messages) { m in
                            markdownText(m.text)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(m.fromMe ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)))
                                .id(m.id)
                        }
                        if asker.busy {
                            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Thinking…").foregroundStyle(.secondary) }
                                .id("busy")
                        }
                    }
                    .padding(12)
                }
                .onChange(of: asker.messages.count) { _ in
                    withAnimation { proxy.scrollTo(asker.messages.last?.id, anchor: .top) }
                }
            }
            Divider()
            HStack {
                TextField("Ask a question, then Return", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($focused)
                    .onSubmit(send)
                Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                    .buttonStyle(.borderless)
                    .disabled(asker.busy || draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
        }
        .frame(width: 340)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { focused = true }
    }

    func send() {
        let q = draft
        draft = ""
        asker.ask(q)
    }
}

// MARK: - Context helpers

extension Item {
    var askContext: String {
        var s = "Deck: \(deck)\nQuestion: \(q)"
        if !choices.isEmpty { s += "\nChoices: " + choices.enumerated().map { "\($0.offset + 1)) \($0.element)" }.joined(separator: "  ") }
        let ans = type == "mc" && choices.indices.contains(answerIndex) ? choices[answerIndex] : (type == "fill" ? accepted.first ?? "" : answerText)
        if !ans.isEmpty { s += "\nCorrect answer: \(ans)" }
        if !steps.isEmpty { s += "\nWorked steps: " + steps.joined(separator: " | ") }
        if !why.isEmpty { s += "\nWhy: \(why)" }
        if !trap.isEmpty { s += "\nTrap: \(trap)" }
        return s
    }
}

extension LessonPage {
    var askContext: String {
        var s = "Lesson page (\(kind)): \(title)"
        if !text.isEmpty { s += "\n\(text)" }
        if !q.isEmpty { s += "\nQuestion: \(q)" }
        if !steps.isEmpty { s += "\nSteps: " + steps.map { "\($0.doThis) (\($0.why))" }.joined(separator: " | ") }
        if !answer.isEmpty { s += "\nAnswer: \(answer)" }
        if !choices.isEmpty { s += "\nChoices: " + choices.joined(separator: " / ") + (choices.indices.contains(answerIndex) ? "\nCorrect: \(choices[answerIndex])" : "") }
        return s
    }
}

extension CalcProblem {
    var askContext: String {
        "Calc problem (\(topic.rawValue)): \(prompt)\nWorked steps: " + steps.joined(separator: " | ") + "\nAnswer: \(answer)"
    }
}
