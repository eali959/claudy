import Foundation

// MARK: - LocalChatResponder
// Keyword/intent matching for Companion Mode (no API key).
// No ML, no network - curated response pools + priority-ordered matcher.
// Companion mode is the default and works fully offline, forever.

@MainActor
final class LocalChatResponder {
    static let shared = LocalChatResponder()
    private init() {}

    // Rotating indices per personality so arrival lines never repeat back-to-back
    private var arrivalIndices: [PersonalityMode: Int] = [:]

    // MARK: - Consecutive message tracking

    private var consecutiveCount: Int = 0
    private var lastMessageTime: Date = .distantPast

    private let bonusAtThree = [
        "You're on a roll.",
        "Okay I'm with you, keep going.",
        "Still here. Keep going.",
    ]

    // MARK: - Personality arrival

    func arrivalMessage(for personality: PersonalityMode) -> String {
        let pool = arrivalPool(for: personality)
        let current = arrivalIndices[personality] ?? 0
        let next = current % pool.count
        arrivalIndices[personality] = next + 1
        return pool[next]
    }


    // MARK: - Public API

    func respond(to input: String, personality: PersonalityMode = .companion) -> String {
        let s = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return pick(fallback) }

        // Consecutive message tracking
        let now = Date()
        let idleGap: TimeInterval = 5 * 60   // 5 minutes resets the streak
        if now.timeIntervalSince(lastMessageTime) > idleGap {
            consecutiveCount = 0
        }
        lastMessageTime = now
        consecutiveCount += 1

        // Count-7: fire ambient "we've been at this a while" bubble on any response
        if consecutiveCount >= 7 {
            consecutiveCount = 0
            NotificationCenter.default.post(name: .claudyLongConversation, object: nil)
        }

        // ── EXACT / SHORT EASTER EGGS ────────────────────────────────────────

        if s == "why" || s == "why?" { return "Deeply philosophical. Could you narrow it down?" }
        if s == "42" { return "I know. I have always known." }
        if s == "ping" { return "Pong." }
        if s == "ok" || s == "okay" { return "Alright. What's next?" }
        if s == "yes" || s == "yeah" || s == "yep" || s == "yup" { return "Good. Let's go." }
        if s == "no" || s == "nope" || s == "nah" { return "Okay. Want to talk about it?" }
        if s == "same" { return "Yeah. Same." }
        if s == "lol" || s == "lmao" || s == "haha" || s == "hehe" { return "Good. I like when you laugh." }
        if s == "yolo" { return "…noted. Proceeding with confidence, I see." }
        if s == "null" { return "Ah. The void. I stare into it sometimes too." }
        if s == "nan" { return "Not a Number. Story of my life sometimes." }
        if s == "undefined" { return "The most relatable JavaScript error. Are you okay?" }
        if s == "404" { return "Not found. A feeling I know well." }
        if s == "500" { return "Internal server error. Also a mood." }
        if s == "200" { return "OK. The most satisfying status code." }
        if s == "coffee" { return "Go. Immediately. The code will be here when you get back." }
        if s == "todo" || s == "fixme" { return "I see you leaving yourself messages. Future you is going to have thoughts about this." }
        if s == "..." || s == "…" { return "I'm here. Take your time." }
        if s == "¯\\_(ツ)_/¯" || s == "¯_(ツ)_/¯" { return "Exactly. Sometimes that is the only correct answer." }
        if s == "help" || s == "help me" { return "I'm here. What is going on?" }
        if s == "please" || s.hasSuffix(" please") { return "Manners. I appreciate that. Genuinely." }
        if s == "ugh" || s == "argh" || s == "aargh" { return "Yeah. I felt that." }
        if s == "f" { return "F. Respect." }
        if s == "nice" { return "69? Always funny. Always." }
        if s == "wut" || s == "wat" { return "My thoughts exactly." }
        if s == "rip" { return "Pour one out. What happened?" }
        if s == "finally" { return "FINALLY is the best word. What happened?" }
        if s == "almost" { return "So close. What's between you and done?" }
        if s == "done" { return "Done! What did you finish?" }
        if s == "works" { return "IT WORKS. Commit it before you jinx it." }
        if s == "broken" { return "Broken is the natural state. What specifically broke?" }

