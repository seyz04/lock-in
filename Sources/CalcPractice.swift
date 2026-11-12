// Calc practice, ported from the standalone Calc for MFE app (Nov 2026). Shown as Lock In → Practice → Calc.
// Randomized derivative problems with lesson cards, worked examples and typed answers.
import SwiftUI
import AppKit

// MARK: - Superscript formatting

func sup(_ n: Int) -> String {
    let map: [Character: Character] = ["0":"⁰","1":"¹","2":"²","3":"³","4":"⁴","5":"⁵","6":"⁶","7":"⁷","8":"⁸","9":"⁹","-":"⁻"]
    return String(n).compactMap { map[$0] }.reduce("") { $0 + String($1) }
}

func xPow(_ n: Int) -> String {
    if n == 0 { return "1" }
    if n == 1 { return "x" }
    return "x" + sup(n)
}

func term(_ coef: Int, _ power: Int) -> String {
    let x = xPow(power)
    if power == 0 { return "\(coef)" }
    if coef == 1 { return x }
    if coef == -1 { return "-\(x)" }
    return "\(coef)\(x)"
}

func plus(_ a: String, _ b: String) -> String {
    b.hasPrefix("-") ? "\(a) \(b.prefix(1))\(b.dropFirst(1).trimmingCharacters(in: .whitespaces))" : "\(a) + \(b)"
}

// MARK: - Polynomial arithmetic (for fully expanding/combining product & quotient results)

struct Poly {
    var coeffs: [Int: Int] = [:]

    static func monomial(_ coef: Int, _ exp: Int) -> Poly {
        coef == 0 ? Poly() : Poly(coeffs: [exp: coef])
    }
    static func constant(_ c: Int) -> Poly { monomial(c, 0) }

    static func + (lhs: Poly, rhs: Poly) -> Poly {
        var r = lhs.coeffs
        for (e, c) in rhs.coeffs { r[e, default: 0] += c }
        return Poly(coeffs: r.filter { $0.value != 0 })
    }
    static func - (lhs: Poly, rhs: Poly) -> Poly {
        lhs + Poly(coeffs: rhs.coeffs.mapValues { -$0 })
    }
    static func * (lhs: Poly, rhs: Poly) -> Poly {
        var r: [Int: Int] = [:]
        for (e1, c1) in lhs.coeffs {
            for (e2, c2) in rhs.coeffs {
                r[e1 + e2, default: 0] += c1 * c2
            }
        }
        return Poly(coeffs: r.filter { $0.value != 0 })
    }

    // Fully simplified, combined-like-terms string, descending by exponent.
    func toString() -> String {
        if coeffs.isEmpty { return "0" }
        let sorted = coeffs.sorted { $0.key > $1.key }
        var result = term(sorted[0].value, sorted[0].key)
        for (exp, coef) in sorted.dropFirst() {
            result = plus(result, term(coef, exp))
        }
        return result
    }
}

// Lists every term of each poly in order WITHOUT combining like terms (to show the "before combining" line).
func rawJoin(_ polys: [Poly]) -> String {
    var parts: [String] = []
    for p in polys {
        for (e, c) in p.coeffs.sorted(by: { $0.key > $1.key }) { parts.append(term(c, e)) }
    }
    guard var r = parts.first else { return "0" }
    for t in parts.dropFirst() { r = plus(r, t) }
    return r
}

func gcd(_ a: Int, _ b: Int) -> Int {
    var x = abs(a), y = abs(b)
    while y != 0 { (x, y) = (y, x % y) }
    return x
}

// Superscript power, but blank for 1 (so we show (3x + 1) instead of (3x + 1)¹).
func pw(_ n: Int) -> String { n == 1 ? "" : sup(n) }

// MARK: - CalcProblem model

enum CalcTopic: String, CaseIterable, Identifiable {
    case basics = "Basic Derivatives"
    case polynomial = "Polynomial"
    case product = "Product Rule"
    case productSpecial = "Product (eˣ, ln, √)"
    case quotient = "Quotient Rule"
    case quotientSpecial = "Quotient (eˣ, ln, √)"
    case chain = "Chain Rule"
    case logexp = "Log / Exponential"
    case productChain = "Product + Chain Rule"
    case quotientChain = "Quotient + Chain Rule"
    case inverseDeriv = "R6: Inverse Function Derivative"
    case inverseDemand = "R6: Inverse Demand & Marginal Revenue"
    case implicitDiff = "R6: Implicit Differentiation"
    case logDiff = "R6: Log Differentiation"
    case expLog = "Q7: Exp & Log Derivatives (aˣ, log_b, chains)"

    var id: String { rawValue }
}

struct CalcProblem {
    let topic: CalcTopic
    let prompt: String
    let steps: [String]
    let answer: String
    var numeric: Double? = nil   // if set, you can type an answer and the app checks it
    var ask: String? = nil       // label next to the answer box, e.g. "(f⁻¹)'(5) ="
}

func rint(_ range: ClosedRange<Int>) -> Int { Int.random(in: range) }
func nonzero(_ range: ClosedRange<Int>) -> Int {
    var v = 0
    while v == 0 { v = rint(range) }
    return v
}

func generatePolynomial() -> CalcProblem {
    let a = nonzero(-6...6), n = rint(2...5)
    let b = nonzero(-6...6), m = rint(1...4)
    let prompt = "f(x) = \(plus(term(a, n), term(b, m)))"
    let d1 = a * n, d2 = b * m
    let steps = [
        "Differentiate term by term using the power rule: d/dx[axⁿ] = a·n·xⁿ⁻¹",
        "d/dx[\(term(a, n))] = \(a)·\(n)·\(xPow(n - 1)) = \(term(d1, n - 1))",
        "d/dx[\(term(b, m))] = \(b)·\(m)·\(xPow(m - 1)) = \(term(d2, m - 1))",
        "Add the results together.",
    ]
    let answer = "f'(x) = \(plus(term(d1, n - 1), term(d2, m - 1)))"
    return CalcProblem(topic: .polynomial, prompt: prompt, steps: steps, answer: answer)
}

func generateProduct() -> CalcProblem {
    let a = nonzero(-5...5), n = rint(1...3), c = nonzero(-5...5)
    let b = nonzero(-5...5), m = rint(1...3), d = nonzero(-5...5)
    let u = plus(term(a, n), "\(c)")
    let v = plus(term(b, m), "\(d)")
    let prompt = "f(x) = (\(u))(\(v))"
    let uprime = term(a * n, n - 1)
    let vprime = term(b * m, m - 1)

    let uPoly = Poly.monomial(a, n) + Poly.constant(c)
    let vPoly = Poly.monomial(b, m) + Poly.constant(d)
    let uPrimePoly = Poly.monomial(a * n, n - 1)
    let vPrimePoly = Poly.monomial(b * m, m - 1)
    let p1 = uPrimePoly * vPoly
    let p2 = uPoly * vPrimePoly
    let result = p1 + p2

    let steps = [
        "Spot the rule: two things MULTIPLIED together → product rule. Call the first factor u and the second v.",
        "u = \(u),  v = \(v)",
        "Power rule on each (constants vanish): u' = \(uprime),  v' = \(vprime)",
        "Product rule (\"first' × second + first × second'\"): f'(x) = u'v + uv'",
        "Plug in: f'(x) = (\(uprime))(\(v)) + (\(u))(\(vprime))",
        "First product, distribute every term: (\(uprime))(\(v)) = \(p1.toString())",
        "Second product: (\(u))(\(vprime)) = \(p2.toString())",
        "Add them (it's a plus, so no sign flips): \(rawJoin([p1, p2]))",
        "Combine like terms (same power of x → add coefficients): \(result.toString())",
    ]
    let answer = "f'(x) = \(result.toString())"
    return CalcProblem(topic: .product, prompt: prompt, steps: steps, answer: answer)
}

func generateQuotient() -> CalcProblem {
    let a = nonzero(-5...5), n = rint(1...3), c = nonzero(-5...5)
    let b = nonzero(-5...5), m = rint(1...3), d = nonzero(-5...5)
    let u = plus(term(a, n), "\(c)")
    let v = plus(term(b, m), "\(d)")
    let prompt = "f(x) = (\(u)) / (\(v))"
    let uprime = term(a * n, n - 1)
    let vprime = term(b * m, m - 1)

    let uPoly = Poly.monomial(a, n) + Poly.constant(c)
    let vPoly = Poly.monomial(b, m) + Poly.constant(d)
    let uPrimePoly = Poly.monomial(a * n, n - 1)
    let vPrimePoly = Poly.monomial(b * m, m - 1)
    let q1 = uPrimePoly * vPoly
    let q2 = uPoly * vPrimePoly
    let negQ2 = Poly() - q2
    let numerator = q1 - q2

    let steps = [
        "Spot the rule: one thing DIVIDED by another → quotient rule. Top = u, bottom = v.",
        "u = \(u),  v = \(v)",
        "Power rule on each (constants vanish): u' = \(uprime),  v' = \(vprime)",
        "Quotient rule (\"low d-high minus high d-low, over low squared\"): f'(x) = (u'v − uv') / v²",
        "Plug in: f'(x) = [(\(uprime))(\(v)) − (\(u))(\(vprime))] / (\(v))²",
        "First product (u'v), distribute every term: \(q1.toString())",
        "Second product (uv'): \(q2.toString())",
        "Subtract — wrap the 2nd product in parentheses so the minus hits EVERY term: (\(q1.toString())) − (\(q2.toString()))",
        "Distribute the minus (flip each sign in the 2nd group): \(rawJoin([q1, negQ2]))",
        "Combine like terms (same power of x → add coefficients): \(numerator.toString())",
        "Leave the bottom as (\(v))² — expanding it is extra work and NOT required.",
    ]
    let answer = "f'(x) = (\(numerator.toString())) / (\(v))²"
    return CalcProblem(topic: .quotient, prompt: prompt, steps: steps, answer: answer)
}

