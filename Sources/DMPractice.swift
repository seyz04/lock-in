// Decision Models worked-problem practice, in the style of the Calc practice:
// randomized numbers, a lesson per family, step-by-step hints, typed numeric answers, full worked solution after.
// Families follow the Midterm 2 cheat sheet, the 10/27 bundling prep, and the flaw-of-averages/simulation lectures.
import SwiftUI

enum DMFamily: String, CaseIterable, Identifiable {
    case weights = "Portfolio weights from holdings"
    case pReturn = "Portfolio expected return"
    case pRisk = "Portfolio risk (2 assets)"
    case bigM = "Big-M: smallest valid M"
    case relax = "Relaxing an integer (fractional project)"
    case surplus = "Consumer surplus choice"
    case bundle = "Pure bundling vs separate pricing"
    case flaw = "Flaw of averages"
    case ev = "Expected value (simulation input)"
    var id: String { rawValue }
}

struct DMProblem {
    let family: DMFamily
    let prompt: String
    let steps: [String]
    let answer: Double
    let answerText: String
    let tolerance: Double   // absolute
    let unit: String
}

let dmLessons: [DMFamily: [String]] = [
    .weights: ["Weights are DOLLAR shares, not share counts.", "Value of each holding = shares × price. Add them up to get M.", "wᵢ = valueᵢ / M. The weights add to 1."],
    .pReturn: ["Expected portfolio return is a weighted average:", "E[r] = w_A·r_A + w_B·r_B (+ …)", "Excel: =SUMPRODUCT(W, Returns)"],
    .pRisk: ["Variance has own terms plus a doubled cross term:", "V = w_A²σ_A² + w_B²σ_B² + 2·w_A·w_B·Cov(A,B)", "Cov(A,B) = ρ·σ_A·σ_B. SD = √V.", "Negative ρ shrinks the cross term, which is why diversification works."],
    .bigM: ["Pattern: flag y = 1 only if expr ≥ 0  →  expr ≥ −M·(1 − y).", "y = 1 forces expr ≥ 0. y = 0 must leave expr unrestricted, so −M has to be at or below the smallest value expr can take.", "Smallest valid M = the largest possible negative gap. Too small cuts off feasible solutions; huge causes numerical trouble."],
    .relax: ["Relaxing an integer restriction can only help a max objective (or leave it the same).", "Leftover cash buys a FRACTION of the project: fraction = leftover / cost.", "New objective = old objective + fraction × project value."],
    .surplus: ["Surplus = valuation − price, for every option.", "The customer buys the option with the LARGEST non-negative surplus.", "If every surplus is negative, they buy nothing (surplus 0). Excel: =MAX(surplus_range, 0)."],
    .bundle: ["Separate pricing: for each product, try each segment's valuation as the price; revenue = price × number of segments willing to pay.", "Pure bundle: price = the LOWEST total valuation across segments, so everyone buys.", "Bundling wins when valuations are negatively correlated."],
    .flaw: ["Plugging in AVERAGE demand gives the profit at the average, not the average profit.", "With a capacity cap, profit = margin × min(demand, capacity), which is concave.", "Expected profit = Σ probability × profit in each scenario."],
    .ev: ["Expected value of a discrete input: E[X] = Σ xᵢ·pᵢ.", "Probabilities must add to 1.", "In a simulation, the AVERAGE of many trials approaches this number."],
]

private func r(_ x: ClosedRange<Int>) -> Int { Int.random(in: x) }
private func f(_ x: Double, _ places: Int = 2) -> String {
    let s = String(format: "%.\(places)f", x)
    return s.contains(".") ? s.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression) : s
}
private func money(_ x: Double) -> String {
    let n = NumberFormatter(); n.numberStyle = .decimal; n.maximumFractionDigits = 2
    return "$" + (n.string(from: NSNumber(value: x)) ?? f(x))
}

