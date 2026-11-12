# Lock In

A macOS study app built around how students with ADHD actually study: it teaches before it quizzes, works in short rounds, and plans the day for you.

## What it does
- **Teach first.** New topics open with a 3–5 page lesson (idea, worked example revealed one step at a time, a quick check) before any questions.
- **Exam-aware spaced review.** Leitner boxes (1, 3, 7, 14, 30, 60 days). Decks for an assessment in the next 7 days jump to the front.
- **Step-by-step solutions and traps.** Every question can carry a worked solution and the one small mistake that usually trips you up.
- **Today's checklist.** After-class review blocks and due dates (optionally from a Brightspace calendar feed), with a sound and progress bar when you check things off.
- **Ask (⌘K).** A tutor panel that sees the card or lesson on screen and explains it step by step, using the local Claude Code CLI.
- **Practice generators.** Randomized calculus problems and decision-model problems with every step written out.

## Content
Decks and lessons are plain JSON in `banks/<course>/` and `lessons/<course>/`, loaded at launch. This repo ships one example deck (`banks/mfe/module0-foundations.json`: fractions, exponents, roots, logs). My course decks are kept private because they're built from class materials.

## Build
Requires macOS 13+ and Xcode.
```sh
./build.sh
```
The app reads its content from `~/School/Study Apps/LockIn` (see `appRoot` in `Sources/main.swift`).

Built with Swift and SwiftUI, with AI pair-programming help (Claude Code).