func generateProductChain() -> CalcProblem {
    // f(x) = u·w, where u = a·x^n and w = (b·x + e)^p (w needs the chain rule).
    let a = nonzero(-4...4), n = rint(1...2)
    let b = nonzero(-3...3), e = nonzero(-5...5), p = rint(2...3)
    let uStr = term(a, n)
    let innerStr = plus(term(b, 1), "\(e)")
    let wStr = "(\(innerStr))\(sup(p))"
    let prompt = "f(x) = \(uStr)\(wStr)"

    let uPrimeStr = term(a * n, n - 1)
    let wPrimeStr = "\(p)(\(innerStr))\(pw(p - 1)) · \(b)"

    let steps = [
        "This is a product u·w where u = \(uStr) and w = \(wStr) — w needs the chain rule.",
        "u' = \(uPrimeStr) (power rule)",
        "w' = \(wPrimeStr) (chain rule: outer power rule × inner derivative)",
        "Product rule: f'(x) = u'w + uw'",
        "f'(x) = (\(uPrimeStr))(\(wStr)) + (\(uStr))(\(wPrimeStr))",
        "Both terms share (\(innerStr))\(pw(p - 1))\(n > 1 ? " and \(xPow(n - 1))" : ""). Pull that common piece out front.",
        "What's left in the bracket: \(a * n)(\(innerStr)) + \(term(a * p * b, 1))",
        "Expand the bracket: \(plus(plus(term(a * n * b, 1), term(a * n * e, 0)), term(a * p * b, 1)))",
        "Combine the x terms (\(a * n * b) + \(a * p * b) = \(a * b * (n + p))):",
    ]

    let bracketCoefX = a * b * (n + p)
    let bracketConst = a * n * e
    let fullBracket = plus(term(bracketCoefX, 1), term(bracketConst, 0))
    let g = gcd(bracketCoefX, bracketConst)
    let bracket = plus(term(bracketCoefX / g, 1), term(bracketConst / g, 0))
    let common = "\(n > 1 ? xPow(n - 1) : "")(\(innerStr))\(pw(p - 1))"
    var steps2 = steps
    steps2.append("So far: f'(x) = \(common)(\(fullBracket))")
    if g > 1 {
        steps2.append("Last simplification: \(term(bracketCoefX, 1)) and \(bracketConst) are both divisible by \(g). Pull the \(g) out front: (\(fullBracket)) = \(g)(\(bracket))")
    } else {
        steps2.append("Check for a common number in the bracket: none, so you're done.")
    }

    var factorParts: [String] = []
    let front = term(g, n - 1)
    if front != "1" { factorParts.append(front) }
    factorParts.append("(\(innerStr))\(pw(p - 1))")
    factorParts.append("(\(bracket))")
    let answer = "f'(x) = " + factorParts.joined(separator: "")

    return CalcProblem(topic: .productChain, prompt: prompt, steps: steps2, answer: answer)
}

func generateQuotientChain() -> CalcProblem {
    // f(x) = u / v, where u = a·x + c and v = (b·x + e)^p (v needs the chain rule).
    let a = nonzero(-4...4), c = nonzero(-5...5)
    let b = nonzero(-3...3), e = nonzero(-5...5), p = rint(2...3)
    let uStr = plus(term(a, 1), "\(c)")
    let innerStr = plus(term(b, 1), "\(e)")
    let vStr = "(\(innerStr))\(sup(p))"
    let prompt = "f(x) = (\(uStr)) / \(vStr)"

    let uPrimeStr = "\(a)"
    let vPrimeStr = "\(p)(\(innerStr))\(pw(p - 1)) · \(b)"

    let steps = [
        "This is a quotient u/v where u = \(uStr) and v = \(vStr) — v needs the chain rule.",
        "u' = \(uPrimeStr)",
        "v' = \(vPrimeStr) (chain rule: outer power rule × inner derivative)",
        "Quotient rule: f'(x) = (u'v − uv') / v²",
        "f'(x) = [(\(uPrimeStr))(\(vStr)) − (\(uStr))(\(vPrimeStr))] / (\(innerStr))\(sup(2 * p))",
        "Both numerator terms share (\(innerStr))\(pw(p - 1)). Factor it out → bracket left: \(a)(\(innerStr)) − \(p * b)(\(uStr))",
        "Expand the bracket (careful: the minus hits both terms of the 2nd group): \(plus(plus(plus(term(a * b, 1), term(a * e, 0)), term(-p * b * a, 1)), term(-p * b * c, 0)))",
        "Combine like terms: \(plus(term(a * b * (1 - p), 1), term(a * e - p * b * c, 0)))",
        "Cancel powers: (\(innerStr))\(sup(2 * p)) on the bottom ÷ (\(innerStr))\(pw(p - 1)) pulled from the top = (\(innerStr))\(sup(p + 1))",
    ]

    let bracketCoefX = a * b * (1 - p)
    let bracketConst = a * e - p * b * c
    let fullBracket = plus(term(bracketCoefX, 1), term(bracketConst, 0))
    let g = bracketConst == 0 ? abs(bracketCoefX) : gcd(bracketCoefX, bracketConst)
    let bracket = bracketConst == 0 ? term(bracketCoefX / g, 1) : plus(term(bracketCoefX / g, 1), term(bracketConst / g, 0))
    let finalPower = p + 1
    var steps2 = steps
    steps2.append("So far: f'(x) = (\(fullBracket)) / (\(innerStr))\(sup(finalPower))")
    if g > 1 {
        steps2.append("Last simplification: both numbers on top are divisible by \(g). Pull it out: \(g)(\(bracket))")
    } else {
        steps2.append("Check for a common number on top: none, so you're done.")
    }
    let top = g > 1 ? "\(g)(\(bracket))" : "(\(bracket))"
    let answer = "f'(x) = \(top) / (\(innerStr))\(sup(finalPower))"

    return CalcProblem(topic: .quotientChain, prompt: prompt, steps: steps2, answer: answer)
}


// Linear "x + a" string; a == 0 gives just "x".
func lin(_ a: Int) -> String { a == 0 ? "x" : plus("x", "\(a)") }

func generateQuotientSpecial() -> CalcProblem {
    let a = rint(1...5), k = rint(2...5), n = rint(1...3)
    let intro = "Spot the rule: one thing DIVIDED by another → quotient rule. Fill the four boxes FIRST, simplify LAST."
    let rule = "Quotient rule (low d-high minus high d-low, over low squared): f'(x) = (top'·bottom − top·bottom') / bottom²"
    switch rint(1...6) {
    case 1:
        let g = lin(a)
        let top = a == 1 ? "xeˣ" : "eˣ(\(lin(a - 1)))"
        return CalcProblem(topic: .quotientSpecial, prompt: "f(x) = eˣ / (\(g))", steps: [
            intro,
            "Boxes: top = eˣ, top' = eˣ (eˣ is its own derivative).  bottom = \(g), bottom' = 1",
            rule,
            "Plug in: [eˣ(\(g)) − eˣ(1)] / (\(g))²",
            "Both pieces on top contain eˣ. Pull it out: eˣ[(\(g)) − 1]",
            "Simplify the bracket: \(g) − 1 = \(lin(a - 1))",
            "Leave the bottom squared as is.",
        ], answer: "f'(x) = \(top) / (\(g))²")
    case 2:
        let coef = n == 1 ? "" : "\(n)"
        return CalcProblem(topic: .quotientSpecial, prompt: "f(x) = ln x / \(xPow(n))", steps: [
            intro,
            "Boxes: top = ln x, top' = 1/x (memorize: derivative of ln x is 1/x).  bottom = \(xPow(n)), bottom' = \(term(n, n - 1))",
            rule,
            "Plug in: [(1/x)(\(xPow(n))) − (ln x)(\(term(n, n - 1)))] / (\(xPow(n)))²",
            "Clean the first piece: (1/x)·\(xPow(n)) = \(xPow(n - 1)) (dividing by x lowers the power by 1)",
            "Top is now: \(xPow(n - 1)) − \(term(n, n - 1))·ln x" + (n > 1 ? ". Pull out \(xPow(n - 1)): \(xPow(n - 1))(1 − \(coef)ln x)" : " = 1 − ln x"),
            "Bottom: (\(xPow(n)))² = \(xPow(2 * n))" + (n > 1 ? ". Cancel \(xPow(n - 1)) from top and bottom → \(xPow(n + 1))" : ""),
        ], answer: "f'(x) = (1 − \(coef)ln x) / \(xPow(n + 1))")
    case 3:
        return CalcProblem(topic: .quotientSpecial, prompt: "f(x) = \(term(k, 1)) / ln x", steps: [
            intro,
            "Boxes: top = \(term(k, 1)), top' = \(k).  bottom = ln x, bottom' = 1/x",
            rule,
            "Plug in: [\(k)·ln x − \(term(k, 1))·(1/x)] / (ln x)²",
            "Clean the second piece: \(term(k, 1))·(1/x) = \(k) (the x's cancel)",
            "Top is now: \(k)ln x − \(k). Pull out the \(k): \(k)(ln x − 1)",
            "Treat ln x like a block, the same way you treated (x + 2). Leave (ln x)² alone.",
        ], answer: "f'(x) = \(k)(ln x − 1) / (ln x)²")
    case 4:
        let g = lin(a)
        return CalcProblem(topic: .quotientSpecial, prompt: "f(x) = √x / (\(g))", steps: [
            intro,
            "Rewrite √x as x^(1/2). Power rule: bring down 1/2, subtract 1 → (1/2)x^(−1/2) = 1/(2√x)",
            "Boxes: top = √x, top' = 1/(2√x).  bottom = \(g), bottom' = 1",
            rule,
            "Plug in: [(1/(2√x))(\(g)) − √x·1] / (\(g))²",
            "There's a fraction inside the fraction. Fix: multiply top AND bottom by 2√x.",
            "Top × 2√x: (\(g)) − 2√x·√x = (\(g)) − 2x = \(a) − x   (because √x·√x = x)",
            "Bottom × 2√x: 2√x(\(g))²",
        ], answer: "f'(x) = (\(a) − x) / [2√x(\(g))²]")
    case 5:
        return CalcProblem(topic: .quotientSpecial, prompt: "f(x) = e^(\(k)x) / x", steps: [
            intro,
            "top = e^(\(k)x). Its derivative needs the chain rule: e^(stuff) → e^(stuff) × stuff'. Inside = \(k)x, inside' = \(k)",
            "Boxes: top = e^(\(k)x), top' = \(k)e^(\(k)x).  bottom = x, bottom' = 1",
            rule,
            "Plug in: [\(k)e^(\(k)x)·x − e^(\(k)x)·1] / x²",
            "Both pieces on top contain e^(\(k)x). Pull it out: e^(\(k)x)(\(k)x − 1)",
        ], answer: "f'(x) = e^(\(k)x)(\(k)x − 1) / x²")
    default:
        let g = lin(a)
        let top = a == 1 ? "−x" : "−(\(lin(a - 1)))"
        return CalcProblem(topic: .quotientSpecial, prompt: "f(x) = (\(g)) / eˣ", steps: [
            intro,
            "Boxes: top = \(g), top' = 1.  bottom = eˣ, bottom' = eˣ",
            rule,
            "Plug in: [1·eˣ − (\(g))·eˣ] / (eˣ)²",
            "Both pieces on top contain eˣ. Pull it out: eˣ[1 − (\(g))]",
            "The minus hits BOTH terms in the parentheses: 1 − x − \(a) = \(top)",
            "Bottom: (eˣ)² = e^(2x). Cancel one eˣ from top and bottom → eˣ left on the bottom.",
        ], answer: "f'(x) = \(top) / eˣ")
    }
}

