// French speaking practice, ported from the standalone Shadow French app (Nov 2026). Shown as Lock In → Practice → Speaking.
// Listen, record yourself, play back against the reference. Recordings live in ~/Library/Application Support/ShadowFrench.
import SwiftUI
import AppKit
import AVFoundation

struct Phrase {
    let fr: String
    let en: String
}

let mediaDeck: [Phrase] = [
    Phrase(fr: "Bien qu'il pleuve, je vais sortir.", en: "Although it's raining, I'm going out."),
    Phrase(fr: "Même si les Français sont hyper connectés, certains souffrent d'illectronisme.", en: "Even if the French are hyper-connected, some suffer from digital illiteracy."),
    Phrase(fr: "Je promène mes chiens pour me détendre.", en: "I walk my dogs to relax."),
    Phrase(fr: "Ça m'étonne qu'il fasse tellement beau aujourd'hui.", en: "It surprises me that it's so nice out today."),
    Phrase(fr: "Il faut que tu ailles au lit.", en: "You need to go to bed."),
    Phrase(fr: "Je ne vois rien.", en: "I don't see anything."),
    Phrase(fr: "La plupart des informations circulent vite sur les réseaux sociaux.", en: "Most information spreads fast on social media."),
    Phrase(fr: "Il faut vérifier les sources avant de partager un article.", en: "You have to check sources before sharing an article."),
    Phrase(fr: "Je lis les nouvelles sur mon téléphone entre mes cours.", en: "I read the news on my phone between classes."),
    Phrase(fr: "La liberté de la presse est essentielle pour la démocratie.", en: "Freedom of the press is essential for democracy."),
    Phrase(fr: "J'ai vu le film Ascenseur pour l'échafaud pour mon projet de culture.", en: "I watched the film Elevator to the Gallows for my culture project."),
    Phrase(fr: "Je fais confiance à mon conseiller académique.", en: "I trust my academic advisor."),
    Phrase(fr: "C'est difficile de faire confiance aux réseaux sociaux.", en: "It's hard to trust social media."),
    Phrase(fr: "Malgré la distance, on peut communiquer avec ses proches.", en: "Despite the distance, you can stay in touch with loved ones."),
    Phrase(fr: "La solidarité numérique reste quand même une nécessité.", en: "Digital solidarity remains a necessity nonetheless."),
    Phrase(fr: "Je préfère la rubrique économie du journal.", en: "I prefer the economy section of the newspaper."),
    Phrase(fr: "Je commence un nouveau travail bientôt.", en: "I'm starting a new job soon."),
    Phrase(fr: "Pourtant, ce n'est pas toujours évident de se repérer.", en: "Still, it's not always easy to find your way."),
    Phrase(fr: "Je dois rendre mes devoirs de français ce soir.", en: "I have to turn in my French homework tonight."),
    Phrase(fr: "J'adore apprendre de nouvelles choses.", en: "I love learning new things."),
]

let ch7Deck: [Phrase] = [
    Phrase(fr: "Si j'ai le temps, je viendrai à la soirée.", en: "If I have time, I'll come to the party. (si + présent → futur)"),
    Phrase(fr: "Si tu révises ce soir, tu réussiras l'examen.", en: "If you study tonight, you'll pass the exam. (si + présent → futur)"),
    Phrase(fr: "Si j'avais plus d'argent, je voyagerais en France.", en: "If I had more money, I'd travel to France. (si + imparfait → conditionnel)"),
    Phrase(fr: "Si elle parlait plus lentement, je la comprendrais.", en: "If she spoke more slowly, I'd understand her. (si + imparfait → conditionnel)"),
    Phrase(fr: "Si j'avais su, je serais venu.", en: "If I had known, I would have come. (si + plus-que-parfait → conditionnel passé)"),
    Phrase(fr: "Je viendrai à condition de finir mes devoirs.", en: "I'll come on the condition that I finish my homework. (à condition de + infinitif: same subject)"),
    Phrase(fr: "Je te prête mes notes à condition que tu me les rendes demain.", en: "I'll lend you my notes as long as you give them back tomorrow. (à condition que + subjonctif)"),
    Phrase(fr: "On peut sortir à condition qu'il ne pleuve pas.", en: "We can go out as long as it doesn't rain. (à condition que + subjonctif)"),
    Phrase(fr: "Dépêche-toi, sinon on va rater le métro.", en: "Hurry up, otherwise we'll miss the subway. (sinon + phrase)"),
    Phrase(fr: "Il faut réviser, sinon tu seras perdu à l'examen.", en: "You have to study, otherwise you'll be lost on the exam. (sinon + phrase)"),
    Phrase(fr: "Prends ton parapluie, sinon tu seras trempé.", en: "Take your umbrella, otherwise you'll get soaked. (sinon + phrase)"),
    Phrase(fr: "Même si c'est difficile, je continue.", en: "Even if it's hard, I keep going. (même si + indicatif)"),
    Phrase(fr: "Si on allait au cinéma ce soir ?", en: "How about going to the movies tonight? (si + imparfait = suggestion)"),
]