func generateDM(_ fam: DMFamily) -> DMProblem {
    switch fam {
    case .weights:
        let n = [r(2...8) * 100, r(1...6) * 100, r(1...5) * 100]
        let p = [Double(r(2000...9000)) / 100, Double(r(2000...9000)) / 100, Double(r(2000...9000)) / 100]
        let v = zip(n, p).map { Double($0) * $1 }
        let m = v.reduce(0, +)
        let w = v[0] / m
        return DMProblem(family: fam,
            prompt: "You own \(n[0]) shares of A at \(money(p[0])), \(n[1]) of B at \(money(p[1])), and \(n[2]) of C at \(money(p[2])). What is A's portfolio weight? (decimal, 4 places)",
            steps: ["Value each holding: A = \(n[0])·\(f(p[0])) = \(money(v[0])), B = \(money(v[1])), C = \(money(v[2])).",
                    "Total M = \(money(m)).",
                    "w_A = \(money(v[0])) / \(money(m)) = \(f(w, 4))."],
            answer: w, answerText: f(w, 4), tolerance: 0.0015, unit: "")
    case .pReturn:
        let wA = Double(r(2...8)) / 10, rA = Double(r(40...160)) / 10, rB = Double(r(30...120)) / 10
        let e = wA * rA + (1 - wA) * rB
        return DMProblem(family: fam,
            prompt: "Fund A: expected return \(f(rA))%. Fund B: \(f(rB))%. You put \(Int(wA * 100))% in A and the rest in B. Expected portfolio return (in %)?",
            steps: ["w_A = \(f(wA)), w_B = 1 − \(f(wA)) = \(f(1 - wA)).",
                    "E[r] = \(f(wA))·\(f(rA)) + \(f(1 - wA))·\(f(rB)).",
                    "= \(f(wA * rA, 3)) + \(f((1 - wA) * rB, 3)) = \(f(e, 3))%."],
            answer: e, answerText: "\(f(e, 2))%", tolerance: 0.02, unit: "%")
    case .pRisk:
        let wA = Double(r(2...8)) / 10, wB = 1 - wA
        let sA = Double(r(10...35)) / 100, sB = Double(r(5...25)) / 100
        let rho = [-0.6, -0.4, -0.3, 0.0, 0.2, 0.5].randomElement()!
        let cov = rho * sA * sB
        let v = wA * wA * sA * sA + wB * wB * sB * sB + 2 * wA * wB * cov
        let sd = sqrt(v) * 100
        return DMProblem(family: fam,
            prompt: "w_A = \(f(wA)), w_B = \(f(wB)). σ_A = \(Int(sA * 100))%, σ_B = \(Int(sB * 100))%, correlation ρ = \(f(rho)). Portfolio standard deviation (in %)?",
            steps: ["Cov(A,B) = ρ·σ_A·σ_B = \(f(rho))·\(f(sA))·\(f(sB)) = \(f(cov, 5)).",
                    "V = \(f(wA))²·\(f(sA))² + \(f(wB))²·\(f(sB))² + 2·\(f(wA))·\(f(wB))·\(f(cov, 5))",
                    "= \(f(wA * wA * sA * sA, 5)) + \(f(wB * wB * sB * sB, 5)) + \(f(2 * wA * wB * cov, 5)) = \(f(v, 5)).",
                    "SD = √\(f(v, 5)) = \(f(sd, 2))%."],
            answer: sd, answerText: "\(f(sd, 2))%", tolerance: 0.1, unit: "%")
    case .bigM:
        let k = r(2...9) * 10, top = k + r(3...12) * 10
        return DMProblem(family: fam,
            prompt: "Flag y = 1 only if x − \(k) ≥ 0, where x can be anywhere from 0 to \(top). Constraint: x − \(k) ≥ −M·(1 − y). Smallest M that still works?",
            steps: ["y = 1 → x − \(k) ≥ 0. That's the rule we want.",
                    "y = 0 → x − \(k) ≥ −M must ALWAYS hold, so −M ≤ the smallest value of x − \(k).",
                    "Smallest x − \(k) is at x = 0: −\(k). So M ≥ \(k)."],
            answer: Double(k), answerText: "M = \(k)", tolerance: 0.01, unit: "")
    case .relax:
        let npv = r(30...60) * 1000, left = r(2...9) * 100, cost = r(2...6) * 1000, val = r(4...12) * 1000
        let add = Double(left) / Double(cost) * Double(val)
        return DMProblem(family: fam,
            prompt: "Best 0/1 plan: NPV \(money(Double(npv))), with \(money(Double(left))) cash unused. Project 7 costs \(money(Double(cost))) and is worth \(money(Double(val))). If only project 7 may be fractional, what's the new max NPV?",
            steps: ["Relaxing an integer can only raise a max objective.",
                    "Fraction of project 7 = \(left) / \(cost) = \(f(Double(left) / Double(cost), 4)).",
                    "Added NPV = \(f(Double(left) / Double(cost), 4)) × \(val) = \(money(add)).",
                    "New NPV = \(money(Double(npv))) + \(money(add)) = \(money(Double(npv) + add))."],
            answer: Double(npv) + add, answerText: money(Double(npv) + add), tolerance: 1, unit: "$")
    case .surplus:
        let ve = r(15...45) * 10, vw = r(15...45) * 10, vb = max(ve, vw) + r(5...25) * 10
        let pe = r(10...40) * 10, pw = r(10...40) * 10, pb = r(25...60) * 10
        let s = [("Excel only", ve - pe), ("Word only", vw - pw), ("Bundle", vb - pb)]
        let best = s.max { $0.1 < $1.1 }!
        let got = max(best.1, 0)
        return DMProblem(family: fam,
            prompt: "A segment values Excel \(money(Double(ve))), Word \(money(Double(vw))), the bundle \(money(Double(vb))). Prices: Excel \(money(Double(pe))), Word \(money(Double(pw))), bundle \(money(Double(pb))). What surplus does this segment end up with?",
            steps: s.map { "\($0.0): surplus = \($0.1)" } +
                   [got > 0 ? "Largest non-negative surplus: \(best.0) (\(best.1)). They buy it." : "Every surplus is negative, so they buy nothing: surplus 0."],
            answer: Double(got), answerText: got > 0 ? "\(money(Double(got))) (buys \(best.0))" : "$0 (buys nothing)", tolerance: 0.01, unit: "$")
    case .bundle:
        let hi1 = r(8...14) * 100, lo1 = r(3...6) * 100, hi2 = r(8...14) * 100, lo2 = r(3...6) * 100
        // Segment 1: product A high, B low. Segment 2: A low, B high.
        func bestSingle(_ a: Int, _ b: Int) -> (Int, Int) {
            let both = min(a, b) * 2, one = max(a, b)
            return both >= one ? (min(a, b), both) : (max(a, b), one)
        }
        let (pA, revA) = bestSingle(hi1, lo2), (pB, revB) = bestSingle(lo1, hi2)
        let bundleP = min(hi1 + lo1, lo2 + hi2), bundleRev = bundleP * 2
        let gain = bundleRev - (revA + revB)
        return DMProblem(family: fam,
            prompt: "Segment 1 values computer \(money(Double(hi1))), monitor \(money(Double(lo1))). Segment 2 values computer \(money(Double(lo2))), monitor \(money(Double(hi2))). One customer per segment. How much MORE revenue does the best pure bundle make than the best separate prices?",
            steps: ["Computer: price \(money(Double(pA))) earns \(money(Double(revA))) (try each segment's valuation as the price).",
                    "Monitor: price \(money(Double(pB))) earns \(money(Double(revB))). Separate total = \(money(Double(revA + revB))).",
                    "Bundle price = lowest total valuation = min(\(hi1 + lo1), \(lo2 + hi2)) = \(money(Double(bundleP))); both buy → \(money(Double(bundleRev))).",
                    "Difference = \(money(Double(bundleRev))) − \(money(Double(revA + revB))) = \(money(Double(gain)))."],
            answer: Double(gain), answerText: money(Double(gain)), tolerance: 0.01, unit: "$")
    case .flaw:
        let cap = r(8...15) * 10, low = cap - r(3...6) * 10, high = cap + r(2...6) * 10, m = r(5...20)
        let avg = (low + high) / 2
        let atAvg = m * min(avg, cap)
        let exp = 0.5 * Double(m * min(low, cap)) + 0.5 * Double(m * min(high, cap))
        return DMProblem(family: fam,
            prompt: "Capacity \(cap) units. Demand is \(low) or \(high), each with probability 0.5. Profit is \(money(Double(m))) per unit sold. What is the EXPECTED profit?",
            steps: ["Profit at average demand (\(avg)): \(m) × min(\(avg), \(cap)) = \(money(Double(atAvg))). That's the flawed plan number.",
                    "Low demand: \(m) × min(\(low), \(cap)) = \(money(Double(m * min(low, cap)))).",
                    "High demand: \(m) × min(\(high), \(cap)) = \(money(Double(m * min(high, cap)))) (capped).",
                    "Expected = 0.5·\(m * min(low, cap)) + 0.5·\(m * min(high, cap)) = \(money(exp)), below the \(money(Double(atAvg))) the average suggests."],
            answer: exp, answerText: money(exp), tolerance: 0.01, unit: "$")
    case .ev:
        let xs = [r(2...5) * 10, r(6...9) * 10, r(10...14) * 10]
        let p1 = Double(r(1...4)) / 10, p2 = Double(r(2...5)) / 10, p3 = (10 - (p1 * 10).rounded() - (p2 * 10).rounded()) / 10
        let e = Double(xs[0]) * p1 + Double(xs[1]) * p2 + Double(xs[2]) * p3
        return DMProblem(family: fam,
            prompt: "Demand is \(xs[0]) with probability \(f(p1)), \(xs[1]) with \(f(p2)), and \(xs[2]) with \(f(p3)). Expected demand?",
            steps: ["Check that the probabilities add to 1: \(f(p1)) + \(f(p2)) + \(f(p3)) = 1.",
                    "E = \(xs[0])·\(f(p1)) + \(xs[1])·\(f(p2)) + \(xs[2])·\(f(p3))",
                    "= \(f(Double(xs[0]) * p1)) + \(f(Double(xs[1]) * p2)) + \(f(Double(xs[2]) * p3)) = \(f(e))."],
            answer: e, answerText: f(e), tolerance: 0.01, unit: "")
    }
}