func generateBasic() -> CalcProblem {
    let c = rint(2...9), n = rint(2...6)
    switch rint(1...6) {
    case 1:
        return CalcProblem(topic: .basics, prompt: "f(x) = \(c)", steps: [
            "A plain number never changes, so its rate of change is 0.",
            "Rule: d/dx[c] = 0",
        ], answer: "f'(x) = 0")
    case 2:
        let a = nonzero(-6...6)
        return CalcProblem(topic: .basics, prompt: "f(x) = \(term(a, n))", steps: [
            "Power rule: bring the power down in front, then subtract 1 from the power.",
            "\(a) × \(n) = \(a * n), and \(n) − 1 = \(n - 1)",
        ], answer: "f'(x) = \(term(a * n, n - 1))")
    case 3:
        return CalcProblem(topic: .basics, prompt: "f(x) = \(c)eˣ", steps: [
            "eˣ is its own derivative. It copies itself.",
            "The number in front just rides along: d/dx[c·f] = c·f'",
        ], answer: "f'(x) = \(c)eˣ")
    case 4:
        return CalcProblem(topic: .basics, prompt: "f(x) = \(c)ln x", steps: [
            "Memorize: the derivative of ln x is 1/x.",
            "The number in front rides along: \(c) × 1/x",
        ], answer: "f'(x) = \(c)/x")
    case 5:
        let ans = c % 2 == 0 ? "\(c / 2)/√x" : "\(c)/(2√x)"
        return CalcProblem(topic: .basics, prompt: "f(x) = \(c)√x", steps: [
            "Rewrite: √x = x^(1/2)",
            "Power rule: bring down 1/2, subtract 1 → (1/2)x^(−1/2)",
            "x^(−1/2) means 1/√x, so d/dx[√x] = 1/(2√x). Memorize this one.",
            "Multiply by the \(c) in front: \(c)/(2√x)" + (c % 2 == 0 ? " = \(ans)" : ""),
        ], answer: "f'(x) = \(ans)")
    default:
        let m = rint(1...3)
        return CalcProblem(topic: .basics, prompt: "f(x) = \(c)/\(xPow(m))", steps: [
            "Rewrite with a negative power: \(c)/\(xPow(m)) = \(c)x^(−\(m))",
            "Power rule: bring down −\(m), subtract 1 → \(c)·(−\(m))·x^(−\(m + 1)) = −\(c * m)x^(−\(m + 1))",
            "Negative power means flip to the bottom: x^(−\(m + 1)) = 1/\(xPow(m + 1))",
        ], answer: "f'(x) = −\(c * m)/\(xPow(m + 1))")
    }
}

func generateProductSpecial() -> CalcProblem {
    let a = rint(1...5), n = rint(1...3), k = rint(1...5)
    let intro = "Spot the rule: two things MULTIPLIED → product rule. Fill four boxes: first, first', second, second'."
    let rule = "Product rule: f'(x) = first'·second + first·second'"
    let first = term(a, n)
    let firstP = term(a * n, n - 1)
    let front = term(a, n - 1)
    let frontStr = front == "1" ? "" : front
    switch rint(1...4) {
    case 1:
        return CalcProblem(topic: .productSpecial, prompt: "f(x) = \(first)eˣ", steps: [
            intro,
            "Boxes: first = \(first), first' = \(firstP).  second = eˣ, second' = eˣ",
            rule,
            "Plug in: (\(firstP))eˣ + (\(first))eˣ",
            "Both terms share \(frontStr)eˣ. Pull it out → \(frontStr)eˣ(\(n) + x)",
            "Reorder the bracket so x comes first: (x + \(n))",
        ], answer: "f'(x) = \(frontStr)(x + \(n))eˣ")
    case 2:
        let coef = n == 1 ? "" : "\(n)"
        let share = frontStr.isEmpty ? "Nothing extra to pull out, you're done." : "Both terms share \(frontStr). Pull it out."
        return CalcProblem(topic: .productSpecial, prompt: "f(x) = \(first)ln x", steps: [
            intro,
            "Boxes: first = \(first), first' = \(firstP).  second = ln x, second' = 1/x",
            rule,
            "Plug in: (\(firstP))ln x + (\(first))(1/x)",
            "Clean the second term: \(first) × 1/x = \(term(a, n - 1)) (dividing by x lowers the power by 1)",
            share,
        ], answer: "f'(x) = \(frontStr)(\(coef)ln x + 1)")
    case 3:
        return CalcProblem(topic: .productSpecial, prompt: "f(x) = √x·eˣ", steps: [
            intro,
            "Boxes: first = √x, first' = 1/(2√x).  second = eˣ, second' = eˣ",
            rule,
            "Plug in: eˣ/(2√x) + √x·eˣ",
            "Pull out eˣ: eˣ[1/(2√x) + √x]",
            "Common denominator inside: √x = 2x/(2√x) (because √x·2√x = 2x)",
            "Add the fractions: (1 + 2x)/(2√x)",
        ], answer: "f'(x) = eˣ(2x + 1) / (2√x)")
    default:
        let g = lin(k)
        return CalcProblem(topic: .productSpecial, prompt: "f(x) = eˣ(\(g))", steps: [
            intro,
            "Boxes: first = eˣ, first' = eˣ.  second = \(g), second' = 1",
            rule,
            "Plug in: eˣ(\(g)) + eˣ(1)",
            "Pull out eˣ: eˣ[(\(g)) + 1] = eˣ(\(lin(k + 1)))",
        ], answer: "f'(x) = eˣ(\(lin(k + 1)))")
    }
}

func generateChain() -> CalcProblem {
    let a = nonzero(-4...4), n = rint(1...2), c = nonzero(-6...6)
    let p = rint(2...4)
    let inner = plus(term(a, n), "\(c)")
    let prompt = "f(x) = (\(inner))\(sup(p))"
    let innerPrime = term(a * n, n - 1)
    let steps = [
        "Spot the rule: a whole expression raised to a power (function INSIDE a function) → chain rule.",
        "Outside = (stuff)\(sup(p)).  Inside = \(inner)",
        "Derivative of the outside, leaving the inside untouched: bring the \(p) down, lower the power by 1 → \(p)(\(inner))\(pw(p - 1))",
        "Derivative of the inside (power rule): \(innerPrime)",
        "Chain rule = outside' × inside': \(p)(\(inner))\(pw(p - 1)) · (\(innerPrime))",
        "Clean up — multiply the plain numbers/x's in front: \(p) × \(innerPrime) = \(term(p * a * n, n - 1))",
    ]
    let answer = "f'(x) = \(term(p * a * n, n - 1))(\(inner))\(pw(p - 1))"
    return CalcProblem(topic: .chain, prompt: prompt, steps: steps, answer: answer)
}

func generateLogExp() -> CalcProblem {
    let isExp = Bool.random()
    let a = nonzero(-4...4), b = nonzero(-6...6)
    let inner = plus(term(a, 1), "\(b)")
    if isExp {
        let prompt = "f(x) = e^(\(inner))"
        let steps = [
            "Rule: e^(stuff) → e^(stuff) × stuff'. The e part copies itself exactly.",
            "stuff = \(inner), so stuff' = \(a)",
            "Multiply: e^(\(inner)) × \(a). Put the number in front.",
        ]
        let answer = "f'(x) = \(a)·e^(\(inner))"
        return CalcProblem(topic: .logexp, prompt: prompt, steps: steps, answer: answer)
    } else {
        let prompt = "f(x) = ln(\(inner))"
        let steps = [
            "Rule: ln(stuff) → stuff' / stuff. Derivative of the inside OVER the inside.",
            "stuff = \(inner), so stuff' = \(a)",
            "Put \(a) on top, the original inside on the bottom.",
        ]
        let answer = "f'(x) = \(a) / (\(inner))"
        return CalcProblem(topic: .logexp, prompt: prompt, steps: steps, answer: answer)
    }
}

// MARK: - R6 helpers

// Reduced fraction string: frac(-6, 8) = "−3/4", frac(4, 2) = "2".
func frac(_ n: Int, _ d: Int) -> String {
    let g = max(gcd(n, d), 1)
    var a = n / g, b = d / g
    if b < 0 { a = -a; b = -b }
    let sign = a < 0 ? "−" : ""
    return b == 1 ? "\(sign)\(abs(a))" : "\(sign)\(abs(a))/\(b)"
}

// Short decimal: 0.0769 → "0.0769", -7.3077 → "−7.308"
func dec(_ x: Double) -> String {
    let s = String(format: "%.4g", x)
    return s.hasPrefix("-") ? "−" + String(s.dropFirst()) : s
}

func padL(_ s: String, _ w: Int) -> String { String(repeating: " ", count: max(0, w - s.count)) + s }

// Accepts "0.25", "-1/13", "−17/16", " 3 "
func parseAnswer(_ raw: String) -> Double? {
    let s = raw.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: " ", with: "")
    if s.isEmpty { return nil }
    let parts = s.split(separator: "/")
    if parts.count == 2, let a = Double(String(parts[0])), let b = Double(String(parts[1])), b != 0 { return a / b }
    if parts.count == 1 { return Double(s) }
    return nil
}

// MARK: - R6 generators