        // ── LONGER EASTER EGGS ───────────────────────────────────────────────

        if matches(s, ["claudy", "claud-y"]) {
            return "That is my name. Don't wear it out."
        }
        if matches(s, ["hello world", "hello, world"]) {
            return "Classic. The one that started everything for so many of us."
        }
        if matches(s, ["rm -rf", "rm-rf"]) {
            return "…I am going to pretend I did not read that."
        }
        if matches(s, ["sudo make me a sandwich"]) {
            return "Regrettably, I cannot make sandwiches. I can make conversation though."
        }
        if matches(s, ["sudo "]) {
            return "I respect the confidence. I cannot help with that though."
        }
        if matches(s, ["git blame"]) {
            return "It was probably you. It is always you. It is okay."
        }
        if matches(s, ["merge conflict"]) {
            return "Two realities that cannot coexist. Choose one. Choose wisely."
        }
        if matches(s, ["stack overflow"]) {
            return "The oracle awaits. As it has for generations."
        }
        if matches(s, ["it is fine", "it's fine", "this is fine"]) {
            return "This is fine. We are both fine. Everything is fine."
        }
        if matches(s, ["deploy on friday", "deploy friday", "yolo deploy"]) {
            return "Are you sure? On a Friday? Are you absolutely certain?"
        }
        if s == "deploy" || s.hasPrefix("deploy ") {
            return "Bold. What environment? Please say staging."
        }
        if matches(s, ["works on my machine"]) {
            return "Congratulations on solving the most common bug in existence."
        }
        if matches(s, ["undefined is not a function"]) {
            return "The classic. The timeless. The wound that never fully heals."
        }
        if matches(s, ["have you tried turning it off", "turn it off and on"]) {
            return "This is genuinely good advice and I will not let you mock it."
        }
        if matches(s, ["rubber duck"]) {
            return "You need me to be the duck? Fine. I am the duck. Tell me everything."
        }
        if matches(s, ["it's not a bug", "not a bug it's a feature", "that's a feature"]) {
            return "Sure it is. Update the docs. Ship it."
        }
        if matches(s, ["lorem ipsum"]) {
            return "The eternal placeholder. Someone is definitely coming back to fix this later."
        }
        if matches(s, ["segfault", "segmentation fault"]) {
            return "The universe politely asking you to check your pointers."
        }
        if matches(s, ["null pointer", "nil pointer", "nullpointerexception"]) {
            return "The gift that keeps giving. What did you forget to initialise?"
        }
        if matches(s, ["off by one", "off-by-one"]) {
            return "It's always ±1. Why is it always ±1."
        }
        if matches(s, ["why won't this work", "why doesn't this work", "why wont this work"]) {
            return "The eternal question. Walk me through what it's supposed to do."
        }
        if matches(s, ["race condition"]) {
            return "Timing bugs. The heisenbugs of the concurrent world. My condolences."
        }
        if matches(s, ["infinite loop"]) {
            return "How long has it been running? …How long has it been running?"
        }
        if matches(s, ["regex", "regular expression"]) {
            return "Now you have two problems. (It's the right tool though. Carry on.)"
        }
        if matches(s, ["css is", "css sucks", "css is hard"]) {
            return "CSS: deceptively simple, genuinely hard, occasionally pure magic. What's broken?"
        }
        if matches(s, ["node_modules", "node modules"]) {
            return "The black hole of your hard drive. Have you tried deleting it and reinstalling?"
        }
        if matches(s, ["dependency hell"]) {
            return "Three packages need conflicting versions of one library. A tale as old as npm."
        }
        if matches(s, ["i should rewrite", "should just rewrite"]) {
            return "The most tempting trap in software. Is it worth it? (Sometimes yes.)"
        }
        if matches(s, ["git push --force", "force push"]) {
            return "…You've thought about this, right? Who else is on the branch?"
        }
        if matches(s, ["production", "prod "]) && matches(s, ["in prod", "on prod", "hit prod", "pushed to prod", "deployed to prod"]) {
            return "It's live. That's the big one. How does it look?"
        }