// Whole chunks to say without building them: reactions, and lines that buy time instead of going silent.
let repliesDeck: [Phrase] = [
    Phrase(fr: "Ah bon ?", en: "Really? (the all-purpose reaction)"),
    Phrase(fr: "Ah ouais, carrément.", en: "Oh yeah, totally."),
    Phrase(fr: "C'est vrai, ça.", en: "That's true."),
    Phrase(fr: "Je suis tout à fait d'accord.", en: "I completely agree."),
    Phrase(fr: "Pas vraiment, en fait.", en: "Not really, actually."),
    Phrase(fr: "Ça dépend.", en: "It depends. (then: ça dépend de…)"),
    Phrase(fr: "Moi aussi ! Moi non plus.", en: "Me too! / Me neither."),
    Phrase(fr: "Tu as raison.", en: "You're right."),
    Phrase(fr: "Ah, je vois.", en: "Ah, I see."),
    Phrase(fr: "C'est intéressant, ça.", en: "That's interesting."),
    Phrase(fr: "Je n'y avais jamais pensé.", en: "I'd never thought about that."),
    Phrase(fr: "Ça me fait penser à…", en: "That reminds me of…"),
    Phrase(fr: "Bonne question… laisse-moi réfléchir.", en: "Good question… let me think. (buys 3 seconds)"),
    Phrase(fr: "Euh, comment dire…", en: "Um, how do I put it… (stall in French, never in English)"),
    Phrase(fr: "Attends, je reformule.", en: "Wait, let me rephrase. (when a sentence falls apart, restart instead of freezing)"),
    Phrase(fr: "En fait, ce que je veux dire, c'est que…", en: "Actually, what I mean is…"),
    Phrase(fr: "Je ne sais pas trop, mais je pense que…", en: "I'm not too sure, but I think…"),
    Phrase(fr: "Comment on dit « deadline » en français ?", en: "How do you say \"deadline\" in French? (swap in any word you're missing)"),
    Phrase(fr: "Pardon, tu peux répéter plus lentement ?", en: "Sorry, can you repeat more slowly?"),
    Phrase(fr: "Du coup…", en: "So… (spoken connector to keep going)"),
    Phrase(fr: "Enfin bref, c'est ça.", en: "Anyway, that's it. (a clean way to finish)"),
]

// Frames where only the first verb is conjugated, and it's always the same form; the real verb stays in the infinitive.
let framesDeck: [Phrase] = [
    Phrase(fr: "Je vais réviser ce week-end.", en: "I'm going to study this weekend. (je vais + infinitif = future, no futur needed)"),
    Phrase(fr: "Je viens de finir mon devoir de modèles de décision.", en: "I just finished my decision models assignment. (je viens de + infinitif = just did, no passé composé needed)"),
    Phrase(fr: "Je suis en train de préparer un examen.", en: "I'm in the middle of preparing for an exam. (je suis en train de + infinitif = right now)"),
    Phrase(fr: "Je dois rendre un projet ce soir.", en: "I have to turn in a project tonight. (je dois + infinitif)"),
    Phrase(fr: "Je peux t'aider si tu veux.", en: "I can help you if you want. (je peux + infinitif)"),
    Phrase(fr: "J'aime bien écouter de la musique quand je travaille.", en: "I like listening to music when I work. (j'aime bien + infinitif)"),
    Phrase(fr: "J'ai l'habitude d'écouter du jazz pour me concentrer.", en: "I usually listen to jazz to focus. (j'ai l'habitude de + infinitif)"),
    Phrase(fr: "J'ai envie de sortir ce soir.", en: "I feel like going out tonight. (j'ai envie de + infinitif)"),
    Phrase(fr: "Je voudrais voyager en France un jour.", en: "I'd like to travel to France someday. (je voudrais + infinitif: a ready-made conditionnel)"),
    Phrase(fr: "Je compte travailler pendant les vacances.", en: "I plan to work over the break. (je compte + infinitif)"),
    Phrase(fr: "Il faut lire plusieurs sources.", en: "You have to read several sources. (il faut + infinitif: no subjonctif needed)"),
    Phrase(fr: "J'étudie l'économie et la philosophie à NYU.", en: "I study economics and philosophy at NYU."),
    Phrase(fr: "Ce que j'aime, c'est la musique.", en: "What I love is music. (ce que j'aime, c'est + anything)"),
    Phrase(fr: "Pour moi, le plus important, c'est de bien dormir.", en: "For me, the most important thing is sleeping well. (le plus important, c'est de + infinitif)"),
    Phrase(fr: "Je pense que c'est une bonne idée.", en: "I think it's a good idea. (je pense que c'est…: c'est never changes)"),
    Phrase(fr: "C'était super, il y avait beaucoup de monde.", en: "It was great, there were lots of people. (c'était / il y avait: past description, memorize as is)"),
    Phrase(fr: "J'ai trop aimé.", en: "I loved it. (fixed chunk for any film, song or event)"),
]