func generateInverseDeriv() -> CalcProblem {
    let formula = "Formula: (f⁻¹)'(b) = 1 / f'(a), where a is the input that gives f(a) = b."
    if rint(1...3) == 1 {
        // Exp/log version (Quiz 7): the a comes from e⁰ = 1 or ln 1 = 0
        let k = rint(1...5)
        let useExp = Bool.random()
        let fStr = useExp ? "eˣ + \(term(k, 1))" : "\(term(k, 1)) + ln x   (x > 0)"
        let b = useExp ? 1 : k
        let a = useExp ? 0 : 1
        return CalcProblem(topic: .inverseDeriv, prompt: "f(x) = \(fStr)   (one-to-one)\n\nFind (f⁻¹)'(\(b))", steps: [
            formula,
            "Find a with f(a) = \(b). Try the friendly inputs: e⁰ = 1 and ln 1 = 0.",
            useExp ? "f(0) = e⁰ + \(k)(0) = 1 + 0 = 1  ✓  So a = 0." : "f(1) = \(k)(1) + ln 1 = \(k) + 0 = \(k)  ✓  So a = 1.",
            useExp ? "f'(x) = eˣ + \(k)" : "f'(x) = \(k) + 1/x",
            useExp ? "f'(0) = e⁰ + \(k) = \(k + 1)" : "f'(1) = \(k) + 1/1 = \(k + 1)",
            "Flip it: (f⁻¹)'(\(b)) = 1/\(k + 1)",
        ], answer: "(f⁻¹)'(\(b)) = 1/\(k + 1) ≈ \(dec(1.0 / Double(k + 1)))",
           numeric: 1.0 / Double(k + 1), ask: "(f⁻¹)'(\(b)) =")
    }
    if Bool.random() {
        // Table version (R6 Q1)
        var xs: [Int] = [], fs: [Int] = []
        var x = rint(0...2), f = rint(1...4)
        for _ in 0..<3 { xs.append(x); fs.append(f); x += rint(1...3); f += rint(1...4) }
        let ds = (0..<3).map { _ in rint(2...9) }
        let r = rint(0...2)
        let a = xs[r], b = fs[r], k = ds[r]
        var rows = [" x | f(x) | f'(x)"]
        for i in 0..<3 { rows.append("\(padL("\(xs[i])", 2)) | \(padL("\(fs[i])", 4)) | \(padL("\(ds[i])", 5))") }
        var steps = [
            formula,
            "We want the slope of the INVERSE at b = \(b). First we need a.",
            "Look for \(b) in the f(x) column (NOT the x column).",
            "It's in the row x = \(a). So f(\(a)) = \(b), which means f⁻¹(\(b)) = \(a). That's a = \(a).",
            "Read f'(a) from that SAME row: f'(\(a)) = \(k).",
            "Flip it: (f⁻¹)'(\(b)) = 1/\(k)",
        ]
        if let j = xs.firstIndex(of: b), j != r {
            steps.append("TRAP: \(b) also shows up in the x column, with f'(\(b)) = \(ds[j]). Using it would give 1/\(ds[j]). That's the #1 mistake: f' must be taken at a, not at b.")
        } else {
            steps.append("#1 mistake to avoid: plugging b straight into f'. Always go b → a → f'(a) → flip.")
        }
        return CalcProblem(topic: .inverseDeriv,
                       prompt: "f is one-to-one:\n\n" + rows.joined(separator: "\n") + "\n\nFind (f⁻¹)'(\(b))",
                       steps: steps, answer: "(f⁻¹)'(\(b)) = 1/\(k) ≈ \(dec(1.0 / Double(k)))",
                       numeric: 1.0 / Double(k), ask: "(f⁻¹)'(\(b)) =")
    }
    // Formula version (R6 Q2)
    let c = rint(1...5), d = rint(-5...5)
    let a = [-1, 0, 1, 2].randomElement()!
    let g: (Int) -> Int = { t in t * t * t + c * t + d }
    let b = g(a)
    let gStr = d == 0 ? plus("x³", term(c, 1)) : plus(plus("x³", term(c, 1)), "\(d)")
    var steps = [
        formula,
        "We need a: the input with g(a) = \(b). You can't solve a cubic by algebra, so TEST small numbers: 0, 1, −1, 2.",
    ]
    for t in [0, 1, -1, 2] {
        let v = g(t)
        steps.append("g(\(t)) = (\(t))³ + \(c)(\(t)) \(d < 0 ? "−" : "+") \(abs(d)) = \(v)" + (v == b ? "  ✓ That's it." : "  ✗"))
        if t == a { break }
    }
    let k = 3 * a * a + c
    steps += [
        "So a = \(a).",
        "Differentiate: g'(x) = 3x² + \(c)   (the constant \(d) disappears).",
        "g'(\(a)) = 3(\(a))² + \(c) = \(3 * a * a) + \(c) = \(k)",
        "Flip it: (g⁻¹)'(\(b)) = 1/\(k)",
        "Note: the inverse slope only fails when g'(a) = 0 (horizontal tangent → the inverse has a vertical one).",
    ]
    return CalcProblem(topic: .inverseDeriv,
                   prompt: "g(x) = \(gStr)   (one-to-one)\n\nFind (g⁻¹)'(\(b))",
                   steps: steps, answer: "(g⁻¹)'(\(b)) = 1/\(k) ≈ \(dec(1.0 / Double(k)))",
                   numeric: 1.0 / Double(k), ask: "(g⁻¹)'(\(b)) =")
}

func generateInverseDemand() -> CalcProblem {
    let p0 = rint(2...8), bb = rint(1...5)
    let minA = bb * p0 + p0 * p0 + 10
    let A = ((minA + 9) / 10) * 10 + rint(0...10) * 10
    let q0 = A - bb * p0 - p0 * p0
    let m = bb + 2 * p0                       // D'(p0) = −m
    let mr = Double(p0) - Double(q0) / Double(m)
    let bStr = bb == 1 ? "" : "\(bb)"
    let demand = "q = D(p) = \(A) − \(bStr)p − p²"
    let askMR = Bool.random()
    var steps = [
        "Setup: D turns price into quantity. The inverse P turns quantity into price. You never need a formula for P.",
        "Current quantity: D(\(p0)) = \(A) − \(bb)(\(p0)) − (\(p0))² = \(A) − \(bb * p0) − \(p0 * p0) = \(q0)",
        "Differentiate demand: D'(p) = −\(bb) − 2p",
        "At p = \(p0): D'(\(p0)) = −\(bb) − 2(\(p0)) = −\(m)",
        "Inverse rule: P'(\(q0)) = 1 / D'(\(p0)) = −1/\(m) ≈ \(dec(-1.0 / Double(m))) dollars per unit.",
        "Sign check: negative, because to sell MORE units you have to LOWER the price.",
    ]
    if !askMR {
        steps.append("So to sell 1 more unit, cut the price by about \(dec(1.0 / Double(m))) dollars. It's an approximation (tangent line), not exact.")
        return CalcProblem(topic: .inverseDemand,
                       prompt: "Demand: \(demand)\nCurrent price: $\(p0)\n\nFind P'(q) at today's quantity  (P = inverse demand)",
                       steps: steps, answer: "P'(\(q0)) = −1/\(m) ≈ \(dec(-1.0 / Double(m))) $ per unit",
                       numeric: -1.0 / Double(m), ask: "P'(q) =")
    }
    steps += [
        "Revenue R(q) = q·P(q). Product rule: R'(q) = (1)·P(q) + q·P'(q)",
        "Fill the boxes: P(\(q0)) = \(p0) (that's just today's price!), q = \(q0), P'(\(q0)) = −1/\(m)",
        "R'(\(q0)) = \(p0) + \(q0)·(−1/\(m)) = \(p0) − \(frac(q0, m))",
        "\(frac(q0, m)) ≈ \(dec(Double(q0) / Double(m))), so R'(\(q0)) ≈ \(dec(mr)) dollars per extra unit.",
        mr < 0
            ? "Negative MR: selling one more unit LOWERS revenue. The +$\(p0) from the extra sale is beaten by the price cut on all \(q0) units."
            : "Positive MR: selling one more unit still RAISES revenue, by about $\(dec(mr)).",
    ]
    return CalcProblem(topic: .inverseDemand,
                   prompt: "Demand: \(demand)\nCurrent price: $\(p0)\n\nFind marginal revenue R'(q) at today's quantity\n(R(q) = q·P(q), P = inverse demand)",
                   steps: steps, answer: "R'(\(q0)) = \(p0) − \(frac(q0, m)) ≈ \(dec(mr)) $ per unit",
                   numeric: mr, ask: "R'(q) =")
}

func generateImplicit() -> CalcProblem {
    let intro = "y is tangled in, so differentiate BOTH sides with respect to x. Every y-term picks up a y' (chain rule)."
    let plugTip = "Plug in the point NOW, before solving. Numbers are way easier than letters."
    switch rint(1...5) {
    case 4:
        // eʸ version (Quiz 7)
        let a = rint(1...5)
        return CalcProblem(topic: .implicitDiff, prompt: "x·eʸ + y = \(a)\n\nFind dy/dx at (\(a), 0)", steps: [
            intro,
            "x·eʸ is a product → PRODUCT rule: (1)·eʸ + x·eʸ·y'   (eʸ → eʸ·y' by the chain rule)",
            "d/dx[y] = y'.   d/dx[\(a)] = 0.",
            "So: eʸ + x·eʸ·y' + y' = 0",
            plugTip,
            "At (\(a), 0), e⁰ = 1:  1 + \(a)·1·y' + y' = 0  →  1 + \(a + 1)y' = 0",
            "y' = −1/\(a + 1)",
        ], answer: "dy/dx = −1/\(a + 1) ≈ \(dec(-1.0 / Double(a + 1)))", numeric: -1.0 / Double(a + 1), ask: "dy/dx =")
    case 5:
        // ln y version (Quiz 7)
        let a = rint(1...4)
        let num = -2 * a, den = 1 + a * a
        return CalcProblem(topic: .implicitDiff, prompt: "ln y + x²y = \(a * a)\n\nFind dy/dx at (\(a), 1)", steps: [
            intro,
            "d/dx[ln y] = y'/y   (ln(stuff) → stuff'/stuff, and stuff' = y')",
            "x²y is a product → PRODUCT rule: 2x·y + x²·y'",
            "So: y'/y + 2xy + x²y' = 0",
            plugTip,
            "At (\(a), 1), ln 1 = 0 checks out:  y'/1 + 2(\(a))(1) + \(a * a)y' = 0  →  \(den)y' + \(2 * a) = 0",
            "y' = \(num)/\(den) = \(frac(num, den))",
        ], answer: "dy/dx = \(frac(num, den)) ≈ \(dec(Double(num) / Double(den)))",
           numeric: Double(num) / Double(den), ask: "dy/dx =")
    case 1:
        let pts = [(3, 4), (4, 3), (6, 8), (8, 6), (5, 12), (12, 5)]
        var (a, b) = pts.randomElement()!
        if Bool.random() { a = -a }
        if Bool.random() { b = -b }
        let r2 = a * a + b * b
        let v = -Double(a) / Double(b)
        return CalcProblem(topic: .implicitDiff, prompt: "x² + y² = \(r2)\n\nFind dy/dx at (\(a), \(b))", steps: [
            intro,
            "d/dx[x²] = 2x.   d/dx[y²] = 2y·y'.   d/dx[\(r2)] = 0 (constant).",
            "So: 2x + 2y·y' = 0",
            plugTip,
            "2(\(a)) + 2(\(b))·y' = 0  →  \(2 * a) + \(2 * b)y' = 0",
            "Move the number over: \(2 * b)y' = \(-2 * a)",
            "Divide: y' = \(-2 * a)/\(2 * b) = \(frac(-a, b))",
        ], answer: "dy/dx = \(frac(-a, b)) ≈ \(dec(v))", numeric: v, ask: "dy/dx =")
    case 2:
        let a = rint(1...3), b = rint(1...3)
        let C = a * a * b + b * b * b
        let num = -2 * a * b, den = a * a + 3 * b * b
        return CalcProblem(topic: .implicitDiff, prompt: "x²y + y³ = \(C)\n\nFind dy/dx at (\(a), \(b))", steps: [
            intro,
            "x²·y is two things multiplied → PRODUCT rule: (2x)·y + x²·y'",
            "d/dx[y³] = 3y²·y'   (chain rule: power rule, then × y')",
            "So: 2xy + x²y' + 3y²y' = 0",
            plugTip,
            "2(\(a))(\(b)) + (\(a))²y' + 3(\(b))²y' = 0  →  \(2 * a * b) + \(a * a)y' + \(3 * b * b)y' = 0",
            "Group the y' terms: \(den)y' = \(num)",
            "y' = \(num)/\(den) = \(frac(num, den))",
        ], answer: "dy/dx = \(frac(num, den)) ≈ \(dec(Double(num) / Double(den)))",
           numeric: Double(num) / Double(den), ask: "dy/dx =")
    default:
        let a = rint(1...6), b = rint(1...6)
        let C = a * a + a * b + b * b
        let num = -(2 * a + b), den = a + 2 * b
        return CalcProblem(topic: .implicitDiff, prompt: "x² + xy + y² = \(C)\n\nFind dy/dx at (\(a), \(b))", steps: [
            intro,
            "d/dx[x²] = 2x.   d/dx[y²] = 2y·y'.",
            "xy is a product → PRODUCT rule: (1)·y + x·y'",
            "So: 2x + y + xy' + 2yy' = 0",
            plugTip,
            "2(\(a)) + \(b) + \(a)y' + 2(\(b))y' = 0  →  \(2 * a + b) + \(den)y' = 0",
            "Move the number over: \(den)y' = \(num)",
            "y' = \(frac(num, den))",
            "Econ version (R6 Q5): if x = price and y = quantity, this is dq/dp, and dp/dq is just its reciprocal: \(frac(den, num)).",
        ], answer: "dy/dx = \(frac(num, den)) ≈ \(dec(Double(num) / Double(den)))",
           numeric: Double(num) / Double(den), ask: "dy/dx =")
    }
}

