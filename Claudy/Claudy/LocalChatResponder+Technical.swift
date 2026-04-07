import Foundation

extension LocalChatResponder {
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
}