// Questions to throw back so the partner talks; built with intonation (tu fais quoi ?), no inversion.
let askBackDeck: [Phrase] = [
    Phrase(fr: "Et toi ?", en: "And you? (the fastest way to hand the conversation back)"),
    Phrase(fr: "Et toi, qu'est-ce que tu en penses ?", en: "And you, what do you think about it?"),
    Phrase(fr: "Pourquoi ?", en: "Why?"),
    Phrase(fr: "C'est-à-dire ?", en: "Meaning? / What do you mean?"),
    Phrase(fr: "Tu peux me donner un exemple ?", en: "Can you give me an example?"),
    Phrase(fr: "Tu préfères les films ou les séries ?", en: "Do you prefer movies or shows? (tu préfères… ou… ?)"),
    Phrase(fr: "Tu fais quoi ce week-end ?", en: "What are you doing this weekend?"),
    Phrase(fr: "Tu étudies quoi ?", en: "What do you study?"),
    Phrase(fr: "C'est quoi ton cours préféré ce semestre ?", en: "What's your favorite class this semester?"),
    Phrase(fr: "Ça va, tes cours ?", en: "How are your classes going?"),
    Phrase(fr: "Tu écoutes quel genre de musique ?", en: "What kind of music do you listen to?"),
    Phrase(fr: "Tu as vu un bon film récemment ?", en: "Have you seen a good movie lately?"),
    Phrase(fr: "C'était comment ?", en: "How was it?"),
    Phrase(fr: "Qu'est-ce qui t'a le plus plu ?", en: "What did you like most about it?"),
    Phrase(fr: "Tu t'informes comment, toi ?", en: "How do you keep up with the news?"),
    Phrase(fr: "Tu viens d'où ?", en: "Where are you from?"),
    Phrase(fr: "Tu as des projets pour les vacances ?", en: "Any plans for the break?"),
]

struct OralPrompt {
    let q: String
    let en: String
    let starter: String
    let starterEn: String
    let grammar: String
}

let oralPrompts: [OralPrompt] = [
    OralPrompt(q: "Quel rôle est-ce que les médias jouent dans ta vie quotidienne ?", en: "What role does media play in your daily life?", starter: "Alors, pour moi, les médias…", starterEn: "So, for me, media…", grammar: "Try: Je ne pense pas que + subjonctif"),
    OralPrompt(q: "Quels médias est-ce que tu consommes régulièrement ? Lesquels est-ce que tu évites ?", en: "What media do you consume regularly? Which ones do you avoid?", starter: "Honnêtement, je dirais que…", starterEn: "Honestly, I'd say that…", grammar: "Try: les médias que j'évite… / qui…"),
    OralPrompt(q: "Parmi tes deux explorations culturelles, quel média était le plus intéressant ? Pourquoi ?", en: "Of your two cultural explorations, which medium was the most interesting? Why?", starter: "C'est une bonne question…", starterEn: "That's a good question…", grammar: "Try: le film dont je parle… / la ville où…"),
    OralPrompt(q: "Est-ce que tu le recommanderais à tes amis ?", en: "Would you recommend it to your friends?", starter: "Oui, à condition que…", starterEn: "Yes, as long as…", grammar: "Try: à condition que + subjonctif · si + imparfait → conditionnel"),
    OralPrompt(q: "À ton avis, quels sont les avantages de la consommation médiatique ?", en: "In your opinion, what are the advantages of media consumption?", starter: "D'un côté…", starterEn: "On one hand…", grammar: "Try: il faut que + subjonctif"),
    OralPrompt(q: "Et les inconvénients ?", en: "And the disadvantages?", starter: "De l'autre côté…", starterEn: "On the other hand…", grammar: "Try: Si on passe trop de temps sur…, on…"),
    OralPrompt(q: "Est-ce que tu penses que l'IA va changer la façon dont on s'informe ?", en: "Do you think AI is going to change the way we get informed?", starter: "Ça dépend…", starterEn: "It depends…", grammar: "Try: si + présent → futur · sinon…"),
]