func generateLogDiff() -> CalcProblem {
    let why = "x is in the base AND the exponent, so the power rule and the eˣ rule both fail. Use log differentiation."
    switch rint(1...3) {
    case 1:
        let n = rint(2...5)
        return CalcProblem(topic: .logDiff, prompt: "y = x^(\(n)x)\n\nFind y'(1)", steps: [
            why,
            "Take ln of both sides: ln y = ln(x^(\(n)x))",
            "Log rule ln(aᵇ) = b·ln a: the exponent comes down → ln y = \(n)x·ln x",
            "Differentiate the left: (1/y)·y'   (chain rule).",
            "Differentiate the right (product rule): \(n)·ln x + \(n)x·(1/x) = \(n)ln x + \(n)",
            "So y'/y = \(n)(ln x + 1). Multiply by y: y' = x^(\(n)x)·\(n)(ln x + 1)",
            "At x = 1: y = 1^(\(n)) = 1 and ln 1 = 0 → y'(1) = 1·\(n)(0 + 1) = \(n)",
        ], answer: "y' = x^(\(n)x)·\(n)(ln x + 1),  y'(1) = \(n)", numeric: Double(n), ask: "y'(1) =")
    case 2:
        let k = rint(1...4)
        let v = Double(1 + k) * log(Double(1 + k)) + 2
        return CalcProblem(topic: .logDiff, prompt: "y = (x² + \(k))^x\n\nFind y'(1)", steps: [
            why,
            "Take ln: ln y = x·ln(x² + \(k))   (the exponent x comes down)",
            "Left side: y'/y.",
            "Right side, product rule: (1)·ln(x² + \(k)) + x·[2x/(x² + \(k))]   (ln(stuff) → stuff'/stuff)",
            "So y' = (x² + \(k))^x · [ln(x² + \(k)) + 2x²/(x² + \(k))]",
            "At x = 1: y = (1 + \(k))¹ = \(1 + k)",
            "Bracket at x = 1: ln(\(1 + k)) + 2/\(1 + k)",
            "y'(1) = \(1 + k)·ln(\(1 + k)) + \(1 + k)·(2/\(1 + k)) = \(1 + k)ln(\(1 + k)) + 2 ≈ \(dec(v))",
        ], answer: "y'(1) = \(1 + k)ln(\(1 + k)) + 2 ≈ \(dec(v))", numeric: v, ask: "y'(1) =")
    default:
        let c = rint(1...4)
        let v = Double(c) / 2 - 0.25
        return CalcProblem(topic: .logDiff, prompt: "y = (1 + x)^(x² + \(c)) / (eˣ + 1)\n\nFind y'(0)   (R6 Q6 style)", steps: [
            "A variable power AND a quotient → log differentiation turns it into easy pieces.",
            "Take ln. Power → multiply, divide → subtract: ln y = (x² + \(c))·ln(1 + x) − ln(eˣ + 1)",
            "First piece, product rule: 2x·ln(1 + x) + (x² + \(c))·1/(1 + x)",
            "Second piece, ln(stuff) → stuff'/stuff: eˣ/(eˣ + 1)",
            "So y'/y = 2x·ln(1 + x) + (x² + \(c))/(1 + x) − eˣ/(eˣ + 1)",
            "y' = y·[that bracket]. Now evaluate at x = 0.",
            "y(0) = 1^(\(c)) / (1 + 1) = 1/2",
            "Bracket at 0: 2(0)ln 1 + \(c)/1 − 1/2 = \(c) − 1/2",
            "y'(0) = (1/2)(\(c) − 1/2) = \(dec(v))",
        ], answer: "y' = y·[2x·ln(1+x) + (x²+\(c))/(1+x) − eˣ/(eˣ+1)],  y'(0) = \(dec(v))",
           numeric: v, ask: "y'(0) =")
    }
}

// Quiz 7: derivatives of exponential and log functions beyond e^(ax+b) / ln(ax+b).
func generateExpLog() -> CalcProblem {
    let subs: [Int: String] = [2: "₂", 3: "₃", 5: "₅", 10: "₁₀"]
    switch rint(1...6) {
    case 1:
        let b = [2, 3, 5, 10].randomElement()!, k = rint(1...4)
        let kx = term(k, 1)
        let v = Double(k) * log(Double(b))
        return CalcProblem(topic: .expLog, prompt: "f(x) = \(b)^(\(kx))\n\nFind f'(0)", steps: [
            "Base is a number other than e → rule: d/dx[aˣ] = aˣ·ln a.  (aˣ = e^(x·ln a), so the ln a falls out.)",
            "With a chain: \(b)^(stuff) → \(b)^(stuff) · ln \(b) · stuff'",
            "stuff = \(kx), so stuff' = \(k)",
            "f'(x) = \(k == 1 ? "" : "\(k)·")ln \(b)·\(b)^(\(kx))",
            "At x = 0: \(b)⁰ = 1, so f'(0) = \(k == 1 ? "" : "\(k)·")ln \(b) ≈ \(dec(v))",
            "#1 mistake: using the power rule (\(kx)·\(b)^(\(kx) − 1)). The variable is in the EXPONENT, not the base.",
        ], answer: "f'(x) = \(k == 1 ? "" : "\(k)·")ln \(b)·\(b)^(\(kx)),  f'(0) ≈ \(dec(v))", numeric: v, ask: "f'(0) =")
    case 2:
        let b = [2, 3, 10].randomElement()!, c = rint(1...5)
        let v = 2.0 / (Double(1 + c) * log(Double(b)))
        return CalcProblem(topic: .expLog, prompt: "f(x) = log\(subs[b]!)(x² + \(c))\n\nFind f'(1)", steps: [
            "Rule: d/dx[log_b x] = 1 / (x·ln b).  Change of base: log_b u = ln u / ln b, so it's the ln rule divided by ln b.",
            "With a chain: log\(subs[b]!)(stuff) → stuff' / (stuff · ln \(b))",
            "stuff = x² + \(c), so stuff' = 2x",
            "f'(x) = 2x / ((x² + \(c))·ln \(b))",
            "At x = 1: 2 / ((1 + \(c))·ln \(b)) = 2 / (\(1 + c)·\(dec(log(Double(b))))) ≈ \(dec(v))",
        ], answer: "f'(x) = 2x / ((x² + \(c)) ln \(b)),  f'(1) ≈ \(dec(v))", numeric: v, ask: "f'(1) =")
    case 3:
        let k = nonzero(-5...5)
        let inner = plus("x²", term(k, 1))
        return CalcProblem(topic: .expLog, prompt: "f(x) = e^(\(inner))\n\nFind f'(0)", steps: [
            "e^(stuff) → e^(stuff) · stuff'. The e part copies itself exactly.",
            "stuff = \(inner), so stuff' = \(plus("2x", "\(k)"))",
            "f'(x) = (\(plus("2x", "\(k)")))·e^(\(inner))",
            "At x = 0: e⁰ = 1, so f'(0) = (0 \(k < 0 ? "−" : "+") \(abs(k)))·1 = \(k)",
        ], answer: "f'(x) = (\(plus("2x", "\(k)")))e^(\(inner)),  f'(0) = \(k)", numeric: Double(k), ask: "f'(0) =")
    case 4:
        let n = rint(2...4), c = rint(1...4)
        let v = Double(n) + 1.0 / Double(1 + c)
        return CalcProblem(topic: .expLog, prompt: "f(x) = ln[(x² + 1)\(sup(n))·(x + \(c))]\n\nFind f'(1)", steps: [
            "Don't product-rule inside the ln. Use LOG RULES FIRST: ln(AB) = ln A + ln B,  ln(Aⁿ) = n·ln A.",
            "f(x) = \(n)·ln(x² + 1) + ln(x + \(c))",
            "Now each piece is ln(stuff) → stuff'/stuff:",
            "\(n)·ln(x² + 1) → \(n)·2x/(x² + 1) = \(2 * n)x/(x² + 1)",
            "ln(x + \(c)) → 1/(x + \(c))",
            "f'(x) = \(2 * n)x/(x² + 1) + 1/(x + \(c))",
            "At x = 1: \(2 * n)/2 + 1/\(1 + c) = \(n) + 1/\(1 + c) ≈ \(dec(v))",
        ], answer: "f'(x) = \(2 * n)x/(x² + 1) + 1/(x + \(c)),  f'(1) ≈ \(dec(v))", numeric: v, ask: "f'(1) =")
    case 5:
        let n = rint(2...4)
        let v = Double(n + 1) * exp(Double(n - 1))
        return CalcProblem(topic: .expLog, prompt: "f(x) = x\(sup(n))·ln x\n\nFind f'(e)", steps: [
            "Two things multiplied → product rule. u = x\(sup(n)), v = ln x.",
            "u' = \(n)x\(pw(n - 1)),  v' = 1/x",
            "f'(x) = \(n)x\(pw(n - 1))·ln x + x\(sup(n))·(1/x) = \(n)x\(pw(n - 1))·ln x + x\(pw(n - 1))",
            "At x = e: ln e = 1, so f'(e) = \(n)e\(pw(n - 1)) + e\(pw(n - 1)) = \(n + 1)e\(pw(n - 1)) ≈ \(dec(v))",
        ], answer: "f'(x) = \(n)x\(pw(n - 1)) ln x + x\(pw(n - 1)),  f'(e) = \(n + 1)e\(pw(n - 1)) ≈ \(dec(v))", numeric: v, ask: "f'(e) =")
    default:
        let k = nonzero(-4...4), c = rint(1...5)
        let kx = term(k, 1)
        return CalcProblem(topic: .expLog, prompt: "f(x) = e^(\(kx)) / (x² + \(c))\n\nFind f'(0)", steps: [
            "Divided → quotient rule: (u'v − uv') / v²",
            "u = e^(\(kx)) → u' = \(k)e^(\(kx))   (chain).   v = x² + \(c) → v' = 2x",
            "f'(x) = [\(k)e^(\(kx))(x² + \(c)) − e^(\(kx))·2x] / (x² + \(c))²",
            "Pull out e^(\(kx)) on top: e^(\(kx))[\(k)(x² + \(c)) − 2x] / (x² + \(c))²",
            "At x = 0: e⁰ = 1 → [\(k)·\(c) − 0] / \(c)² = \(frac(k * c, c * c))",
        ], answer: "f'(x) = e^(\(kx))[\(k)(x² + \(c)) − 2x] / (x² + \(c))²,  f'(0) = \(frac(k, c))",
           numeric: Double(k) / Double(c), ask: "f'(0) =")
    }
}