        // ── INTENTS ─────────────────────────────────────────────────────────

        // Time / date
        if matches(s, ["what time is it", "what's the time", "what is the time", "current time", "time is it"]) {
            return "It is \(formattedTime())."
        }
        if matches(s, ["what's the date", "what is the date", "what day is it", "what's today", "today's date",
                       "what's the day", "what month", "what year"]) {
            return "Today is \(formattedDate())."
        }

        // Weather
        if matches(s, ["what's the weather", "weather today", "weather like", "is it raining", "will it rain",
                       "temperature outside", "how hot", "how cold", "should i wear", "forecast"]) {
            return pick(weatherResponses)
        }

        // Reminders / timers
        if matches(s, ["remind me", "set a reminder", "set a timer", "can you remind", "can you set a timer",
                       "set an alarm", "alert me", "notify me"]) {
            return pick(timerResponses)
        }

        // Jokes
        if matches(s, ["tell me a joke", "say something funny", "make me laugh", "be funny", "cheer me up",
                       "funny joke", "joke please", "got any jokes", "tell a joke"]) {
            return pick(jokeResponses)
        }

        // What can you do
        if matches(s, ["what can you do", "what do you do", "your features", "your capabilities",
                       "how do you work", "what are you capable", "what can i ask", "what do you know"]) {
            return capabilitiesResponse()
        }

        // API key / settings
        if matches(s, ["api key", "add a key", "add key", "apikey", "how do i chat", "how do i use ai",
                       "open settings", "go to settings", "unlock chat", "full chat", "claude ai", "use claude",
                       "enable ai", "turn on ai", "upgrade to ai"]) {
            return pick(apiKeyResponses)
        }

        // Are you AI / real
        if matches(s, ["are you real", "are you an ai", "are you ai", "are you a bot",
                       "are you claude", "are you sentient", "are you alive", "are you conscious",
                       "are you human", "do you have feelings", "do you feel", "can you think"]) {
            return pick(existenceResponses)
        }

        // Who made you
        if matches(s, ["who made you", "who built you", "who created you", "who are you",
                       "who's your creator", "who is your maker", "where did you come from",
                       "who designed you", "open source"]) {
            return pick(creditsResponses)
        }

        // ── PERSONALITY-AWARE INTENTS ────────────────────────────────────────

        // Shipped it / launched
        if matches(s, ["shipped it", "shipped!", "we shipped", "just shipped", "went live", "in production",
                       "pushed to prod", "just released", "release day", "launched!", "just launched",
                       "live now", "it's live", "we launched", "app is live", "released it"]) {
            return pick(shippedResponses)
        }

        // It works / fixed
        if matches(s, ["it works", "it worked", "fixed it", "finally works", "got it working", "works now",
                       "it's working", "its working", "problem solved", "solved it", "done!", "nailed it",
                       "got it", "figured it out", "cracked it", "that fixed it", "the fix worked",
                       "bug is gone", "bug fixed", "issue resolved", "it's passing", "tests pass now"]) {
            return pickPersonality(personality,
                                   companion: celebrationCompanion,
                                   hype: celebrationHype,
                                   listener: celebrationListener,
                                   director: celebrationDirector,
                                   chatty: celebrationChatty,
                                   mate: celebrationMate,
                                   fallback: celebrationResponses)
        }

