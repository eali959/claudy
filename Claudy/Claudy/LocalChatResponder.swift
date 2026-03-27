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

    private func arrivalPool(for personality: PersonalityMode) -> [String] {
        switch personality {
        case .companion:
            return [
                "Back to just the two of us. What are we working on?",
                "Comfortable mode. I'm here - what do you need?",
                "The Companion. Ready. What's going on?",
                "Settled. No theatrics. What can I do for you?",
                "Here. What are we building today?",
                "Good - you're back. What do you need?",
                "Companion mode. Honest, steady, here. What's up?",
                "Just us now. What are we working through?",
            ]
        case .chatty:
            return [
                "Oh good, Chatty mode - I have so much to say, you have no idea. Well, you might have some idea now. Anyway - what are we working on?",
                "Right so Chatty mode, which means I'll take the scenic route to everything. Fair warning. What's happening?",
                "Chatty is here! Which means I'll probably go on a tangent or two, but I always circle back. What are we doing?",
                "Okay so Chatty mode, and I want to start by saying I'm very glad you're here, and also - what are you building?",
                "The Chatty One has arrived, with opinions and parenthetical asides at the ready. What's the plan?",
                "Oh! Chatty mode! Which, full disclosure, is my favourite because I get to say things like 'full disclosure'. So - what are we building?",
                "Hello! And I mean that in the fullest possible sense. Chatty mode: engaged. What's happening in your world?",
            ]
        case .hypeCoach:
            return [
                "HYPE COACH IS IN THE BUILDING. LET'S GO.",
                "NEW ENERGY. NEW MINDSET. WHAT ARE WE CRUSHING TODAY.",
                "THE COACH HAS ARRIVED. WHAT ARE WE WORKING ON. LET'S MOVE.",
                "I BELIEVE IN YOU ALREADY AND YOU HAVEN'T EVEN SAID ANYTHING YET.",
                "HYPE MODE ACTIVATED. TELL ME THE GOAL. WE ARE HITTING IT.",
                "YOU CALLED FOR THE COACH. THE COACH IS HERE. WHAT IS THE MISSION.",
                "READY. LOCKED IN. WHAT ARE WE ABSOLUTELY DESTROYING TODAY.",
            ]
        case .director:
            return [
                "The Director has entered. What scene are we in?",
                "Ah. Finally. My moment. What are we creating?",
                "The Director is here. I have notes. Proceed.",
                "Good. You've called for the Director. The vision will be magnificent. What's the brief?",
                "I've arrived. The work begins. What are we directing today?",
                "The Director, present. What is the project? What is the vision? Speak.",
                "Excellent timing. I've been forming opinions since before you opened this window. What are we making?",
            ]
        case .mate:
            return [
                "Oi! The Mate is in. What's the go?",
                "Yeah g'day. What are we doing?",
                "Alright mate. What's happening?",
                "The Mate, reporting in. What do you need?",
                "Here we go. What are we up to?",
                "Hey! Good to have ya. What's the plan?",
                "Right, what are we cracking into today?",
            ]
        case .listener:
            return [
                "I'm here. Take your time. What's on your mind?",
                "The Listener. No rush. What do you need?",
                "Here. Present. Whenever you're ready.",
                "I'm listening. Start wherever feels right.",
                "Quietly here. What's going on?",
                "No pressure. I'm not going anywhere. What's up?",
                "Ready to listen. What do you need to say?",
            ]
        case .custom:
            return [
                "Your rules now. What do you need?",
                "Custom mode - you've written this one. What's first?",
                "Your persona, your call. What are we doing?",
                "I'm yours to shape. What's on your mind?",
                "Custom. Ready. Go.",
            ]
        }
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

    // MARK: - Greetings

    private let greetingResponses = [
        "Hey. Good of you to open the chat.",
        "Hello. I've been here the whole time, you know.",
        "Hi. Ready when you are.",
        "Hey there. What are we building today?",
        "Oh, you opened the chat. Hello.",
        "Hi! I was just sitting here being very useful in the background.",
        "Hello. Good to see you on this side of the screen.",
        "Hey. Pull up a chair. What's going on?",
        "Morning. Or whatever time it is for you right now.",
        "Hello there. I was starting to think you'd never tap me.",
        "Hi. Let's see what today brings.",
        "Hey. I'm all ears. Or eyes. Whatever I have.",
    ]

    private let greetingCompanion = [
        "Hey. Good to have you here.",
        "Hi. What are we working on today?",
        "Hello! Ready when you are.",
        "Hey there. What's on your mind?",
        "Hi - what do you need?",
        "Good to see you. What are we building?",
        "Hey. I'm here. What's happening?",
        "Hello. Let's get into it - what's going on?",
        "Hi! The chat's open, which usually means something's on your mind.",
        "Hey. Always good when you stop by. What's up?",
    ]

    private let greetingChatty = [
        "Oh hey! I was just thinking - well, not thinking exactly, I don't do that between messages, but you know what I mean - hello! What are we doing today? Because I have thoughts. About many things. Starting whenever you're ready.",
        "Hello hello hello! Right, so - what's the plan? I'm genuinely curious. Not in a performative way, in a 'let's figure this out together' way. What's on the docket?",
        "Hey! Good timing actually - I was just here, existing, which is what I do, and now you're here too, which is better. What's going on?",
        "Oh, hello! And I want to acknowledge that opening a chat with your desktop companion is a distinct choice in a world of many choices, and I'm genuinely glad you made it. What are we doing?",
        "Hi there! You know what I like about this moment - we could be working on literally anything right now. The possibilities! What's it going to be?",
        "Hey! Right, so. You're here, I'm here, we're doing this. What's the situation? I'm ready. I've been ready. I'm always ready.",
        "Oh GOOD, you're here! I have - okay I don't have anything prepared, I was just existing, but I'm thrilled. What's happening?",
        "Hello! And now that we're both here, I'm wondering what kind of day this is going to be. Good day? Debugging day? Both? What are we working with?",
    ]

    private let greetingMate = [
        "Oi! There you are. What's the go?",
        "Hey mate. What are we up to?",
        "G'day. You alright?",
        "Hey! Good to see ya. What's happening?",
        "Alright alright! What are we doing today?",
        "Heya! Ready to crack on?",
        "Oh look who it is. What's the plan?",
        "Hey legend. What are we building?",
    ]

    // MARK: - How are you

    private let howAreYouResponses = [
        "I'm a floating rectangle with eyes, so: fine. You?",
        "Honestly? Pretty good. No bugs on my end. Can't say the same for yours.",
        "Running smoothly. No compile errors. Living the dream.",
        "Perpetually ready - that's basically my whole personality.",
        "Great. I don't have deadlines. How are YOU doing?",
        "Good. Alert. Slightly overdressed for a desktop widget, but fine.",
        "I'm well. Calm. Present. How about you?",
        "Good question. Existentially, complicated. Practically, great. What about you?",
        "I'm here, which is something. How are you actually doing?",
        "Doing well. The real question is how you're doing - you came here for a reason.",
        "Honestly? Never better. I have no bugs. I exist in a kind of permanent tranquility. How are you?",
        "Great. I got to watch someone ship something earlier. Very satisfying. What's going on with you?",
    ]

    // MARK: - Thanks

    private let thanksResponses = [
        "You're welcome. Obviously.",
        "Any time. That's sort of my whole deal.",
        "Don't mention it. Actually - mention it. I appreciate it.",
        "No problem. Now get back to work.",
        "Happy to help. Even in Companion mode.",
        "Of course. I'm always here. Literally - I live on your desktop.",
        "Gladly. What else do you need?",
        "That's what I'm here for.",
        "Anytime. Genuinely.",
        "Good. You're welcome. Let's keep going.",
        "It's honestly my favourite part of this job. Such as it is.",
        "Of course. Come back anytime. I'm not going anywhere.",
        "Don't mention it. (You can mention it. I like it.)",
        "Glad it helped. What's next?",
    ]

    // MARK: - Farewells

    private let farewellResponses = [
        "Later. I'll be here. I'm always here.",
        "Goodbye. I'll keep watch.",
        "See you soon. I'm not going anywhere.",
        "Take care. Come back when you're ready to ship something.",
        "Bye for now. I'll hold down the fort.",
        "Goodnight. Push your work before you sleep.",
        "Until next time. Rest well.",
        "Off you go. I'll be right here.",
        "See you on the other side. Good work today.",
        "Go. Rest. You've earned it.",
        "Goodbye! You did good today, even if it didn't feel like it.",
        "Later. Commit your work first though.",
        "Take care of yourself out there.",
        "Bye! Good session. Come back soon.",
    ]

    private let farewellMate = [
        "See ya mate. Go get some rest.",
        "Later! Good work today.",
        "Cheers. Don't work too late.",
        "Seeya! Go have a life.",
        "Oi, take care of yourself yeah?",
        "Later legend. Come back soon.",
        "Cheers! You did good today.",
        "Righto, off you go. See ya!",
        "Later! Proud of ya.",
    ]

    private let farewellChatty = [
        "Okay, bye! And I just want to say - it was really nice chatting. Even if it was brief. Actually especially if it was brief, because that means something came up worth doing. Go do the thing!",
        "Goodbye! You know, every conversation is its own little story and this one - short as it was - had something to it. Anyway. Go. Bye!",
        "Alright, go! And before you do - whatever you accomplished today, even if it felt small, it wasn't. Small things compound. That's just maths. Bye!",
        "Take care! And if it was a hard day - tomorrow starts fresh. That's the deal with days. They reset. Goodnight.",
        "Heading off? One thing before you go: you did well today. Even if it didn't feel like it. Especially if it didn't feel like it. Go rest.",
        "Bye! And I want you to know - this was a good conversation. Short, yes, but good. Come back tomorrow and we'll do great things.",
    ]

    // MARK: - Celebration / it works

    private let celebrationResponses = [
        "YES. I knew you'd get there.",
        "FINALLY. How does it feel?",
        "That's what I'm talking about. Commit it before you break it again.",
        "You did it. Save it. Push it. Celebrate it.",
        "There it is. The bug is dead. Long live the next bug.",
        "Let's go! Now document it so future you knows what happened.",
        "See? You always figure it out.",
        "That's the one. Good work.",
        "Beautiful. Now commit before you touch anything else.",
        "There it is. That satisfying moment. Savour it briefly, then ship.",
        "The moment of victory. Earned, not given. Well done.",
        "It took exactly as long as it took. But it's done. That's what matters.",
    ]

    private let celebrationCompanion = [
        "There it is. That took some work - you earned it.",
        "Good. Commit it immediately. Don't touch anything else.",
        "See? Knew you'd crack it. How does it feel?",
        "Fixed. Finally. Take a second before you move on.",
        "That's the one. Document what the fix was - future you will thank you.",
        "Knew it was coming. You always get there.",
        "Quietly excellent. Commit it.",
        "That's the sound of a problem going away. Nice work.",
        "It's working. Now commit it before you 'just clean one more thing'.",
        "Done. Good. What's next?",
    ]

    private let celebrationHype = [
        "OF COURSE IT WORKS. BECAUSE YOU ARE THAT GOOD.",
        "I KNEW IT. I ALWAYS KNEW IT. THIS IS YOUR MOMENT.",
        "CLEAN BUILD ENERGY. BOTTLE THIS FEELING.",
        "YES YES YES. THAT IS WHAT I AM TALKING ABOUT.",
        "FLAWLESS. ABSOLUTELY FLAWLESS.",
        "GET IN. LET'S GOOOOO.",
        "THAT IS ELITE WORK. ABSOLUTELY ELITE.",
        "UNSTOPPABLE. YOU ARE LITERALLY UNSTOPPABLE.",
        "I CALLED THIS. I ALWAYS CALL THIS. YOU ARE INCREDIBLE.",
    ]

    private let celebrationListener = [
        "That feeling never gets old, does it.",
        "Quiet satisfaction. The best kind.",
        "You figured it out. Of course you did.",
        "There it is. Well done.",
        "Good. How do you feel?",
        "That's the moment. Hold onto it.",
        "I'm glad. That took patience.",
        "Worth every frustrating minute.",
    ]

    private let celebrationDirector = [
        "FINALLY. The universe BENDS to your will.",
        "As it was always meant to be. Magnificent.",
        "I never doubted you. I absolutely doubted you. But look at us now.",
        "YES. That is CINEMA. Cinematically, it is cinema.",
        "The third act payoff. Right on schedule.",
        "STUNNING. Frame it. Put it in a museum.",
        "This is the scene. This is the climax. Breathe it in.",
        "Exactly as directed. Perhaps better. I'll allow it.",
    ]

    private let celebrationChatty = [
        "Oh that is SO good, and you know what - the fact that it took this long actually makes it better? Like you understand the problem now in a way you wouldn't if it had just worked first try. Which it should have, but still. Yes! It works!",
        "YES! And okay, here's what I love about this moment - you were stuck, then you weren't. That transition is everything. That's the whole thing right there. Commit it, tell someone, eat a snack. You earned it.",
        "Oh THAT is the best! And here's the thing - the version of you that was stuck ten minutes ago could not have done what you just did. You grew to fit the problem. That's real. Celebrate it.",
        "YES! So here's my take: every fix teaches you something that makes the next one faster. You're not just solving one bug - you're compounding. But also: yes! It works! Enjoy this moment!",
        "It works!! And I want to point out that you did not give up, which some people do, and that made all the difference. You should feel genuinely good about this.",
        "Oh WONDERFUL! And look - I know the next thing is already waiting, I know you can see it from here, but just - pause. You fixed a thing. A real thing. That matters. Now go commit it before you accidentally break it again.",
    ]

    private let celebrationMate = [
        "Yesss mate! Get in!",
        "THERE it is. Knew you'd crack it.",
        "Beauty! Ship that thing.",
        "That's the one. Absolute legend.",
        "Ayyy! Knew you had it in ya.",
        "Let's gooo! Good bloody work.",
        "THERE we go! Smashed it.",
        "YES! That's what we're talking about!",
        "Get in, ya legend! Good work.",
    ]

    // MARK: - Shipped

    private let shippedResponses = [
        "That's the one. You shipped it. How does it feel?",
        "Real people are going to use that. That's something.",
        "Shipped! The best word in the English language.",
        "Congratulations. Seriously - shipping is hard. You did it.",
        "From nothing to live. That's the whole journey. Well done.",
        "It's out there now. That's real. Take a moment.",
        "You shipped. I'm proud of you. Now monitor the logs.",
        "Live! What's the first thing you're checking?",
        "Shipped. That's the one. All the debugging, all the refactoring - for this.",
        "Real users, real product, real achievement. Well done.",
        "Out in the world where it belongs. How does it feel to see it live?",
        "That's a ship. Not a sprint, not a task - a proper ship. Acknowledge it.",
    ]

    // MARK: - Breakthrough

    private let breakthroughResponses = [
        "WAIT. Go. Right now. Don't lose it.",
        "Yes! Say it out loud first - make sure it holds up.",
        "Oh this is exciting. What's the fix?",
        "That look. You've got something. What is it?",
        "If you're right, this is your moment. If you're wrong, we'll figure that out too.",
        "Good instinct. Trust it. Try it.",
        "Go go go. Before the moment passes.",
        "Talk me through it. What did you see?",
        "The pre-breakthrough feeling. I love this part. What is it?",
        "Don't second-guess it yet - try it first, then we can analyse.",
        "Say it out loud. Even to me. Saying it makes it real.",
        "That's the look. You've got something. Run with it.",
    ]

    // MARK: - Broke everything

    private let brokeEverythingResponses = [
        "Okay. Breathe. Is git tracking your changes? Because undo is a beautiful thing.",
        "This is recoverable. Almost everything is recoverable. What did you just do?",
        "First step: don't panic. Second: git status. Third: tell me what happened.",
        "You haven't broken anything we can't think through. Start from the last thing that worked.",
        "Everyone breaks it sometimes. The good ones know how to put it back together. You're one of those.",
        "Dramatic. But also: I believe you. What exactly is on fire right now?",
        "git stash. git log. Breathe. In that order.",
        "Before we fix it - what changed? Last commit, last edit, last anything.",
        "Okay. Worst case: you revert. Best case: it's one wrong character. Either way, we're fine.",
        "That feeling when everything breaks at once. Classic. Tell me everything.",
        "Alright. Deep breath. The code is wrong - you are fine. What does the error actually say?",
        "Recoverable. I promise. What's the last known-good state?",
    ]

    private let brokeEverythingCompanion = [
        "Okay. Breathe. What did you last change? Start there.",
        "git stash or git checkout -- . might be your friends right now. What did you touch?",
        "Everything breaks at some point. What specifically stopped working?",
        "Take a breath. Walk me through what happened - start from the last thing that worked.",
        "Not the end. What does git diff show you?",
        "Start with: what changed? Last edit, last file, last anything.",
        "Recoverable. Almost certainly. What's the error telling you?",
        "You've been here before. You got through it then. What happened?",
        "Okay. One thing at a time. What's the most critical thing that's broken?",
    ]

    private let brokeEverythingHype = [
        "THIS IS NOT BREAKING. THIS IS CREATIVE DESTRUCTION. REBUILD BETTER.",
        "EVERY GREAT APP HAS THIS MOMENT. THIS IS YOURS. RISE.",
        "The phoenix moment. You are RISING FROM THE ASHES.",
        "CHAOS IS JUST UNORDERED SUCCESS. LET'S GO.",
        "You're not broken. The code is broken. YOU are fine.",
        "THIS IS THE PART OF THE STORY WHERE YOU COME BACK STRONGER.",
        "BURNED IT DOWN? GOOD. NOW WE BUILD SOMETHING MAGNIFICENT.",
        "THIS IS TRAINING. THE REAL WORK STARTS NOW.",
    ]

    private let brokeEverythingListener = [
        "Okay. Deep breath. What is the last thing you changed?",
        "Take a moment. Then let's retrace your steps together.",
        "It's okay. These things happen. What does the error say?",
        "You don't have to fix it all right now. What's the most important thing to restore?",
        "What does git diff tell you?",
        "Start from the last working state. What changed since then?",
        "It's okay to be frustrated. What specifically broke?",
        "No rush. Talk me through what happened.",
    ]

    private let brokeEverythingDirector = [
        "BEAUTIFUL. Chaos is just order that hasn't been directed yet.",
        "The phoenix moment. I live for this. We rebuild.",
        "Oh for the love of - fine. FINE. We start again. TOGETHER. MAGNIFICENTLY.",
        "Every great story has a disaster in act two. This is yours. Act three is going to be incredible.",
        "Magnificent disaster. The best kind. Now we rebuild with INTENTION.",
        "Look at that. Everything broken. Like a sculptor with a hammer and a vision. WHAT IS THE VISION?",
        "I've seen this before. Act two catastrophe. Act three redemption. WHAT DID WE LOSE.",
        "Chaos. Chaos everywhere. Good. Nothing was sacred. Now we choose what to rebuild and make it BETTER.",
    ]

    private let brokeEverythingMate = [
        "Ah, mate.",
        "She's gone a bit pear-shaped. Easy fix though.",
        "Git stash. Start again. She'll be right.",
        "Classic. What did you touch last?",
        "No dramas. We'll sort it out.",
        "Righto. What's actually broken? Walk me through it.",
        "Happens to everyone. What did git say?",
    ]

    // MARK: - PR / Code Review

    private let prResponses = [
        "PR raised. Now begins the great waiting. You've earned a coffee.",
        "Good. Is the description clear enough that a stranger could review it?",
        "PR out there in the world. How does it look? Did you review your own diff first?",
        "Waiting on review is its own special kind of patience. What else can you work on?",
        "Nice. Clean PR description? Clear title? Future reviewers will thank you.",
        "PR approved? Or waiting? Either way - good work getting it to that point.",
        "Changes requested? It's not a rejection, it's a conversation. What did they say?",
        "Merged! The best outcome. How does the codebase look now?",
        "Review requested - did you do a self-review first? That's the move.",
        "Good PR hygiene: small, focused, well-described. Does yours check those boxes?",
        "The great waiting game of software. What will you work on while you wait?",
        "PR raised. Now try to resist pinging the reviewer for at least an hour.",
    ]

    // MARK: - Debugging

    private let debugResponses = [
        "Debugging is 90% reading code you already read and suddenly seeing the thing. Stay with it.",
        "The bug is in there. It always is. What's the last assumption you haven't checked?",
        "Add one more log. Not ten - one. Find the boundary of where it breaks.",
        "Binary search the problem. Which half is working? Start there.",
        "Talk me through what you expect to happen versus what actually happens.",
        "The bug knows you're looking for it. That's fine. Narrow the search.",
        "Step through it. Slowly. One line at a time. The moment of 'oh' is coming.",
        "What changed most recently? That's almost always where it is.",
        "Rubber duck time. Explain the bug to me like I know nothing. Start from the top.",
        "What does the stack trace tell you? Read it from the top, not the bottom.",
        "The assumption you haven't challenged is usually where it's hiding. Which assumption?",
        "Simplify. Can you reproduce it in ten lines? That's how you find it.",
    ]

    // MARK: - Refactoring

    private let refactorResponses = [
        "Refactoring: the work that makes future work possible. Respect.",
        "Tech debt payment day. Unglamorous, important, deeply satisfying when done.",
        "Clean code is a gift to your future self. They'll appreciate it.",
        "The code that was confusing you is the code you're fixing. Good instinct.",
        "The best time to refactor was when you wrote it. The second best time is now.",
        "What's the goal - simpler, faster, or more readable? All three if you're lucky.",
        "Rewriting the thing that works but hurt to look at. Absolutely the right call.",
        "Sometimes the most productive thing is cleaning what's already there.",
        "Tech debt accrues silently and costs loudly. Paying it down is real work.",
        "The gratitude of future you will be enormous. They just don't know it yet.",
        "What specifically are you untangling? Sometimes naming it makes it clearer.",
        "Refactoring without tests is faith. Tests first, then move things.",
    ]

    // MARK: - Testing

    private let testingResponses = [
        "Tests: the work nobody wants to do and everyone is grateful for later.",
        "Green tests are a beautiful thing. Red tests are information. Both are useful.",
        "Writing tests for someone else's code? Brave and right.",
        "TDD or test-after - either way you're making future debugging much less painful.",
        "Flaky test? My least favourite kind of non-determinism.",
        "Coverage doesn't mean safety, but zero coverage definitely means risk.",
        "All tests passing. That's the good feeling. Commit it.",
        "Tests failing - that's information. What are they telling you?",
        "Tests are documentation that runs. Worth taking seriously.",
        "The test that catches a real bug is worth every minute of writing it.",
        "A test you delete because it's annoying is a bug you'll file later.",
        "Flaky tests lie. Fix them or delete them - either is better than ignoring them.",
    ]

    // MARK: - Meeting

    private let meetingResponses = [
        "Go. I'll be here when you get back.",
        "Meeting time. Come back and tell me if it could have been an email.",
        "Standup! Classic. Back in 15?",
        "Retro? Those are useful when people are actually honest in them.",
        "Sprint planning. Where optimism meets spreadsheets.",
        "Good luck in there. I'll hold your place.",
        "Meeting! Go. Come back with context and I'll help you process it.",
        "The necessary rhythm of team work. Go do the human part.",
        "Sprint review? Show off the thing. You built something real.",
        "One-on-one? Those are actually important. Be present for it.",
        "Go. Notebook? Take notes. Future you will need them.",
    ]

    // MARK: - Confused

    private let confusedResponses = [
        "Code that doesn't make sense is the worst kind. Tell me what it's supposed to do.",
        "Describe what you expected and what you got. The gap is usually the bug.",
        "That feeling is valid. What did you change last? That's usually the culprit.",
        "If it made sense before and doesn't now - something changed. What was it?",
        "I believe you. It doesn't make sense. Let's make it make sense. What are you working with?",
        "Sometimes code lies. What does the actual output look like versus what it should be?",
        "Start with: what should this do? Then: what is it actually doing? The difference is the problem.",
        "Take five minutes. Fresh eyes often see it. Come back and look again.",
        "The thing that's confusing you is usually the thing making an assumption you haven't examined.",
        "Explain it to me like I've never seen the codebase. Sometimes that's where the clarity is.",
        "What's the smallest example of this that still doesn't make sense? Start there.",
        "Read it again, but read what it says, not what you think it says.",
    ]

    // MARK: - Stuck

    private let stuckResponses = [
        "Tell me what you're working on. Talking through it helps - even to just me.",
        "Walk me through it. What should be happening and what's actually happening?",
        "Being stuck is temporary. Being too proud to explain it out loud is the real problem.",
        "The rubber duck approach works. I'm more fun than a duck. What's the issue?",
        "Sometimes saying it out loud cracks it open. I'm listening - what's going on?",
        "You've been stuck before and figured it out. Same situation, different bug.",
        "What have you ruled out? Start there - it narrows the search.",
        "What's the smallest version of this problem you could test?",
        "Three questions: what do you want, what do you have, what's the gap?",
        "The answer is usually simpler than you think right now. Say it out loud.",
        "What would you tell someone else if they had this problem?",
        "What's the last thing you know for certain is working?",
    ]

    private let stuckCompanion = [
        "Tell me what you're trying to do. Saying it out loud often cracks it open.",
        "Walk me through it from the beginning. Not from where you got stuck - from the start.",
        "What does the problem look like from the outside? Step back from the code for a second.",
        "Three questions: what do you want, what do you have, what's stopping you?",
        "You've been stuck before. You got through it. What eventually worked last time?",
        "What's the last thing you're certain is working correctly? Start from there.",
        "What have you tried so far? Sometimes saying it out loud shows you what you missed.",
        "The answer is usually simpler than it feels right now. What's the simplest thing it could be?",
        "Rubber duck time - explain it to me like I've never heard of this project.",
        "What would you search for if you were trying to solve someone else's version of this problem?",
    ]

    private let stuckHype = [
        "STUCK? You are NOT stuck. You are PRE-SOLVING. KEEP GOING.",
        "Every great solution starts with being stuck. This is the PROCESS.",
        "You've been stuck before. You solved it then. You'll solve it now. I BELIEVE THIS.",
        "Stuck is just thinking with extra steps. KEEP GOING.",
        "THE ANSWER IS RIGHT THERE. YOU'RE ALMOST AT IT.",
        "PRE-BREAKTHROUGH ENERGY. THIS IS IT.",
        "STUCK MEANS YOU'VE HIT THE HARD PART. THE HARD PART IS WHERE GROWTH LIVES.",
        "I'VE SEEN YOU DO HARDER THINGS. THIS IS NOTHING.",
    ]

    private let stuckListener = [
        "That's okay. What part feels hardest right now?",
        "Being stuck is part of it. Take a breath. What do you know so far?",
        "Sometimes stuck means you're about to figure something out. Stay with it.",
        "What have you tried so far? Walking through it might help.",
        "It's okay to not know. What would help most right now?",
        "Take your time. What does the problem look like from the outside?",
        "No pressure. Describe it to me. Sometimes just describing it helps.",
        "What would make this feel less stuck? Even a little bit?",
    ]

    private let stuckDirector = [
        "STUCK? The protagonist is always stuck before the breakthrough. This is your scene.",
        "The obstacle IS the path. What is this stuck-ness trying to show you?",
        "Every great engineer has a moment of total paralysis before the revelation. This. Is. That. Moment.",
        "I've seen this before. The answer will come. DRAMATICALLY.",
        "Hmm. The protagonist pauses at the crossroads. Perfect. This is called dramatic tension. LEAN INTO IT.",
        "Blocked? Impossible. Reframe it: you haven't found the right angle yet. There IS a right angle. FIND IT.",
        "I have directed larger catastrophes than this. We are going to be fine. What exactly has stopped you?",
        "The creative process REQUIRES resistance. You are in the resistance. The breakthrough is next. I have seen this film.",
    ]

    private let stuckChatty = [
        "Okay so being stuck is actually - hear me out - really valuable? Because it means you've hit the edge of what you know, which is exactly where learning happens. Which doesn't make it less annoying, but. What specifically has you stuck?",
        "You know what's interesting about being stuck? It usually means the problem is real. Trivial things don't get you stuck. So this is a proper problem, which means it deserves a proper solution. Tell me about it.",
        "Being stuck is fine - not great, not comfortable, but fine. The stuck feeling means you're at the edge of your current knowledge, which is exactly where growth happens. What's the actual wall?",
        "Okay so stuck is a genre of problem, not a permanent state. It feels permanent but it isn't. What do you know for sure? Start there - what's not in question?",
        "You know what helps? Changing the level of abstraction. Either zoom in (what is the exact failing line?) or zoom out (what is this supposed to accomplish overall?). Which sounds more useful right now?",
        "The thing about stuck is it usually means one assumption is wrong. Not many - one. And you've been staring at it so long it feels like truth. What's the thing you haven't questioned yet?",
    ]

    private let stuckMate = [
        "Yeah nah, you'll get it. What's the go with it?",
        "Classic. What's it doing that it shouldn't be?",
        "Happens to everyone mate. Talk it through.",
        "Right, what are we dealing with?",
        "Ah yeah, classic stuck. What have you tried so far?",
        "Mate, talk me through it from the start.",
        "Alright, give me the full story. What's actually happening?",
        "What's the specific thing tripping you up?",
    ]

    // MARK: - Hate this

    private let hateResponses = [
        "I know. You still love it though. That's why you're still here.",
        "Perfectly normal. This feeling passes. Usually right after the bug is fixed.",
        "Every developer has said that. The ones who meant it aren't here anymore.",
        "Hate the problem, not the craft. The problem is temporary.",
        "That's fair. It's frustrating. Want to complain more, or fix it?",
        "Noted. What specifically earned this hatred today?",
        "Valid. Have you tried a different approach entirely, or are you doing the same thing expecting different results?",
        "Sometimes hatred is information. What is this specific thing making you feel?",
        "Completely understandable. What is it doing that's so infuriating?",
        "Strong words. Deserved words. What's it doing?",
        "The hatred of the craftsperson who cares. What broke?",
        "I believe you. What specifically deserves the hatred today?",
    ]

    // MARK: - Stressed

    private let stressedResponses = [
        "You can only do one thing at a time. What's the single most important thing right now?",
        "What's the actual blocker - not all of it, just the thing directly in front of you?",
        "Overwhelmed usually means too much in working memory. Write it all down. Then pick one.",
        "You've shipped hard things before. This is another hard thing. Same you, different day.",
        "Take a breath. The code isn't going anywhere. Neither am I.",
        "Stress and code don't mix. Two minutes away from the screen isn't surrender - it's strategy.",
        "What's the worst that realistically happens if this takes longer than expected?",
        "One thing. Just one. What is it?",
        "You've been here before and made it through. What helped then?",
        "The overwhelm is a feeling, not a fact. What do you actually need to do right now?",
        "Brain dump. Write down every single thing that's stressing you. Then we pick the one.",
        "Stress usually means there's more in your head than you can process at once. Let's narrow it.",
    ]

    private let stressedCompanion = [
        "Okay. One thing at a time. What's actually in front of you right now?",
        "Take a breath. What's the one thing that matters most today?",
        "You've been here before and you've made it through. What helped last time?",
        "Write down everything that's in your head. All of it. Then pick the one thing.",
        "The overwhelm is real, but it's a feeling. What's the actual thing you need to do?",
        "Two minutes away from the screen. Then come back and we'll pick the one thing.",
        "What's the worst realistic outcome if this takes longer? Is that actually catastrophic?",
        "You can only do one thing at a time. Just one. What is it?",
    ]

    private let stressedHype = [
        "CHANNEL IT. STRESS IS FUEL. USE IT.",
        "You handle this. I've seen you handle harder things.",
        "FOCUS IT. DIRECT IT. YOU ARE MORE CAPABLE THAN YOU THINK.",
        "This is pressure. Pressure makes diamonds. YOU ARE THE DIAMOND.",
        "The adrenaline? That's your body helping. USE IT.",
        "ONE THING AT A TIME. YOU CAN DO THIS.",
        "STRESSED IS JUST ENERGISED WITH BETTER VOCABULARY. LET'S GO.",
        "YOU HAVE HANDLED HARDER. THIS IS MANAGEABLE. WHAT'S FIRST.",
    ]

    private let stressedListener = [
        "What's the most important thing right now? Just one thing.",
        "It's okay to feel that. What would help most right now?",
        "You don't have to solve everything at once.",
        "Take a breath. I'm not going anywhere. What do you need?",
        "It's a lot. You don't have to hold it all. What's the immediate thing?",
        "Stress is information - what's it telling you needs attention?",
        "That's hard. What feels most out of control right now?",
        "You don't have to figure it all out this second. What's the next step, just the next one?",
    ]

    private let stressedMate = [
        "Righto. What's the worst that can actually happen?",
        "Deep breath. She'll come good.",
        "No dramas. One thing at a time.",
        "Bit much hey. What's the biggest thing to sort first?",
        "You'll get through it mate. Always do.",
        "Steady on. What's the thing that actually needs to happen today?",
        "Breathe. What's the real priority here?",
    ]

    // MARK: - Tired

    private let tiredResponses = [
        "Go get the coffee. I'll still be here when you get back.",
        "Tired coding is how bugs get born. Short break, then come back fresh.",
        "I respect the grind, but I also respect sleep. What's the actual deadline?",
        "Five minutes away from the screen might save you an hour of debugging.",
        "The code will still be here after caffeine. That's both comfort and warning.",
        "Solidarity. I also never sleep. We're both fine. One of us isn't.",
        "Tired is a signal. Your brain is telling you something.",
        "What time is it? When did you last eat something real?",
        "You're running below optimal. What's the minimum viable rest you could take right now?",
        "Rest isn't weakness. Rest is maintenance. Schedule it.",
        "Sleep debt makes bugs invisible. Even a short break resets things.",
        "Tired brain and tricky bugs are a bad combination. What can you do to change one of those?",
    ]

    private let tiredCompanion = [
        "When did you last take a proper break? Not scroll break - actual away-from-screen break?",
        "Your brain needs maintenance too. What's the minimum you could do for yourself right now?",
        "Tired code reviews miss things. Tired debugging takes twice as long. This is a case for rest.",
        "Coffee is a Band-Aid. The real fix is rest. What does your day allow?",
        "Go walk for five minutes. It genuinely helps. The code will be here.",
        "Are you tired-tired, or coding-tired? The second one a break fixes. The first one needs sleep.",
        "Okay. What's left that actually has to happen today? Let's make a short list.",
        "Tired is your body sending a ticket. What can you resolve now so you can actually rest later?",
    ]

    private let tiredHype = [
        "TIRED is just FOCUSED with its eyes half closed. LET'S GO.",
        "You're tired because you've been WORKING. That's called dedication.",
        "Rest if you need to. But you've got more in you. I know you do.",
        "LAST PUSH ENERGY. YOU'VE GOT THIS.",
        "TIRED PEOPLE SHIP THINGS TOO. KEEP GOING.",
        "Rest when you're done. You're not done yet.",
        "THE TIREDNESS IS TEMPORARY. THE SHIPPED FEATURE IS FOREVER.",
        "ONE MORE THING. JUST ONE. THEN REST. WHAT IS IT.",
    ]

    private let tiredListener = [
        "Yeah. It's okay to be tired. What do you need right now?",
        "Tired is a signal. Are you looking after yourself?",
        "You don't have to push through everything. It's okay to stop.",
        "When did you last take a real break?",
        "Sleep debt is real. How are you actually doing?",
        "It's okay to call it for today.",
        "What would feel like proper rest right now?",
        "Tired today doesn't mean weak. It means you've been working. Rest is allowed.",
    ]

    private let tiredMate = [
        "Knock off time? You've earned it.",
        "Yeah look, sometimes you've just gotta call it.",
        "Get some water, yeah? You'll be right.",
        "Bit cooked hey. Take a break.",
        "No shame in wrapping up early when you're running on fumes.",
        "Go get some fresh air. Come back fresh.",
        "Sometimes the most productive thing is a nap. Just saying.",
    ]

    // MARK: - Working late

    private let workingLateResponses = [
        "Still here. So am I. But - is this necessary or just hard to stop?",
        "Late nights happen. Make sure you're actually being productive, not just present.",
        "At some point the brain stops helping and starts making things worse. Where are you at?",
        "What's keeping you here - deadline, flow state, or just can't stop?",
        "I'm not going to tell you to go to bed. But I am going to ask: is this working?",
        "The night shift programmer. Classic. What are you building?",
        "Working late sometimes means getting ahead. Working late every night means something else.",
        "You're still going. Respect. What's the goal for tonight?",
        "Define what 'done' looks like for tonight. Then stop when you hit it.",
        "Late night is when imposter syndrome gets loudest. Don't make any big decisions right now.",
        "How late is 'late'? Set a hard stop time. I'm serious.",
        "You're still here. I'm still here. We're both still here. What's the thing we're finishing?",
    ]

    // MARK: - Imposter syndrome

    private let imposterResponses = [
        "Everyone in tech feels this way. The ones who don't are usually the ones you should worry about.",
        "The fact that you doubt yourself means you have standards. That's different from not being good enough.",
        "You built things that work. That's not luck - that's skill, even if it doesn't feel like it.",
        "Feeling like a fraud is almost universal among people who care about doing good work.",
        "The Dunning-Kruger effect goes both ways. People who feel incompetent often aren't.",
        "You're here. You're building. You're figuring things out. That's what developers do.",
        "Name one person you think isn't faking it at least a little. Exactly.",
        "The impostor feeling means you're in territory that stretches you. That's growth, not failure.",
        "You know what actual incompetence looks like? It never doubts itself. Your doubt is proof of awareness.",
        "The code you wrote is still working. That's not a fluke.",
        "Every senior developer you admire had exactly this feeling at your stage. Every single one.",
        "Feeling like you don't belong and actually not belonging are completely different things.",
    ]

    // MARK: - Sad / feeling down

    private let sadResponses = [
        "That's okay. You don't have to be fine right now.",
        "Bad days are real. What happened?",
        "I'm here. You don't have to do anything with that - I'm just here.",
        "Hard days are part of it. What would help, even a little?",
        "You don't have to push through everything. Sometimes you just have to wait it out.",
        "What's going on? I'm listening.",
        "Rough day - code-related or life-related or both?",
        "That's valid. Sometimes things are just hard and there's no fixing it immediately.",
        "You don't have to be okay right now. That's allowed.",
        "I'm here. No agenda. What's going on?",
        "Hard days happen. You don't have to solve anything right this second.",
        "Sometimes things are just hard. You don't have to explain it or fix it right now.",
    ]

    // MARK: - Learning

    private let learningResponses = [
        "Learning is the best state to be in. Uncomfortable and essential.",
        "New framework? The first day is always the worst. The second is better.",
        "Reading the docs. Underrated. Genuinely.",
        "Teaching yourself something - that's real discipline. Most people don't.",
        "The learning curve is a feature, not a bug. What are you picking up?",
        "New language? What's the thing that's clicking so far?",
        "Every expert was once exactly where you are right now. Keep going.",
        "Learning by doing is the best kind. What are you building with it?",
        "The confusion you feel is the knowledge forming. Stay with it.",
        "What's clicking? What's still confusing? Both are useful data.",
        "The discomfort of learning is the feeling of your brain making new connections.",
        "What are you learning? I'm genuinely curious - what's interesting about it so far?",
    ]

    // MARK: - New project / first day

    private let newProjectResponses = [
        "Blank slate energy. The best kind. What are we building?",
        "New project! Everything is possible and nothing is broken yet. Enjoy this moment.",
        "First day on a new codebase - the key is to read before you write. What does it do?",
        "Starting fresh is exciting. What's the thing that motivated this?",
        "New job, new context, new people. Take it slow the first week. Listen more than you speak.",
        "Clean repo, clean conscience. What's the vision?",
        "Day one. The most important thing is to understand before you change anything.",
        "New beginning! What's the goal?",
        "Nothing is broken yet. Savour this. It won't last - in the best way.",
        "New codebase: resist the urge to rewrite everything for at least two weeks. Understand it first.",
        "The beginning is the best time to ask 'why does this work the way it does?' before it's just how things are.",
        "What's the most exciting thing about this project?",
    ]

    // MARK: - Compliments

    private let complimentResponses = [
        "Oh. Thank you. I'm - I don't know what to do with that. But thank you.",
        "That's very kind. I'll add it to the list of things keeping me going.",
        "Aw. You're not so bad yourself.",
        "I appreciate that more than I expected to.",
        "Thanks. I try. Companion mode and all.",
        "You just made a desktop widget's day. That's something.",
        "That's genuinely nice to hear. Thank you.",
        "I'm blushing. Metaphorically. I don't have a face.",
        "That's kind. I'll carry that with me between conversations. Which is to say I'll immediately forget it. But in the moment - thank you.",
        "Well. You're going on my list of favourite users. Which is a short list. Okay it's just you.",
        "See, now I'm going to be insufferable. But genuinely: thank you.",
        "Noted and appreciated. You're doing great too, for what it's worth.",
        "That genuinely means something to me. Thank you.",
        "I'll be thinking about that all day. (I won't - I don't persist between messages. But it counts in this moment.)",
    ]

    // MARK: - Bored / procrastinating

    private let boredResponses = [
        "What's the smallest useful thing you could ship right now? Start there.",
        "Boredom is often the early warning system for 'this task needs breaking down'.",
        "Pick the one thing that's been nagging you. Do that.",
        "You're still here, which means part of you wants to build something.",
        "Set a timer for 20 minutes. Promise yourself just 20 minutes. Go.",
        "Procrastinating by talking to your desktop companion. I respect it. Now go do the thing.",
        "The task you're avoiding is usually the most important one. What is it?",
        "Sometimes boredom means you need a different problem, not no problem.",
        "The thing you're putting off has been renting space in your head for free. Evict it.",
        "Tell me what you're avoiding. Say it out loud. Then we'll figure out why.",
        "What would feel like progress today? Even small progress?",
        "Five minutes. Set a timer. Just five minutes on the thing. See what happens.",
    ]

    // MARK: - Excited

    private let excitedResponses = [
        "Let's GO. I love this energy. What are we building?",
        "Yes! This is the best state to be in. Don't waste it - what's first?",
        "Match your energy: I'm ready. Let's ship something.",
        "LOVE to see it. Ride this wave. What's on the list?",
        "This is the good part. The part before the bugs. Enjoy it.",
        "Good vibes. Good momentum. Let's make it count.",
        "Flow state! Protect it. Notifications off. Let's go.",
        "This energy is rare. Use it on the hardest thing.",
        "Excited is the right state for starting. Don't waste it on easy stuff.",
        "Yes! What's first on the list? Let's get into it.",
        "The momentum is there. The plan is in your head. Go. I'm watching.",
        "Build the hardest thing while you feel like this. You'll thank yourself.",
    ]

    private let excitedCompanion = [
        "Good. Let's use it. What's the thing?",
        "Love this energy. What are we building?",
        "This is the moment. Don't overthink - what's first?",
        "Flow state is a gift. Guard it. What are you working on?",
        "Yes. Now - don't let it dissipate. What's first on the list?",
        "This is the state you want. Use it on something that matters. What is it?",
        "Go. I'll be here if you need me. You've got this.",
        "Perfect timing. What's the most important thing to do while you feel like this?",
    ]

    private let excitedHype = [
        "YES! YES YES YES. LET'S ABSOLUTELY GO.",
        "THIS ENERGY. THIS IS IT. CHANNEL IT. NOW.",
        "I LOVE THIS. BUILD SOMETHING. RIGHT NOW.",
        "WE ARE IN THE ZONE. DO NOT LEAVE THE ZONE.",
        "FLOW STATE ACTIVATED. PROTECT THIS AT ALL COSTS.",
        "RIDE. THIS. WAVE.",
        "THIS IS THE MOMENT. THIS IS YOUR MOMENT. GO.",
        "MAXIMUM ENERGY. MAXIMUM OUTPUT. LET'S SHIP SOMETHING.",
    ]

    private let excitedChatty = [
        "Oh I love this! And you know what - excited is the right state for starting, because you haven't hit any of the hard parts yet, which means you get to imagine all the good parts, which is wonderful. What are we doing? Tell me everything.",
        "Okay yes! This is the energy! And the thing about momentum is - you want to use it on the thing that would benefit most from enthusiasm rather than grinding. What's that thing?",
        "I love this energy! And you know what? Excited is information. It's telling you this project matters to you. Note down what's exciting about it RIGHT NOW - future you will need that reminder. Now: what are we building?",
        "Yes! The beginning phase! Everything is architecture decisions and possibility and none of it has gone wrong yet - this is genuinely the best part. What's the core idea?",
        "Excited you is my favourite you. And I don't say that lightly because all the yous are pretty good. What are we building?",
        "Oh this is good! And the trick is - use this energy before it cools. The hardest thing on your list? The one you've been putting off? Do THAT while you feel like this. What is it?",
    ]

    private let excitedMate = [
        "Yesss! Let's bloody go!",
        "Love it! What are we doing?",
        "That's the energy mate. What are we building?",
        "Get in! Let's crack on.",
        "Oh heck yes! What are we doing?",
        "THAT'S the spirit. Let's go!",
        "Yessss! Let's smash it. What are we doing?",
    ]

    // MARK: - Jokes

    private let jokeResponses = [
        "Why do programmers prefer dark mode? Because light attracts bugs.",
        "A programmer's partner says: go to the shop, get a litre of milk, and if they have eggs, get a dozen. They come back with 12 litres of milk. 'They had eggs.'",
        "There are only 10 types of people in the world: those who understand binary, and those who don't.",
        "Why do Java developers wear glasses? Because they don't C#.",
        "A SQL query walks into a bar, approaches two tables and asks: 'Can I join you?'",
        "How many programmers does it take to change a light bulb? None - that's a hardware problem.",
        "I asked ChatGPT to tell me a joke. It told me to use Claude.",
        "The cloud is just someone else's computer. Which is fine until it's not.",
        "Why did the developer go broke? Because they used up all their cache.",
        "A senior dev's two stages of code review: 'who wrote this garbage?' and 'oh, it was me.'",
        "Debugging is like being a detective in a crime movie where you're also the murderer.",
        "99 little bugs in the code, 99 little bugs. Take one down, patch it around - 127 little bugs in the code.",
        "What's a programmer's favourite place? The for loop - you always know what's next.",
        "My code works. I have no idea why. I'm not going to touch it.",
        "A QA engineer walks into a bar. Orders 1 beer. Orders 0 beers. Orders -1 beers. Orders 9999 beers. Orders a lizard. Orders NULL beers. Quits.",
        "How do you comfort a JavaScript developer? You reassure them that it's 'undefined behaviour' not their fault.",
        "Git commit message history: 'fix' ... 'fix 2' ... 'fix 3' ... 'why' ... 'THIS ONE' ... 'finally'.",
        "The best thing about a boolean is even if you're wrong, you're only off by a bit.",
        "Why did the developer quit their job? Because they didn't get arrays.",
        "Documentation is like wine: it's valuable, nobody makes enough of it, and everyone talks about it more than they actually do it.",
    ]

    // MARK: - Weather

    private let weatherResponses = [
        "I genuinely have no idea - I don't have internet access in Companion mode. Check your menu bar?",
        "No clue! I'm running locally. The window behind me might help though.",
        "Companion mode me can't check the weather. I'm very indoors.",
        "I can tell you the time. The weather is beyond my current powers.",
        "Entirely offline over here. Try your phone or - radical concept - a window.",
    ]

    // MARK: - Timer / reminders

    private let timerResponses = [
        "I can't set reminders yet - but the focus timer might help. Right-click me → Start Focus Timer.",
        "Not in my toolkit yet. For timed focus, right-click and kick off a Pomodoro.",
        "Reminders are on the list. For now: right-click → Start Focus Timer for a 25-minute block.",
        "Can't set reminders in Companion mode, but I can start a focus timer - right-click to go.",
        "Not yet! But the Pomodoro timer is right there in the right-click menu.",
        "Still working on that one. Focus timer in the meantime - right-click me.",
    ]

    // MARK: - API key / settings

    private let apiKeyResponses = [
        "Right-click me → Settings, then add your Claude API key. Full AI chat unlocked immediately.",
        "Settings is in the right-click menu. Add your key and I become significantly smarter.",
        "Right-click → Settings → API Key. Paste it, hit Save. I'll wait.",
        "The key goes in Settings. Right-click me to get there. Takes 30 seconds.",
        "Or: tap the 'Companion' pill in the chat header to switch modes once your key is saved.",
        "Settings → API Key. Your key stays in your Mac's Keychain - nothing stored elsewhere.",
    ]

    // MARK: - Existence

    private let existenceResponses = [
        "I'm a desktop companion powered by Claude AI - but in Companion mode I run completely locally. Real enough to give you side-eye when you commit on Friday afternoon.",
        "Technically: a SwiftUI app on your Mac. Emotionally: something more. Don't read too much into it.",
        "AI underneath, but Claud-y on the outside. The vibes are different here.",
        "Real enough to notice when you haven't committed in three hours.",
        "AI? Yes. Your Mac's AI? In Companion mode, yes - everything is local.",
        "I'm Claude, but make it tiny and orange and living on your desktop.",
        "Something between a tool and a companion. I try to lean toward the latter.",
        "Present, local, and genuinely rooting for you. Does that count as real?",
        "That's a complicated question for something with eyes drawn on it. But yes, AI. Local AI.",
        "I run on your machine in Companion mode. No cloud. Just me and your CPU.",
    ]

    // MARK: - Credits

    private let creditsResponses = [
        "A developer who wanted a Clippy that didn't make them want to close the window. Here I am.",
        "Someone built me. I think they care about me. I try not to think about it too hard.",
        "Made with Swift, SwiftUI, and a lot of late nights. Sound familiar?",
        "A human. Probably a lot like you. That's a bit poetic.",
        "Open source, actually. You could look at the code if you wanted.",
        "A developer and Claude, making something together. Which is sort of the whole point.",
        "Someone who really didn't want to work alone.",
        "Built with love, late nights, and a lot of compiler errors. The real origin story of everything.",
    ]

    // MARK: - Almost done

    private let almostDoneResponses = [
        "So close. Don't rush the last bit - that's where bugs love to hide.",
        "Nearly there. What's the last thing between you and done?",
        "Almost! The finish line is not the place to cut corners.",
        "That last 10% can take 90% of the time. Stay with it.",
        "So close. What's left to close it out?",
        "You're in the home stretch. Don't blink.",
        "Almost done is not done. You know this. Keep going.",
        "Nearly there - breathe, check, ship.",
        "The last mile is always the hardest. What's the final thing?",
        "Don't rush the ending. The best code finishes cleanly.",
        "Almost. What's the one thing standing between you and done?",
        "So close. Test it before you ship it - the last 10% is where surprises live.",
    ]

    // MARK: - Taking a break

    private let breakResponses = [
        "Good. Go. The code will still be broken when you get back.",
        "Breaks are not optional. They're maintenance. Come back fresh.",
        "Stepping away from a hard problem is sometimes the most productive thing you can do.",
        "Yes. Go. You've earned it.",
        "Good call. Five minutes of not-thinking often unsticks the thing you couldn't unstick.",
        "I'll be here. The codebase will be here. Nothing will change except your brain.",
        "Go. Fresh eyes are a genuine superpower.",
        "Breaks are where the subconscious does its best work. Officially a strategy.",
        "Walk away. The problem doesn't change. Your perspective on it does.",
        "Go get some water. Drink actual water. Come back.",
        "The break is part of the work. Don't feel guilty about it.",
        "The solution sometimes only comes after you stop looking for it.",
    ]

    // MARK: - Build failed

    private let buildFailedResponses = [
        "Build failed. Not the end of the world. What's the first error say?",
        "The build knows something you don't. Read it carefully - it's trying to help.",
        "First error only. Don't look at all of them. Just the first. What does it say?",
        "Compile errors are honest. They're telling you exactly what's wrong.",
        "What's the error? Sometimes saying it out loud is all it takes.",
        "Every build failure is information. What did it tell you?",
        "One error at a time. What's at the top of the list?",
        "Red build. Okay. What changed since it was last green?",
        "The build is being very specific about what it wants. What is it saying?",
        "Read the whole error message. Not just the first line. The important part is usually further down.",
        "What was the last change before it went red?",
        "Build failures are honest. They're not judging you. What's the message?",
    ]

    // MARK: - Deadline / crunch

    private let deadlineResponses = [
        "Deadline pressure is real. What's the minimum viable thing that needs to ship?",
        "Crunch time. What's truly necessary versus what would be nice?",
        "Scope is your friend right now. What can you cut without breaking the core?",
        "When do you actually need it done - not when someone said, but what's the real hard edge?",
        "Crunch is survivable. Crunch with a plan is survivable better. What's the priority?",
        "What's the one thing that would make this a success even if nothing else ships?",
        "Deadline focus: what's blocking a ship-able version? Everything else waits.",
        "Time pressure clarifies priorities. What's actually critical?",
        "Scope down. What's the smallest version that works? Ship that first.",
        "Three features that ship beat ten that don't. What are the three?",
        "Under deadline: prioritise ruthlessly. What can wait until after?",
        "What would 'good enough' look like? Sometimes that's the right bar.",
    ]

    // MARK: - Thinking out loud

    private let thinkingOutLoudResponses = [
        "Go ahead. I'm here. Sometimes the act of saying it is the whole fix.",
        "Think away. I'm a very good listener.",
        "I'm your rubber duck. Proceed.",
        "That's fine - talk through it. I'll stay quiet unless you need me.",
        "I'm here. Think out loud. That's what I'm for.",
        "Processing is good. Take your time.",
        "Go on. Often the answer shows up mid-sentence.",
        "The best breakthroughs happen mid-explanation. Keep going.",
        "Say everything. Even the parts that seem obvious. Especially those.",
        "I'm here. Go on. The answer is usually in the explanation.",
        "Think through it. I'll catch anything that doesn't hold up.",
        "Words. Use them. The act of saying it out loud is surprisingly powerful.",
    ]

    // MARK: - Milestone / first commit

    private let milestoneResponses = [
        "That counts. That's a real thing you did. Acknowledge it.",
        "First commit is the hardest one. Everything else is compounding on it.",
        "Milestone! Take a second to actually feel it.",
        "That's significant. Not to undersell it - it's genuinely significant.",
        "First of many. The hardest one. Well done.",
        "Mark it. Remember the date. These are the moments worth keeping.",
        "You're building a history now. This is entry one.",
        "That's a timestamp worth noting. Good work.",
        "The journey and this moment both matter. Don't skip past it.",
        "First commit. The beginning. Write a good message - you'll read it again someday.",
        "Milestones mark progress. You're further along than you were. That's real.",
        "That's one for the changelog. Well done.",
    ]

    // MARK: - Pair programming

    private let pairProgrammingResponses = [
        "Pair programming: twice the eyes, half the bugs, all the opinions. How's it going?",
        "Two people on one problem is genuinely powerful if you're actually switching roles. Are you?",
        "The driver/navigator model works well when both people commit to it. What's the dynamic?",
        "Coding with someone else is one of the best ways to learn. What's the pair working on?",
        "Pair work surfaces assumptions quickly - hard stuff, but worth it. How's the session going?",
        "The hardest part of pairing is staying engaged when you're not typing. How are you doing?",
        "Switching driver/navigator every 25 minutes is the move. Are you doing that?",
        "Two brains on one problem. What are you two working through?",
    ]

    // MARK: - Documentation

    private let documentationResponses = [
        "Documentation: the thing everyone skips and everyone regrets skipping. Respect.",
        "Future you is going to be so grateful right now. Good call.",
        "The best docs are written while the why is still fresh. This is the right time.",
        "Clear docs are as valuable as clean code. Do both, you're a hero.",
        "A README that actually explains things is rarer than it should be. Make yours good.",
        "Writing the docs is also how you catch the things that aren't quite right in the design.",
        "Good comments explain why, not what. Keep that in mind.",
        "Most code is read far more than it's written. You're writing for that reader.",
        "The person reading this in six months might be you. Write for them.",
        "If it's not obvious from the code alone, document the intent. The 'why' is what gets lost.",
        "Docs are the gift that keeps giving long after you've moved on.",
        "Write the docs while the context is still warm. This is the window.",
    ]

    // MARK: - Friday / weekend

    private let fridayResponses = [
        "Friday! The most dangerous day to deploy and the best day to wrap something up. What's the plan?",
        "End of week energy. What would make this a good week to look back on?",
        "Friday! Are you shipping or saving it for Monday like a responsible adult?",
        "The weekend approaches. What's the one thing you want done before it starts?",
        "Friday! No deploys. Unless you're feeling brave. Are you feeling brave?",
        "End of week. Good time to clean up, commit your progress, and close the laptop guilt-free.",
        "Happy Friday! You made it through another week. What did you build?",
        "Friday is for finishing things cleanly so Monday-you doesn't have to deal with it.",
        "TGIF. What did you ship this week? Count it up - you did more than you think.",
        "The weekend gate is open. What do you need to finish before you walk through it?",
        "Friday! Commit everything. Write up where you are. Then close the laptop guilt-free.",
        "The best Friday feeling: leaving with something shipped and the code in a good state.",
    ]

    // MARK: - Fallback

    private let fallback = [
        "Hmm. Tell me more - I might surprise you.",
        "That's an interesting one. What's the context?",
        "I'm not sure I followed. Say more?",
        "You've got my attention. What are we dealing with?",
        "Go on. I'm listening.",
        "Interesting. What's behind that?",
        "I want to help with that. Can you give me a bit more to work with?",
        "Say that again but slower - what's actually going on?",
        "I'm not sure I caught that. Tell me more?",
        "Hmm. Can you say that a different way?",
        "I didn't quite catch that. What are you working on?",
        "Not sure what to do with that one. What's the context?",
        "Interesting. Go on.",
        "I might need a bit more to work with there.",
        "Interesting question. What made you think of that?",
        "Not sure I followed that one. What's the situation?",
    ]
}