let followUps: [Phrase] = [
    Phrase(fr: "Qu'est-ce que tu veux dire par là ?", en: "What do you mean by that?"),
    Phrase(fr: "Tu peux me donner un exemple ?", en: "Can you give me an example?"),
    Phrase(fr: "Pourquoi est-ce que tu penses ça ?", en: "Why do you think that?"),
    Phrase(fr: "Ça m'étonne que tu dises ça. Pourquoi ?", en: "I'm surprised you say that. Why?"),
    Phrase(fr: "Et si tu devais choisir, lequel tu choisirais ?", en: "And if you had to choose, which one would you pick?"),
    Phrase(fr: "Est-ce que ça a changé depuis que tu es à NYU ?", en: "Has that changed since you've been at NYU?"),
    Phrase(fr: "Tu es sûr ? Moi, je ne suis pas tout à fait d'accord.", en: "Are you sure? I don't totally agree."),
    Phrase(fr: "Qu'est-ce que tu ferais si tu ne pouvais plus utiliser ton téléphone ?", en: "What would you do if you couldn't use your phone anymore?"),
]

enum ShadowMode: String, CaseIterable, Identifiable {
    case ch7 = "Ch. 7: si / à condition / sinon"
    case oral = "Oral eval: 60-sec drill"
    case media = "Media phrases"
    case replies = "Quick replies & stalling"
    case frames = "No-conjugation frames"
    case askBack = "Questions to ask back"
    var id: String { rawValue }
}