// MARK: - Lessons (shown before the worked example at the start of each level)

let lessons: [CalcTopic: [String]] = [
    .basics: [
        "Power rule: bring the power down, subtract 1.   d/dx[x⁵] = 5x⁴",
        "Constants vanish: d/dx[7] = 0.   Numbers in front ride along: d/dx[3x²] = 6x",
        "Memorize: d/dx[eˣ] = eˣ,   d/dx[ln x] = 1/x,   d/dx[√x] = 1/(2√x)",
        "Rewrite before you differentiate: 4/x² = 4x⁻² → −8x⁻³ = −8/x³",
    ],
    .product: [
        "Two things MULTIPLIED → product rule:   (uv)' = u'v + uv'",
        "Fill four boxes first: u, u', v, v'. Then plug in. Then simplify.",
        "Example: (x² + 1)(3x − 2) → u' = 2x, v' = 3 → 2x(3x − 2) + (x² + 1)(3)",
        "#1 mistake: (uv)' ≠ u'·v'. You need BOTH pieces added.",
    ],
    .productSpecial: [
        "Same product rule. The boxes just use the basic facts: eˣ → eˣ, ln x → 1/x, √x → 1/(2√x).",
        "Example: x²eˣ → 2x·eˣ + x²·eˣ = xeˣ(2 + x)",
        "Finish by pulling out what both terms share (eˣ, a power of x).",
    ],
    .quotient: [
        "One thing DIVIDED by another → quotient rule:   (u/v)' = (u'v − uv') / v²",
        "Chant: \"low d-high minus high d-low, over low squared.\"",
        "ORDER MATTERS because of the minus. Top's derivative goes first.",
        "Wrap the second product in parentheses so the minus hits every term. Leave the bottom squared.",
    ],
    .quotientSpecial: [
        "Same quotient rule with eˣ, ln x, √x in the boxes.",
        "Fraction inside a fraction (from √x)? Multiply top AND bottom by what's causing it.",
        "Look for a common factor on top (eˣ, x) and cancel with the bottom if you can.",
    ],
    .chain: [
        "A function INSIDE a function → chain rule: derivative of the outside × derivative of the inside.",
        "Example: (3x² + 1)⁴ → 4(3x² + 1)³ · 6x = 24x(3x² + 1)³",
        "#1 mistake: forgetting the × inside' at the end.",
    ],
    .logexp: [
        "e^(stuff) → e^(stuff) · stuff'        ln(stuff) → stuff' / stuff",
        "Example: e^(5x − 2) → 5e^(5x − 2).   ln(4x + 1) → 4/(4x + 1)",
    ],
    .productChain: [
        "Product rule on the outside, chain rule inside one of the boxes.",
        "Then factor out the shared power: the lowest power of the repeated chunk.",
    ],
    .quotientChain: [
        "Quotient rule on the outside, chain rule for the bottom's derivative.",
        "Factor the shared chunk out of the top, then cancel powers with the bottom.",
    ],
    .inverseDeriv: [
        "THE RULE:   if f(a) = b, then (f⁻¹)'(b) = 1 / f'(a)",
        "Why: the inverse is f flipped over y = x, so rise/run flips to run/rise.",
        "RECIPE:  b → find a (the x with f(a) = b) → read/compute f'(a) → flip it.",
        "From a table: find b in the f(x) COLUMN, use that row's f'.",
        "From a formula: test small numbers (0, 1, −1, 2) until f(a) = b.",
        "#1 MISTAKE: computing f'(b). The slope must come from a, not b.",
        "It FAILS when f'(a) = 0: horizontal tangent → the inverse has a vertical tangent, no finite slope. (x³ at 0 is the classic.)",
    ],
    .inverseDemand: [
        "Demand q = D(p). Inverse demand p = P(q). Same rule as inverses: P'(q) = 1 / D'(p)",
        "Units: dollars per unit. It's negative because selling more requires a lower price.",
        "To sell Δq more units: Δp ≈ P'(q)·Δq. It's an APPROXIMATION (tangent line).",
        "Revenue R(q) = q·P(q). Product rule → MR = R'(q) = P(q) + q·P'(q)",
        "P(q) = the price you get for the extra unit (+).  q·P'(q) = the price cut on ALL units (−).",
        "If MR < 0, selling more LOWERS revenue. That's why \"more sales = more revenue\" is wrong.",
    ],
    .implicitDiff: [
        "Use it when y is tangled in and you can't solve for y.",
        "1) Differentiate BOTH sides with respect to x.",
        "2) Every y-term gets × y':   y² → 2y·y'    eʸ → eʸ·y'    ln y → y'/y    xy → y + x·y' (product rule!)",
        "3) PLUG IN THE POINT right away.",
        "4) It's now a simple equation in y'. Collect the y' terms and solve.",
        "Example: x² + y² = 25 at (3, 4): 2(3) + 2(4)y' = 0 → y' = −3/4",
        "Econ: dq/dp and dp/dq at the same point are reciprocals.",
    ],
    .expLog: [
        "e^(stuff) → e^(stuff)·stuff'          ln(stuff) → stuff'/stuff",
        "Other bases:  aˣ → aˣ·ln a          log_b x → 1/(x·ln b)",
        "With a chain: a^(stuff) → a^(stuff)·ln a·stuff'      log_b(stuff) → stuff'/(stuff·ln b)",
        "ln of a product, quotient or power? Use LOG RULES FIRST, then differentiate each piece.",
        "Useful values: e⁰ = 1, ln 1 = 0, ln e = 1.",
        "#1 mistake: power rule on aˣ. The variable is in the exponent, so it's the exponential rule.",
    ],
    .logDiff: [
        "Use it when x is in the base AND the exponent (like xˣ), or for a messy product/quotient.",
        "1) Take ln of both sides.",
        "2) Log rules: ln(aᵇ) = b·ln a,   ln(ab) = ln a + ln b,   ln(a/b) = ln a − ln b",
        "3) Differentiate: the left side becomes y'/y.",
        "4) Multiply both sides by y (the ORIGINAL function).",
        "Example: y = xˣ → ln y = x ln x → y'/y = ln x + 1 → y' = xˣ(ln x + 1)",
    ],
]

func mixedLesson(_ r6: Bool) -> [String] {
    r6 ? [
        "Nobody tells you the technique. Decide FIRST, then work it.",
        "aˣ, log_b, e^(…), ln(…) on their own → exp/log rules (log rules first if ln wraps a product)",
        "f⁻¹, a table, or \"the inverse\" → inverse rule: 1/f'(a)",
        "Demand/price + \"one more unit\" or revenue → P' = 1/D', MR = P + qP'",
        "x and y tangled in one equation → implicit differentiation",
        "x in the base AND the exponent → log differentiation",
    ] : [
        "Nobody tells you the rule. Decide FIRST: multiplied → product, divided → quotient.",
        "Then fill the four boxes before doing any algebra.",
    ]
}

func generate(_ topic: CalcTopic) -> CalcProblem {
    switch topic {
    case .inverseDeriv: return generateInverseDeriv()
    case .inverseDemand: return generateInverseDemand()
    case .implicitDiff: return generateImplicit()
    case .logDiff: return generateLogDiff()
    case .expLog: return generateExpLog()
    case .basics: return generateBasic()
    case .polynomial: return generatePolynomial()
    case .productSpecial: return generateProductSpecial()
    case .product: return generateProduct()
    case .quotient: return generateQuotient()
    case .quotientSpecial: return generateQuotientSpecial()
    case .chain: return generateChain()
    case .logexp: return generateLogExp()
    case .productChain: return generateProductChain()
    case .quotientChain: return generateQuotientChain()
    }
}

// Technique families for the "which technique?" check in mixed mode, and the clue that gives each one away.
func family(_ t: CalcTopic) -> String {
    switch t {
    case .product, .productSpecial, .productChain: return "Product rule"
    case .quotient, .quotientSpecial, .quotientChain: return "Quotient rule"
    case .expLog, .logexp: return "Exp/log rules"
    case .inverseDeriv: return "Inverse rule"
    case .inverseDemand: return "Inverse demand / MR"
    case .implicitDiff: return "Implicit"
    case .logDiff: return "Log differentiation"
    case .chain: return "Chain rule"
    case .basics, .polynomial: return "Basic rules"
    }
}

let familyTell: [String: String] = [
    "Product rule": "Two functions MULTIPLIED together.",
    "Quotient rule": "One function DIVIDED by another.",
    "Exp/log rules": "One eˣ, aˣ, ln or log_b function (maybe with a chain). No y, no f⁻¹, and x isn't in the base AND the exponent.",
    "Inverse rule": "It says f⁻¹ or \"the inverse\", or gives a table → (f⁻¹)'(b) = 1/f'(a).",
    "Inverse demand / MR": "Demand, price, revenue or \"one more unit\" → P' = 1/D' and MR = P + q·P'.",
    "Implicit": "One equation with x AND y tangled together that you can't solve for y.",
    "Log differentiation": "x in the base AND the exponent (like x^x), or a big product/quotient raised to powers.",
]

// MARK: - CalcEngine

struct CalcLevel {
    let name: String
    let topic: CalcTopic?   // nil = mixed quiz, rule hidden
    let blurb: String
}

enum CalcMode: Hashable {
    case path      // Quiz 5 build-up path
    case mixed     // Quiz 5 mixed
    case r6path    // R6 build-up path
    case r6mixed   // R6 mixed
    case topic(CalcTopic)
}