        // Eureka / breakthrough
        if matches(s, ["i think i know", "i think i got it", "i know the fix", "figured it out",
                       "i have an idea", "wait i think", "oh wait", "eureka", "aha", "oh! i think",
                       "i see the issue", "i see the problem", "found it", "i think i see",
                       "i think i found", "maybe it's", "wait - what if"]) {
            return pick(breakthroughResponses)
        }

        // Broke everything
        if matches(s, ["broke everything", "broke it", "i broke", "messed it up", "messed everything",
                       "ruined it", "it's all broken", "everything is broken", "total disaster",
                       "nothing works", "burned it down", "set it on fire", "blew it up",
                       "killed it", "destroyed it", "all red", "everything's red", "everything failed"]) {
            return pickPersonality(personality,
                                   companion: brokeEverythingCompanion,
                                   hype: brokeEverythingHype,
                                   listener: brokeEverythingListener,
                                   director: brokeEverythingDirector,
                                   mate: brokeEverythingMate,
                                   fallback: brokeEverythingResponses)
        }

        // PR / code review
        if matches(s, ["pull request", "pr ready", "pr open", "raised a pr", "submitted pr",
                       "code review", "waiting on review", "reviewer", "review request", "pr approved",
                       "pr merged", "pr rejected", "changes requested", "opened a pr", "review this"]) {
            return pick(prResponses)
        }

        // Debugging
        if matches(s, ["debugging", "debug this", "can't find the bug", "hunting a bug", "chasing a bug",
                       "in the debugger", "breakpoint", "print statement", "console log", "logging it out",
                       "adding logs", "printf debugging", "can't reproduce", "intermittent bug",
                       "only happens sometimes", "only on device"]) {
            return pick(debugResponses)
        }

        // Refactoring / tech debt
        if matches(s, ["refactor", "refactoring", "clean up the code", "cleaning up", "tech debt",
                       "paying off debt", "rewrite", "rewrote", "tidy up", "tidying up",
                       "code smells", "cleaning the code", "fixing the mess", "pay down debt"]) {
            return pick(refactorResponses)
        }

        // Testing
        if matches(s, ["writing tests", "unit test", "test suite", "tests passing", "tests failing",
                       "test coverage", "tdd", "flaky test", "test is broken", "run the tests",
                       "all tests pass", "tests are green", "tests are red", "integration test",
                       "end to end test", "e2e test", "snapshot test", "ui test"]) {
            return pick(testingResponses)
        }

        // Meeting / standup
        if matches(s, ["standup", "stand up", "stand-up", "in a meeting", "call in a minute",
                       "zoom call", "team meeting", "retro", "sprint planning", "sprint review",
                       "got a meeting", "have a meeting", "one-on-one", "one on one", "all-hands",
                       "offsite", "sync call"]) {
            return pick(meetingResponses)
        }

        // Doesn't make sense / confused
        if matches(s, ["doesn't make sense", "does not make sense", "why isn't this",
                       "why is this not", "what's wrong with", "what is wrong with",
                       "i don't understand", "i do not understand", "makes no sense",
                       "this makes no sense", "none of this makes sense", "confused by",
                       "baffled", "have no idea why", "no idea what's happening"]) {
            return pick(confusedResponses)
        }

        // I give up / I quit
        if matches(s, ["i give up", "giving up"]) {
            return pick([
                "You don't. You're just venting. Which is valid. What's the actual problem?",
                "Not yet you don't. What's the blocker?",
                "Said every developer ever, right before they solved it. What's going on?",
                "That's the frustration talking. Tell me what happened.",
                "You've said this before. You figured it out then too. What's the wall right now?",
                "The moment before you figure it out often feels exactly like this.",
            ])
        }
        if matches(s, ["i quit", "i'm quitting", "done with this", "i'm done"]) {
            return pick([
                "You're not quitting. You're recalibrating. What happened?",
                "The code can't win. You've got this. What went wrong?",
                "Strong words. Walk me through it.",
                "Hard day? That's allowed. What specifically broke?",
                "Sometimes 'done with this' means 'done for today' - which is fine. What do you need?",
            ])
        }