final class ShadowEngine: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    @Published var index = 0
    @Published var mode: ShadowMode = .ch7 {
        didSet { index = 0; showEnglish = false; hasRecording = false; stopTimer(); followUp = nil }
    }
    @Published var secondsLeft = 60
    @Published var timerRunning = false
    @Published var followUp: Phrase? = nil
    private var timer: Timer?
    @Published var showEnglish = false
    @Published var isRecording = false
    @Published var hasRecording = false
    @Published var isSpeaking = false
    @Published var isPlayingBack = false
    @Published var practicedCount: Int {
        didSet { UserDefaults.standard.set(practicedCount, forKey: "practicedCount") }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private let recordingURL: URL

    override init() {
        practicedCount = UserDefaults.standard.integer(forKey: "practicedCount")
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShadowFrench", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        recordingURL = dir.appendingPathComponent("last.m4a")
        super.init()
        synthesizer.delegate = self
    }

    var activeDeck: [Phrase] {
        switch mode {
        case .media: return mediaDeck
        case .replies: return repliesDeck
        case .frames: return framesDeck
        case .askBack: return askBackDeck
        default: return ch7Deck
        }
    }
    var count: Int { mode == .oral ? oralPrompts.count : activeDeck.count }
    var current: Phrase { activeDeck[min(index, activeDeck.count - 1)] }
    var prompt: OralPrompt { oralPrompts[min(index, oralPrompts.count - 1)] }

    func startTimer() {
        stopTimer()
        secondsLeft = 60
        timerRunning = true
        if !isRecording { toggleRecording() }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.secondsLeft > 0 { self.secondsLeft -= 1 }
            if self.secondsLeft == 0 {
                self.stopTimer()
                if self.isRecording { self.toggleRecording() }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerRunning = false
    }

    func newFollowUp() {
        followUp = followUps.randomElement()
        showEnglish = false
    }

    func speak(slow: Bool) {
        let utterance = AVSpeechUtterance(string: mode == .oral ? (followUp?.fr ?? prompt.q) : current.fr)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = slow ? 0.32 : 0.46
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }

    func toggleRecording() {
        if isRecording {
            recorder?.stop()
            isRecording = false
            hasRecording = true
            practicedCount += 1
        } else {
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            do {
                recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
                recorder?.delegate = self
                recorder?.record()
                isRecording = true
            } catch {
                print("Recording failed: \(error)")
            }
        }
    }

    func playRecording() {
        guard hasRecording else { return }
        do {
            player = try AVAudioPlayer(contentsOf: recordingURL)
            player?.delegate = self
            player?.play()
            isPlayingBack = true
        } catch {
            print("Playback failed: \(error)")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.isPlayingBack = false }
    }

    func next() {
        index = (index + 1) % count
        showEnglish = false
        hasRecording = false
        stopTimer(); secondsLeft = 60; followUp = nil
    }

    func previous() {
        index = (index - 1 + count) % count
        showEnglish = false
        hasRecording = false
        stopTimer(); secondsLeft = 60; followUp = nil
    }
}

struct ShadowPracticeView: View {
    @StateObject private var engine = ShadowEngine()

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Text("Shadowing — Français")
                    .font(.headline)
                Spacer()
                Text("\(engine.index + 1) / \(engine.count)")
                    .foregroundStyle(.secondary)
                Text("· \(engine.practicedCount) practiced")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            Picker("Mode", selection: $engine.mode) {
                ForEach(ShadowMode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 320)

            if engine.mode == .oral {
                VStack(spacing: 12) {
                    Text(engine.followUp?.fr ?? engine.prompt.q)
                        .font(.system(size: 22, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .frame(minHeight: 70)
                    Text(engine.followUp == nil ? "Start with: \(engine.prompt.starter)" : "Partner follow-up: answer it right away")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    if engine.showEnglish {
                        Text(engine.followUp.map { $0.en } ?? "\(engine.prompt.en)\nStarter: \(engine.prompt.starterEn)")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else {
                        Button("Show translation") { engine.showEnglish = true }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 13))
                    }
                    Text(engine.prompt.grammar)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                    Text("\(engine.secondsLeft)s")
                        .font(.system(size: 40, weight: .semibold, design: .monospaced))
                        .foregroundStyle(engine.timerRunning ? Color.red : Color.secondary)
                    HStack(spacing: 14) {
                        Button {
                            engine.startTimer()
                        } label: {
                            Label("Start 60s + record", systemImage: "timer")
                        }
                        .disabled(engine.timerRunning)
                        Button {
                            engine.newFollowUp()
                        } label: {
                            Label("Surprise follow-up", systemImage: "questionmark.bubble")
                        }
                    }
                    .controlSize(.large)
                    Text("No notes. No English, even for hesitations: euh… comment dire… attends, je réfléchis…")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            } else {
            VStack(spacing: 14) {
                Text(engine.current.fr)
                    .font(.system(size: 26, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 90)

                if engine.showEnglish {
                    Text(engine.current.en)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else {
                    Button("Show translation") { engine.showEnglish = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 13))
                }
            }
            .frame(maxWidth: .infinity)
            }

            HStack(spacing: 14) {
                Button {
                    engine.speak(slow: false)
                } label: {
                    Label("Listen", systemImage: "play.fill")
                }
                .disabled(engine.isSpeaking)

                Button {
                    engine.speak(slow: true)
                } label: {
                    Label("Listen slow", systemImage: "tortoise.fill")
                }
                .disabled(engine.isSpeaking)
            }
            .controlSize(.large)

            Divider().padding(.horizontal, 40)

            HStack(spacing: 14) {
                Button {
                    engine.toggleRecording()
                } label: {
                    Label(engine.isRecording ? "Stop" : "Record yourself", systemImage: engine.isRecording ? "stop.fill" : "mic.fill")
                }
                .tint(engine.isRecording ? .red : .accentColor)

                Button {
                    engine.playRecording()
                } label: {
                    Label("Play my recording", systemImage: "waveform")
                }
                .disabled(!engine.hasRecording || engine.isPlayingBack)
            }
            .controlSize(.large)

            Spacer()

            HStack {
                Button {
                    engine.previous()
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                Spacer()
                Button {
                    engine.next()
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: 640).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