func parseDMAnswer(_ raw: String) -> Double? {
    let cleaned = raw.replacingOccurrences(of: "[$,%\\s]", with: "", options: .regularExpression)
        .replacingOccurrences(of: "M=", with: "", options: .caseInsensitive)
    return parseAnswer(cleaned)
}

final class DMPracticeEngine: ObservableObject {
    @Published var family: DMFamily? = nil { didSet { showLesson = family.map { !seenLesson.contains($0.rawValue) } ?? false; next() } }
    @Published var problem: DMProblem
    @Published var typed = ""
    @Published var hintsShown = 0
    @Published var answered = false
    @Published var correct = false
    @Published var showLesson = false
    @Published var attempted: [String: Int]
    @Published var missed: [String: Int]
    @Published var streak = 0
    private var seenLesson: Set<String>

    init() {
        attempted = UserDefaults.standard.dictionary(forKey: "dm_attempted") as? [String: Int] ?? [:]
        missed = UserDefaults.standard.dictionary(forKey: "dm_missed") as? [String: Int] ?? [:]
        seenLesson = Set(UserDefaults.standard.stringArray(forKey: "dm_seenLesson") ?? [])
        problem = generateDM(.weights)
        next()
    }

    /// Mixed mode leans toward families you miss more often.
    func pick() -> DMFamily {
        if let f = family { return f }
        let bag = DMFamily.allCases.flatMap { fam -> [DMFamily] in
            let weight = 2 + 3 * (missed[fam.rawValue] ?? 0) - (attempted[fam.rawValue] ?? 0) / 4
            return Array(repeating: fam, count: max(weight, 1))
        }
        return bag.randomElement() ?? .weights
    }