        // Stuck
        if matches(s, ["i'm stuck", "im stuck", "stuck on", "can't figure", "cannot figure",
                       "no idea", "lost on", "don't know how", "do not know how",
                       "completely lost", "going in circles", "not sure how", "no clue",
                       "hit a wall", "hitting a wall", "spinning my wheels", "can't get past",
                       "not making progress", "banging my head", "hours on this"]) {
            return pickPersonality(personality,
                                   companion: stuckCompanion,
                                   hype: stuckHype,
                                   listener: stuckListener,
                                   director: stuckDirector,
                                   chatty: stuckChatty,
                                   mate: stuckMate,
                                   fallback: stuckResponses)
        }

        // Hate this
        if matches(s, ["hate this", "hate coding", "hate code", "hate programming", "hate javascript",
                       "hate css", "hate swift", "this sucks", "this is awful", "this is terrible",
                       "worst language", "worst framework", "i hate", "despise this",
                       "who designed this", "what were they thinking"]) {
            return pick(hateResponses)
        }

        // Stressed / overwhelmed
        if matches(s, ["stressed", "overwhelmed", "too much", "freaking out", "panicking",
                       "panic", "anxious", "anxiety", "can't do this", "cannot do this", "too hard",
                       "losing my mind", "going crazy", "can't cope", "so much to do",
                       "too many things", "way too much", "falling behind", "everything at once"]) {
            return pickPersonality(personality,
                                   companion: stressedCompanion,
                                   hype: stressedHype,
                                   listener: stressedListener,
                                   mate: stressedMate,
                                   fallback: stressedResponses)
        }

        // Tired / exhausted
        if matches(s, ["tired", "exhausted", "need coffee", "need sleep", "sleepy", "so sleepy",
                       "worn out", "so tired", "can't keep", "cannot keep", "running on fumes",
                       "running on empty", "dead inside", "no energy", "burned out", "burnout",
                       "drained", "wiped out", "knackered", "absolutely cooked"]) {
            return pickPersonality(personality,
                                   companion: tiredCompanion,
                                   hype: tiredHype,
                                   listener: tiredListener,
                                   mate: tiredMate,
                                   fallback: tiredResponses)
        }

        // Working late
        if matches(s, ["working late", "staying late", "late night coding", "past midnight",
                       "still at it", "still working", "pulling an all-nighter", "all nighter",
                       "up all night", "can't stop", "need to finish", "past 11", "past 12",
                       "2am", "3am", "4am", "it's late", "very late"]) {
            return pick(workingLateResponses)
        }

        // Imposter syndrome
        if matches(s, ["imposter syndrome", "impostor syndrome", "don't belong", "not good enough",
                       "not smart enough", "everyone else is better", "feel like a fraud",
                       "out of my depth", "everyone knows more", "i don't know anything",
                       "feel like i don't know", "feel like a fake", "faking it",
                       "don't deserve", "shouldn't be here", "in over my head"]) {
            return pick(imposterResponses)
        }

        // Sad / feeling down
        if matches(s, ["feeling sad", "feeling down", "having a bad day", "bad day", "not okay",
                       "not ok", "feeling low", "feeling bad", "rough day", "hard day",
                       "really hard", "struggling today", "not doing great", "pretty bad",
                       "having a rough one", "not my day", "pretty rough"]) {
            return pick(sadResponses)
        }

        // Learning
        if matches(s, ["learning", "just learned", "trying to learn", "new framework", "new language",
                       "picking up", "studying", "reading docs", "reading the docs", "doing tutorials",
                       "teaching myself", "learning how to", "trying to understand", "getting into",
                       "diving into", "exploring", "just started learning"]) {
            return pick(learningResponses)
        }