final class CalcEngine: ObservableObject {
    static let levels: [CalcLevel] = [
        CalcLevel(name: "Basic derivatives", topic: .basics, blurb: "The building blocks: power rule, constants, eˣ, ln x, √x, 1/xⁿ."),
        CalcLevel(name: "Product rule", topic: .product, blurb: "first' × second + first × second'"),
        CalcLevel(name: "Product with eˣ, ln, √", topic: .productSpecial, blurb: "Same product rule. The boxes just use the basic facts."),
        CalcLevel(name: "Quotient rule", topic: .quotient, blurb: "Low d-high minus high d-low, over low squared."),
        CalcLevel(name: "Quotient with eˣ, ln, √", topic: .quotientSpecial, blurb: "Four boxes first, simplify last."),
        CalcLevel(name: "Mixed quiz (rule hidden)", topic: nil, blurb: "Like the real quiz: nobody tells you the rule. Decide first."),
    ]
    static let r6Levels: [CalcLevel] = [
        CalcLevel(name: "Exp & log derivatives", topic: .expLog, blurb: "aˣ → aˣ ln a.   log_b x → 1/(x ln b).   Log rules before differentiating."),
        CalcLevel(name: "Inverse function derivatives", topic: .inverseDeriv, blurb: "(f⁻¹)'(b) = 1 / f'(a), where f(a) = b."),
        CalcLevel(name: "Inverse demand & marginal revenue", topic: .inverseDemand, blurb: "P'(q) = 1 / D'(p).   MR = P + q·P'."),
        CalcLevel(name: "Implicit differentiation", topic: .implicitDiff, blurb: "Differentiate both sides. Every y-term gets a y'. Plug in early."),
        CalcLevel(name: "Log differentiation", topic: .logDiff, blurb: "Take ln, use log rules, differentiate, multiply by y."),
        CalcLevel(name: "R6 mixed quiz (technique hidden)", topic: nil, blurb: "Like the real quiz: decide the technique first."),
    ]
    static let streakGoal = 4
    static let quizMix: [CalcTopic] = [.product, .productSpecial, .quotient, .quotientSpecial]
    static let r6Mix: [CalcTopic] = [.expLog, .inverseDeriv, .inverseDemand, .implicitDiff, .logDiff]

    @Published var current: CalcProblem
    @Published var revealed = false
    @Published var weights: [CalcTopic: Int]
    @Published var attempted: [CalcTopic: Int]
    @Published var missed: [CalcTopic: Int]
    @Published var level: Int
    @Published var streak = 0
    @Published var banner: String? = nil
    @Published var stepsShown = 0
    @Published var watching = true       // worked example at the start of each level
    @Published var teaching = true       // lesson card before the worked example
    @Published var lessonAtStart = true  // false = lesson reopened mid-problem
    @Published var answerText = ""
    @Published var checked: Bool? = nil  // result of a typed answer
    @Published var parseError = false
    @Published var guessedFamily: String? = nil   // mixed mode: the technique picked before solving
    var retryTopic: CalcTopic? = nil                  // after a miss, the next problem is the same type with new numbers
    @Published var mode: CalcMode = .r6path {
        didSet {
            streak = 0
            banner = nil
            if onPath {
                level = min(max(UserDefaults.standard.integer(forKey: levelKey), 0), pathLevels.count - 1)
            }
            teaching = true
            lessonAtStart = true
            watching = !isMixedMode
            next()
        }
    }

    var onPath: Bool { mode == .path || mode == .r6path }
    var isMixedMode: Bool { mode == .mixed || mode == .r6mixed }
    var pathLevels: [CalcLevel] { mode == .r6path ? Self.r6Levels : Self.levels }
    var levelKey: String { mode == .r6path ? "pathLevelR6" : "pathLevel" }
    var isR6: Bool {
        switch mode {
        case .r6path, .r6mixed: return true
        case .topic(let t): return Self.r6Mix.contains(t)
        default: return false
        }
    }

    var ruleHidden: Bool {
        switch mode {
        case .mixed, .r6mixed: return true
        case .path, .r6path: return pathLevels[level].topic == nil
        case .topic: return false
        }
    }

    var lessonTitle: String {
        switch mode {
        case .topic(let t): return t.rawValue
        case .mixed, .r6mixed: return "Mixed quiz: how to decide"
        case .path, .r6path: return pathLevels[level].name
        }
    }

    var lessonLines: [String] {
        switch mode {
        case .topic(let t): return lessons[t] ?? []
        case .mixed: return mixedLesson(false)
        case .r6mixed: return mixedLesson(true)
        case .path, .r6path:
            if let t = pathLevels[level].topic { return lessons[t] ?? [] }
            return mixedLesson(mode == .r6path)
        }
    }

    init() {
        var w: [CalcTopic: Int] = [:]
        for t in CalcTopic.allCases { w[t] = 3 }
        if let saved = UserDefaults.standard.dictionary(forKey: "weights_v4") as? [String: Int] {
            for (k, v) in saved { if let t = CalcTopic(rawValue: k) { w[t] = v } }
        }
        weights = w
        attempted = Self.loadCounts("attempted")
        missed = Self.loadCounts("missed")
        // The Quiz 7 exp/log level was inserted at the front of the R6 path; shift saved progress once so it stays on the same topic.
        if !UserDefaults.standard.bool(forKey: "q7LevelMigrated") {
            let old = UserDefaults.standard.integer(forKey: "pathLevelR6")
            if old > 0 { UserDefaults.standard.set(old + 1, forKey: "pathLevelR6") }
            UserDefaults.standard.set(true, forKey: "q7LevelMigrated")
        }
        let savedLevel = UserDefaults.standard.integer(forKey: "pathLevelR6")
        level = min(max(savedLevel, 0), Self.r6Levels.count - 1)
        current = generate(.basics)
        current = generate(chooseTopic())
    }

    static func loadCounts(_ key: String) -> [CalcTopic: Int] {
        var d: [CalcTopic: Int] = [:]
        for t in CalcTopic.allCases { d[t] = 0 }
        if let saved = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] {
            for (k, v) in saved { if let t = CalcTopic(rawValue: k) { d[t] = v } }
        }
        return d
    }

    func save() {
        var w: [String: Int] = [:]
        for (k, v) in weights { w[k.rawValue] = v }
        UserDefaults.standard.set(w, forKey: "weights_v4")
        var a: [String: Int] = [:]
        for (k, v) in attempted { a[k.rawValue] = v }
        UserDefaults.standard.set(a, forKey: "attempted")
        var m: [String: Int] = [:]
        for (k, v) in missed { m[k.rawValue] = v }
        UserDefaults.standard.set(m, forKey: "missed")
        if onPath { UserDefaults.standard.set(level, forKey: levelKey) }
    }

    func weightedPick(_ group: [CalcTopic]) -> CalcTopic {
        let pool = group.flatMap { t in Array(repeating: t, count: max(weights[t] ?? 1, 1)) }
        return pool.randomElement() ?? group[0]
    }

    func chooseTopic() -> CalcTopic {
        if let r = retryTopic {
            retryTopic = nil
            return r
        }
        switch mode {
        case .topic(let t): return t
        case .mixed: return weightedPick(Self.quizMix)
        case .r6mixed: return weightedPick(Self.r6Mix)
        case .path: return Self.levels[level].topic ?? weightedPick(Self.quizMix)
        case .r6path: return Self.r6Levels[level].topic ?? weightedPick(Self.r6Mix)
        }
    }

    var done: Bool { revealed && stepsShown > current.steps.count }
    var canType: Bool { current.numeric != nil && !watching && !teaching && checked == nil && !done && !needsGuess }

    // Mixed quizzes: name the technique before working the problem.
    var needsGuess: Bool { ruleHidden && !watching && !teaching && !revealed && guessedFamily == nil }
    var guessedRight: Bool { guessedFamily == family(current.topic) }
    var familyOptions: [String] {
        var seen: [String] = []
        for t in (isR6 ? Self.r6Mix : Self.quizMix) where !seen.contains(family(t)) { seen.append(family(t)) }
        return seen
    }

    func guess(_ f: String) {
        guessedFamily = f
        if !guessedRight {
            streak = 0
            weights[current.topic] = min((weights[current.topic] ?? 3) + 1, 12)
            save()
        }
    }

    func next() {
        current = generate(chooseTopic())
        guessedFamily = nil
        revealed = false
        stepsShown = 0
        answerText = ""
        checked = nil
        parseError = false
    }

    // One step per press, like watching it get written out.
    func advance() {
        if !revealed {
            revealed = true
            stepsShown = 1
        } else if stepsShown <= current.steps.count {
            stepsShown += 1
        }
    }

    func showAll() {
        revealed = true
        stepsShown = current.steps.count + 1
    }

    // Typed answer → checked against the exact value (1% or 0.005 slack for rounding).
    func check() {
        guard let target = current.numeric, let g = parseAnswer(answerText) else {
            parseError = true
            return
        }
        parseError = false
        checked = abs(g - target) <= max(0.01 * abs(target), 0.005)
        showAll()
    }

    func yourTurn() {
        watching = false
        next()
    }

    func openLesson() {
        lessonAtStart = false
        teaching = true
    }

    // Leaving the lesson card: at the start of a level → fresh worked example; mid-problem → back to it.
    func closeLesson() {
        teaching = false
        if lessonAtStart {
            watching = !isMixedMode
            next()
        }
    }

    func setLevel(_ l: Int) {
        level = min(max(l, 0), pathLevels.count - 1)
        streak = 0
        banner = nil
        watching = true
        teaching = true
        lessonAtStart = true
        save()
        next()
    }

    func mark(gotIt: Bool) {
        banner = nil
        attempted[current.topic, default: 0] += 1
        if gotIt {
            weights[current.topic] = max((weights[current.topic] ?? 3) - 1, 2)
            streak += 1
            if onPath, streak >= Self.streakGoal, level < pathLevels.count - 1 {
                level += 1
                streak = 0
                banner = "Level up! Now: \(pathLevels[level].name)"
                watching = true
                teaching = true
                lessonAtStart = true
            }
        } else {
            missed[current.topic, default: 0] += 1
            weights[current.topic] = min((weights[current.topic] ?? 3) + 2, 12)
            streak = 0
            retryTopic = current.topic
        }
        save()
        next()
        if !gotIt {
            banner = "Same type again with new numbers. Fix the step where you split off."
        }
    }
}

// MARK: - Math rendering