    func next() {
        problem = generateDM(pick())
        typed = ""
        hintsShown = 0
        answered = false
        correct = false
    }

    func hint() { if hintsShown < problem.steps.count { hintsShown += 1 } }

    func check() {
        guard !answered, let v = parseDMAnswer(typed) else { return }
        answered = true
        let tol = max(problem.tolerance, abs(problem.answer) * 0.005)
        correct = abs(v - problem.answer) <= tol
        let k = problem.family.rawValue
        attempted[k, default: 0] += 1
        if correct { streak += 1 } else { missed[k, default: 0] += 1; streak = 0 }
        UserDefaults.standard.set(attempted, forKey: "dm_attempted")
        UserDefaults.standard.set(missed, forKey: "dm_missed")
    }

    func giveUp() {
        guard !answered else { return }
        answered = true
        correct = false
        missed[problem.family.rawValue, default: 0] += 1
        attempted[problem.family.rawValue, default: 0] += 1
        streak = 0
        UserDefaults.standard.set(attempted, forKey: "dm_attempted")
        UserDefaults.standard.set(missed, forKey: "dm_missed")
    }

    func dismissLesson() {
        showLesson = false
        if let f = family { seenLesson.insert(f.rawValue) }
        UserDefaults.standard.set(Array(seenLesson), forKey: "dm_seenLesson")
    }
}