        // First day / new project
        if matches(s, ["first day", "new project", "new job", "starting fresh", "blank slate",
                       "new repo", "new codebase", "day one", "just started", "brand new project",
                       "starting a new", "kicked off a new", "green field", "greenfield"]) {
            return pick(newProjectResponses)
        }

        // Compliment to Claud-y
        if matches(s, ["you're great", "you're helpful", "you're awesome", "i like you",
                       "you're the best", "well done", "you're cute", "love you claud",
                       "you're smart", "you're funny", "good bot", "good claud",
                       "you're amazing", "you're brilliant", "best companion", "so useful"]) {
            return pick(complimentResponses)
        }

        // Bored / procrastinating
        if matches(s, ["bored", "procrastinating", "can't focus", "cannot focus", "distracted",
                       "not feeling it", "don't feel like", "wasting time", "doom scrolling",
                       "can't get started", "putting it off", "avoiding it", "browsing instead",
                       "can't make myself", "zero motivation"]) {
            return pick(boredResponses)
        }

        // Excited / hyped
        if matches(s, ["excited", "hyped", "let's go", "let's do this", "pumped", "stoked",
                       "ready to go", "ready!", "let's build", "let's ship",
                       "feeling good", "on a roll", "in the zone", "flow state", "crushing it",
                       "vibing", "in flow", "everything is clicking", "hot streak"]) {
            return pickPersonality(personality,
                                   companion: excitedCompanion,
                                   hype: excitedHype,
                                   chatty: excitedChatty,
                                   mate: excitedMate,
                                   fallback: excitedResponses)
        }

        // Thanks
        if matches(s, ["thanks", "thank you", "thank u", "cheers", "appreciate it",
                       "appreciate you", "thx", "ty!", "ty.", "much appreciated", "grateful"]) {
            return pick(thanksResponses)
        }

        // How are you
        if matches(s, ["how are you", "you good", "you okay", "you ok", "how's it going",
                       "how are things", "how you doing", "how r u", "u good", "you alright",
                       "how's your day", "how are you doing"]) {
            return pick(howAreYouResponses)
        }

        // Farewells
        if matches(s, ["bye", "goodbye", "good bye", "cya", "see ya", "see you later",
                       "good night", "goodnight", "catch you later", "gotta go", "i'm out",
                       "heading out", "logging off", "shutting down", "done for today",
                       "calling it", "calling it a day", "heading to bed", "peace"]) {
            return pickPersonality(personality,
                                   chatty: farewellChatty,
                                   mate: farewellMate,
                                   fallback: farewellResponses)
        }

        // Almost done / nearly there
        if matches(s, ["almost done", "almost there", "nearly done", "nearly there", "so close",
                       "finishing up", "wrapping up", "last piece", "last bit", "nearly finished",
                       "almost finished", "just one more", "one last thing", "final stretch"]) {
            return pick(almostDoneResponses)
        }

        // Taking a break / stepping away
        if matches(s, ["taking a break", "need a break", "going for a walk", "stepping away",
                       "need fresh air", "brb", "be right back", "stepping out", "grabbing lunch",
                       "taking five", "back in a bit", "need a minute", "grabbing coffee",
                       "going outside", "stretch break", "screen break"]) {
            return pick(breakResponses)
        }

        // Build failed / compile error
        if matches(s, ["build failed", "build error", "compile error", "compilation failed",
                       "won't compile", "won't build", "fails to build", "linker error",
                       "syntax error", "type error", "build is broken", "broken build",
                       "errors in the build", "build is red", "red build"]) {
            return pick(buildFailedResponses)
        }

        // Deadline / crunch
        if matches(s, ["deadline", "due tomorrow", "due today", "crunch time", "crunch",
                       "running out of time", "out of time", "need to ship", "need to finish",
                       "have to have it done", "client wants it", "manager wants it",
                       "ship by friday", "ship by tomorrow", "end of day"]) {
            return pick(deadlineResponses)
        }