// Renders "e^(x² + 3x)" with a real raised exponent and "log_b" with a lowered subscript.
// ^ or _ followed by (...) takes the whole parenthesized group; otherwise it takes the run of letters/digits.
func mathText(_ s: String, size: CGFloat, weight: Font.Weight = .regular, mono: Bool = false) -> Text {
    let design: Font.Design = mono ? .monospaced : .default
    let base = Font.system(size: size, weight: weight, design: design)
    let small = Font.system(size: size * 0.72, weight: weight, design: design)
    let chars = Array(s)
    var out = Text("")
    var buf = ""
    var i = 0
    while i < chars.count {
        let c = chars[i]
        if (c == "^" || c == "_"), i + 1 < chars.count {
            var j = i + 1
            var piece = ""
            if chars[j] == "(" {
                var depth = 0
                while j < chars.count {
                    if chars[j] == "(" { depth += 1 } else if chars[j] == ")" { depth -= 1; if depth == 0 { break } }
                    piece.append(chars[j])
                    j += 1
                }
                piece.removeFirst()   // the opening parenthesis
                j += 1                // skip the closing one
            } else {
                while j < chars.count, chars[j].isLetter || chars[j].isNumber { piece.append(chars[j]); j += 1 }
            }
            if piece.isEmpty {
                buf.append(c)
                i += 1
                continue
            }
            if !buf.isEmpty { out = out + Text(buf).font(base); buf = "" }
            out = out + Text(piece).font(small).baselineOffset(c == "^" ? size * 0.38 : -size * 0.18)
            i = j
            continue
        }
        buf.append(c)
        i += 1
    }
    if !buf.isEmpty { out = out + Text(buf).font(base) }
    return out
}

// MARK: - View

struct CalcPracticeView: View {
    @StateObject private var engine = CalcEngine()
    @AppStorage("hideStats") private var hideStats = true

    private var pathHeader: some View {
        let levels = engine.pathLevels
        let lv = levels[engine.level]
        let last = engine.level == levels.count - 1
        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button { engine.setLevel(engine.level - 1) } label: { Image(systemName: "chevron.left") }
                    .disabled(engine.level == 0)
                    .keyboardShortcut("[", modifiers: [])
                Text("Level \(engine.level + 1) of \(levels.count) · \(lv.name)")
                    .font(.subheadline.weight(.semibold))
                Button { engine.setLevel(engine.level + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(last)
                    .keyboardShortcut("]", modifiers: [])
            }
            mathText(lv.blurb, size: 11)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(0..<CalcEngine.streakGoal, id: \.self) { i in
                    Circle()
                        .fill(i < engine.streak ? Color.green : Color.secondary.opacity(0.3))
                        .frame(width: 9, height: 9)
                }
                Text(last ? "Final level: keep going" : "\(engine.streak)/\(CalcEngine.streakGoal) in a row to level up")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func lessonCard(_ k: CGFloat) -> some View {
        VStack(spacing: 14 * k) {
            Text("📘 LESSON: \(engine.lessonTitle)")
                .font(.system(size: 18 * k, weight: .bold))
                .foregroundStyle(Color.blue)
            ScrollView {
                VStack(alignment: .leading, spacing: 10 * k) {
                    ForEach(Array(engine.lessonLines.enumerated()), id: \.offset) { _, line in
                        mathText("• \(line)", size: 15 * k)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
            }
            .frame(height: 380 * k)
            Text("Read it once out loud. Then watch one done step by step.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button {
                engine.closeLesson()
            } label: {
                Label(engine.lessonAtStart
                      ? (engine.isMixedMode ? "Start the quiz (Return)" : "Show me a worked example (Return)")
                      : "Back to my problem (Return)", systemImage: "play.fill")
            }
            .keyboardShortcut(.return, modifiers: [])
            .controlSize(.large)
            .tint(.blue)
        }
    }

    private func answerBox(_ k: CGFloat) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                mathText(engine.current.ask ?? "Answer =", size: 15 * k, weight: .medium, mono: true)
                TextField("e.g. -1/13 or 0.25", text: $engine.answerText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .onSubmit { engine.check() }
                Button("Check") { engine.check() }
            }
            Text(engine.parseError ? "Type a number or a fraction like -17/16."
                 : "Type your answer and press Return. Or skip it and reveal steps with Space.")
                .font(.caption2)
                .foregroundStyle(engine.parseError ? Color.red : Color.secondary)
        }
    }

    var body: some View {
        GeometryReader { geo in
        let k = min(max(geo.size.height / 760, 1), 1.8)
        VStack(spacing: 16 * k) {
            HStack {
                Text(engine.isR6 ? "Calc for MFE · Quiz 7 Prep" : "Calc for MFE · Quiz 5 Prep")
                    .font(.headline)
                Spacer()
                Button {
                    engine.openLesson()
                } label: {
                    Label("Lesson (L)", systemImage: "book")
                }
                .keyboardShortcut("l", modifiers: [])
                .disabled(engine.teaching)
                Button {
                    hideStats.toggle()
                } label: {
                    Label(hideStats ? "Show stats" : "Hide stats", systemImage: "chart.bar")
                }
                .keyboardShortcut("h", modifiers: [])
                Button {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                } label: {
                    Label("Full screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .keyboardShortcut("f", modifiers: [])
            }
            .padding(.horizontal)
            .padding(.top, 16)

            Picker("Mode", selection: $engine.mode) {
                Text("Quiz 7 path: exp/log, inverses, implicit, log diff").tag(CalcMode.r6path)
                Text("Quiz 7 mixed quiz (technique hidden)").tag(CalcMode.r6mixed)
                Divider()
                Text("Quiz 5 build-up path").tag(CalcMode.path)
                Text("Quiz 5 mixed (rule hidden)").tag(CalcMode.mixed)
                Divider()
                ForEach(CalcTopic.allCases) { t in
                    Text(t.rawValue).tag(CalcMode.topic(t))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 380)

            if engine.onPath {
                pathHeader
            }

            if let b = engine.banner {
                Text(b)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(b.hasPrefix("Same type") ? Color.orange : Color.green)
            }

            if engine.teaching {
                lessonCard(k)
            } else {
            VStack(spacing: 10) {
                Text(engine.watching ? "WORKED EXAMPLE: watch it step by step, then you try one"
                     : (engine.ruleHidden && !engine.revealed ? "Which technique? Decide before you reveal." : engine.current.topic.rawValue))
                    .font(.caption.weight(engine.watching ? .bold : .regular))
                    .foregroundStyle(engine.watching ? Color.orange : Color.secondary)
                mathText(engine.current.prompt, size: 22 * k, weight: .medium, mono: true)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                Text(engine.watching ? "Press Space to see each step. Say it out loud as it appears."
                     : "Work it on paper. Then type your answer, or reveal one step at a time and check yourself.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(minHeight: 100 * k)

            if engine.canType {
                answerBox(k)
            }

            if engine.revealed {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(engine.current.steps.prefix(engine.stepsShown).enumerated()), id: \.offset) { i, step in
                                mathText("\(i + 1). \(step)", size: 14 * k)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if engine.done {
                                Divider()
                                mathText(engine.current.answer, size: 16 * k, weight: .semibold, mono: true)
                                    .foregroundStyle(Color.accentColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                    }
                    .onChange(of: engine.stepsShown) { _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
                .frame(height: 260 * k)

                if !engine.done {
                    HStack(spacing: 14) {
                        Button {
                            engine.advance()
                        } label: {
                            Label("Next step (Space)  \(engine.stepsShown)/\(engine.current.steps.count + 1)", systemImage: "forward.frame")
                        }
                        .keyboardShortcut(.space, modifiers: [])
                        Button {
                            engine.showAll()
                        } label: {
                            Label("Show all (A)", systemImage: "list.bullet")
                        }
                        .keyboardShortcut("a", modifiers: [])
                    }
                    .controlSize(.large)
                } else if engine.watching {
                    Button {
                        engine.yourTurn()
                    } label: {
                        Label("Your turn (Return)", systemImage: "pencil")
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .controlSize(.large)
                    .tint(.orange)
                } else if let ok = engine.checked {
                    VStack(spacing: 8) {
                        Text(ok ? "✓ Correct!" : "✗ Not quite. Find the step where your work split off.")
                            .font(.system(size: 16 * k, weight: .bold))
                            .foregroundStyle(ok ? Color.green : Color.red)
                        Button {
                            engine.mark(gotIt: ok)
                        } label: {
                            Label("Next problem (Return)", systemImage: "arrow.right.circle.fill")
                        }
                        .keyboardShortcut(.return, modifiers: [])
                        .tint(ok ? Color.green : Color.red)
                    }
                    .controlSize(.large)
                } else {
                    HStack(spacing: 14) {
                        Button {
                            engine.mark(gotIt: true)
                        } label: {
                            Label("Got it (G)", systemImage: "checkmark.circle.fill")
                        }
                        .tint(.green)
                        .keyboardShortcut("g", modifiers: [])

                        Button {
                            engine.mark(gotIt: false)
                        } label: {
                            Label("Missed it (M)", systemImage: "xmark.circle.fill")
                        }
                        .tint(.red)
                        .keyboardShortcut("m", modifiers: [])
                    }
                    .controlSize(.large)
                }
            } else if engine.needsGuess {
                VStack(spacing: 10) {
                    Text("Step 0: which technique? (keys 1–\(engine.familyOptions.count))")
                        .font(.system(size: 15 * k, weight: .semibold))
                    HStack(spacing: 10) {
                        ForEach(Array(engine.familyOptions.enumerated()), id: \.offset) { i, f in
                            Button(f) { engine.guess(f) }
                                .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                        }
                    }
                    .controlSize(.large)
                }
                Spacer().frame(height: 200 * k)
            } else {
                if let g = engine.guessedFamily {
                    let right = family(engine.current.topic)
                    VStack(spacing: 4) {
                        Text(engine.guessedRight ? "✓ \(g). Right technique, now work it." : "✗ Not \(g). It's \(right).")
                            .font(.system(size: 15 * k, weight: .bold))
                            .foregroundStyle(engine.guessedRight ? Color.green : Color.red)
                        if !engine.guessedRight, let tell = familyTell[right] {
                            mathText("The tell: \(tell)", size: 13 * k)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                    }
                }
                Button {
                    engine.advance()
                } label: {
                    Label(engine.watching ? "Start the example (Space)" : "Reveal first step (Space)", systemImage: "eye")
                }
                .controlSize(.large)
                .keyboardShortcut(.space, modifiers: [])

                Spacer().frame(height: 220 * k)
            }
            }

            Spacer(minLength: 0)

            if !hideStats {
                Divider().padding(.horizontal, 40)
                VStack(spacing: 4) {
                    Text("All-time by topic")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(CalcTopic.allCases) { t in
                        HStack {
                            Text(t.rawValue).font(.caption2)
                            Spacer()
                            Text("\(engine.attempted[t] ?? 0) attempted · \(engine.missed[t] ?? 0) missed")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 30)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: 900)
        .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(minWidth: 560, minHeight: 560)
        .onAppear { Asker.shared.setContext("Calc problem", engine.current.askContext) }
        .onChange(of: engine.current.prompt) { _ in Asker.shared.setContext("Calc problem", engine.current.askContext) }
    }
}