struct DMPracticeView: View {
    @StateObject private var e = DMPracticeEngine()
    @FocusState private var typing: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Problem type", selection: $e.family) {
                    Text("Mixed (leans on what you miss)").tag(DMFamily?.none)
                    ForEach(DMFamily.allCases) { Text($0.rawValue).tag(DMFamily?.some($0)) }
                }
                .frame(maxWidth: 420)
                Spacer()
                if e.streak >= 2 { Label("\(e.streak) in a row", systemImage: "flame.fill").foregroundStyle(.orange) }
                Button { e.showLesson = true } label: { Label("Lesson (L)", systemImage: "book") }
                    .keyboardShortcut("l", modifiers: [.command])
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if e.showLesson { lesson }
                    Text(e.problem.family.rawValue).font(.caption).foregroundStyle(.secondary)
                    Text(e.problem.prompt)
                        .font(.system(size: 19, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)

                    HStack {
                        TextField("Your answer (numbers, $ and % are fine), then Return", text: $e.typed)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 17, design: .monospaced))
                            .focused($typing)
                            .onSubmit { e.answered ? e.next() : e.check() }
                            .disabled(e.answered)
                        if !e.answered {
                            Button("Check") { e.check() }
                        }
                    }

                    if !e.answered {
                        HStack {
                            Button { e.hint() } label: {
                                Label(e.hintsShown == 0 ? "Hint: first step (⌘H)" : "Next step (⌘H)", systemImage: "lightbulb")
                            }
                            .keyboardShortcut("h", modifiers: [.command])
                            .disabled(e.hintsShown >= e.problem.steps.count)
                            Button("Show solution") { e.giveUp() }
                        }
                    }

                    let shown = e.answered ? e.problem.steps.count : e.hintsShown
                    if shown > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(0..<shown, id: \.self) { i in
                                HStack(alignment: .top) {
                                    Text("\(i + 1).").foregroundStyle(.secondary).monospacedDigit()
                                    Text(e.problem.steps[i]).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.08)))
                    }

                    if e.answered {
                        Label(e.correct ? "Correct: \(e.problem.answerText)" : "Answer: \(e.problem.answerText)",
                              systemImage: e.correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                            .font(.headline)
                            .foregroundStyle(e.correct ? .green : .red)
                        Button { e.next() } label: { Label("New problem (Return)", systemImage: "arrow.right.circle.fill") }
                            .controlSize(.large)
                    }
                }
                .padding(28)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { typing = true }
    }

    var lesson: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lesson: \(e.problem.family.rawValue)").font(.headline)
            ForEach(dmLessons[e.problem.family] ?? [], id: \.self) { Text("• " + $0).fixedSize(horizontal: false, vertical: true) }
            Button("Got it") { e.dismissLesson() }.padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.1)))
    }
}