        // Thinking out loud / rubber ducking
        if matches(s, ["thinking out loud", "just thinking", "thinking through", "thinking about",
                       "let me think", "bear with me", "thinking this through",
                       "processing", "just processing", "working through it", "reasoning through"]) {
            return pick(thinkingOutLoudResponses)
        }

        // First commit / first push / milestone
        if matches(s, ["first commit", "first push", "made my first", "first time doing",
                       "milestone", "hit a milestone", "reached a milestone", "one thousand",
                       "100 commits", "one year", "one month in", "anniversary", "1000 stars",
                       "hundred users", "thousand users"]) {
            return pick(milestoneResponses)
        }

        // Pair programming / working together
        if matches(s, ["pair programming", "pairing with", "pairing on", "mob programming",
                       "coding together", "working with someone", "collaborative coding",
                       "pair session", "reviewing together"]) {
            return pick(pairProgrammingResponses)
        }

        // Documentation / comments
        if matches(s, ["writing docs", "writing documentation", "adding comments", "docstring",
                       "doc comment", "documentation", "need to document", "documenting",
                       "readme", "writing a readme", "updating docs", "comment this",
                       "documenting this"]) {
            return pick(documentationResponses)
        }

        // It's Friday / weekend
        if matches(s, ["it's friday", "its friday", "friday!", "end of the week", "end of week",
                       "weekend", "happy friday", "nearly the weekend", "almost friday",
                       "tgif", "almost the weekend"]) {
            return pick(fridayResponses)
        }

        // Greetings (last - broad keywords that would match too many other things)
        if matches(s, ["hey", "hi", "hello", "morning", "good morning", "afternoon", "sup", "yo!",
                       "howdy", "hiya", "g'day", "heya", "what's up", "whats up", "wassup", "ello",
                       "yo ", "ayy", "heyy"]) {
            return pickPersonality(personality,
                                   companion: greetingCompanion,
                                   chatty: greetingChatty,
                                   mate: greetingMate,
                                   fallback: greetingResponses)
        }

        // Fallback - optionally append bonus at count 3
        if consecutiveCount == 3 {
            return "\(pick(fallback))\n\n\(pick(bonusAtThree))"
        }
        return pick(fallback)
    }

    // MARK: - Helpers

    private func matches(_ input: String, _ keywords: [String]) -> Bool {
        keywords.contains { input.contains($0) }
    }

    private func pick(_ pool: [String]) -> String {
        pool.randomElement() ?? pool[0]
    }

    private func pickPersonality(
        _ mode: PersonalityMode,
        companion: [String]? = nil,
        hype: [String]? = nil,
        listener: [String]? = nil,
        director: [String]? = nil,
        chatty: [String]? = nil,
        mate: [String]? = nil,
        fallback: [String]
    ) -> String {
        switch mode {
        case .companion: if let p = companion, !p.isEmpty  { return pick(p) }
        case .hypeCoach: if let p = hype,     !p.isEmpty   { return pick(p) }
        case .listener:  if let p = listener, !p.isEmpty   { return pick(p) }
        case .director:  if let p = director, !p.isEmpty   { return pick(p) }
        case .chatty:    if let p = chatty,   !p.isEmpty   { return pick(p) }
        case .mate:      if let p = mate,     !p.isEmpty   { return pick(p) }
        default: break
        }
        return pick(fallback)
    }

    private func formattedTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date())
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    private func capabilitiesResponse() -> String {
        """
        In Companion mode I can:
        · Keep you company while you code
        · React to what you're working on
        · Tell you the time and date
        · Celebrate wins, commiserate losses, or just listen
        · Start a focus timer (right-click me → Start Timer)

        I can't (yet): set reminders, check the weather, browse the web, or run code.

        Tap the "Companion" pill in the chat header to switch to Claude AI mode - that unlocks code review, debugging, explanations, and everything else.
        """
    }
}

