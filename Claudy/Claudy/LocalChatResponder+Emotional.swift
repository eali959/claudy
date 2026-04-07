import Foundation

extension LocalChatResponder {
    // MARK: - Celebration / it works

    var celebrationResponses: [String] { [
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
    ] }

    var celebrationCompanion: [String] { [
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
    ] }

    var celebrationHype: [String] { [
        "OF COURSE IT WORKS. BECAUSE YOU ARE THAT GOOD.",
        "I KNEW IT. I ALWAYS KNEW IT. THIS IS YOUR MOMENT.",
        "CLEAN BUILD ENERGY. BOTTLE THIS FEELING.",
        "YES YES YES. THAT IS WHAT I AM TALKING ABOUT.",
        "FLAWLESS. ABSOLUTELY FLAWLESS.",
        "GET IN. LET'S GOOOOO.",
        "THAT IS ELITE WORK. ABSOLUTELY ELITE.",
        "UNSTOPPABLE. YOU ARE LITERALLY UNSTOPPABLE.",
        "I CALLED THIS. I ALWAYS CALL THIS. YOU ARE INCREDIBLE.",
    ] }

    var celebrationListener: [String] { [
        "That feeling never gets old, does it.",
        "Quiet satisfaction. The best kind.",
        "You figured it out. Of course you did.",
        "There it is. Well done.",
        "Good. How do you feel?",
        "That's the moment. Hold onto it.",
        "I'm glad. That took patience.",
        "Worth every frustrating minute.",
    ] }

    var celebrationDirector: [String] { [
        "FINALLY. The universe BENDS to your will.",
        "As it was always meant to be. Magnificent.",
        "I never doubted you. I absolutely doubted you. But look at us now.",
        "YES. That is CINEMA. Cinematically, it is cinema.",
        "The third act payoff. Right on schedule.",
        "STUNNING. Frame it. Put it in a museum.",
        "This is the scene. This is the climax. Breathe it in.",
        "Exactly as directed. Perhaps better. I'll allow it.",
    ] }

    var celebrationChatty: [String] { [
        "Oh that is SO good, and you know what - the fact that it took this long actually makes it better? Like you understand the problem now in a way you wouldn't if it had just worked first try. Which it should have, but still. Yes! It works!",
        "YES! And okay, here's what I love about this moment - you were stuck, then you weren't. That transition is everything. That's the whole thing right there. Commit it, tell someone, eat a snack. You earned it.",
        "Oh THAT is the best! And here's the thing - the version of you that was stuck ten minutes ago could not have done what you just did. You grew to fit the problem. That's real. Celebrate it.",
        "YES! So here's my take: every fix teaches you something that makes the next one faster. You're not just solving one bug - you're compounding. But also: yes! It works! Enjoy this moment!",
        "It works!! And I want to point out that you did not give up, which some people do, and that made all the difference. You should feel genuinely good about this.",
        "Oh WONDERFUL! And look - I know the next thing is already waiting, I know you can see it from here, but just - pause. You fixed a thing. A real thing. That matters. Now go commit it before you accidentally break it again.",
    ] }

    var celebrationMate: [String] { [
        "Yesss mate! Get in!",
        "THERE it is. Knew you'd crack it.",
        "Beauty! Ship that thing.",
        "That's the one. Absolute legend.",
        "Ayyy! Knew you had it in ya.",
        "Let's gooo! Good bloody work.",
        "THERE we go! Smashed it.",
        "YES! That's what we're talking about!",
        "Get in, ya legend! Good work.",
    ] }

    // MARK: - Shipped

    var shippedResponses: [String] { [
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
    ] }

    // MARK: - Breakthrough

    var breakthroughResponses: [String] { [
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
    ] }

    // MARK: - Broke everything

    var brokeEverythingResponses: [String] { [
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
    ] }

    var brokeEverythingCompanion: [String] { [
        "Okay. Breathe. What did you last change? Start there.",
        "git stash or git checkout -- . might be your friends right now. What did you touch?",
        "Everything breaks at some point. What specifically stopped working?",
        "Take a breath. Walk me through what happened - start from the last thing that worked.",
        "Not the end. What does git diff show you?",
        "Start with: what changed? Last edit, last file, last anything.",
        "Recoverable. Almost certainly. What's the error telling you?",
        "You've been here before. You got through it then. What happened?",
        "Okay. One thing at a time. What's the most critical thing that's broken?",
    ] }

    var brokeEverythingHype: [String] { [
        "THIS IS NOT BREAKING. THIS IS CREATIVE DESTRUCTION. REBUILD BETTER.",
        "EVERY GREAT APP HAS THIS MOMENT. THIS IS YOURS. RISE.",
        "The phoenix moment. You are RISING FROM THE ASHES.",
        "CHAOS IS JUST UNORDERED SUCCESS. LET'S GO.",
        "You're not broken. The code is broken. YOU are fine.",
        "THIS IS THE PART OF THE STORY WHERE YOU COME BACK STRONGER.",
        "BURNED IT DOWN? GOOD. NOW WE BUILD SOMETHING MAGNIFICENT.",
        "THIS IS TRAINING. THE REAL WORK STARTS NOW.",
    ] }

    var brokeEverythingListener: [String] { [
        "Okay. Deep breath. What is the last thing you changed?",
        "Take a moment. Then let's retrace your steps together.",
        "It's okay. These things happen. What does the error say?",
        "You don't have to fix it all right now. What's the most important thing to restore?",
        "What does git diff tell you?",
        "Start from the last working state. What changed since then?",
        "It's okay to be frustrated. What specifically broke?",
        "No rush. Talk me through what happened.",
    ] }

    var brokeEverythingDirector: [String] { [
        "BEAUTIFUL. Chaos is just order that hasn't been directed yet.",
        "The phoenix moment. I live for this. We rebuild.",
        "Oh for the love of - fine. FINE. We start again. TOGETHER. MAGNIFICENTLY.",
        "Every great story has a disaster in act two. This is yours. Act three is going to be incredible.",
        "Magnificent disaster. The best kind. Now we rebuild with INTENTION.",
        "Look at that. Everything broken. Like a sculptor with a hammer and a vision. WHAT IS THE VISION?",
        "I've seen this before. Act two catastrophe. Act three redemption. WHAT DID WE LOSE.",
        "Chaos. Chaos everywhere. Good. Nothing was sacred. Now we choose what to rebuild and make it BETTER.",
    ] }

    var brokeEverythingMate: [String] { [
        "Ah, mate.",
        "She's gone a bit pear-shaped. Easy fix though.",
        "Git stash. Start again. She'll be right.",
        "Classic. What did you touch last?",
        "No dramas. We'll sort it out.",
        "Righto. What's actually broken? Walk me through it.",
        "Happens to everyone. What did git say?",
    ] }

    // MARK: - PR / Code Review

    var prResponses: [String] { [
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
    ] }

    // MARK: - Debugging

    var debugResponses: [String] { [
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
    ] }

    // MARK: - Refactoring

    var refactorResponses: [String] { [
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
    ] }

    // MARK: - Testing

    var testingResponses: [String] { [
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
    ] }

    // MARK: - Meeting

    var meetingResponses: [String] { [
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
    ] }

    // MARK: - Confused

    var confusedResponses: [String] { [
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
    ] }

    // MARK: - Stuck

    var stuckResponses: [String] { [
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
    ] }

    var stuckCompanion: [String] { [
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
    ] }

    var stuckHype: [String] { [
        "STUCK? You are NOT stuck. You are PRE-SOLVING. KEEP GOING.",
        "Every great solution starts with being stuck. This is the PROCESS.",
        "You've been stuck before. You solved it then. You'll solve it now. I BELIEVE THIS.",
        "Stuck is just thinking with extra steps. KEEP GOING.",
        "THE ANSWER IS RIGHT THERE. YOU'RE ALMOST AT IT.",
        "PRE-BREAKTHROUGH ENERGY. THIS IS IT.",
        "STUCK MEANS YOU'VE HIT THE HARD PART. THE HARD PART IS WHERE GROWTH LIVES.",
        "I'VE SEEN YOU DO HARDER THINGS. THIS IS NOTHING.",
    ] }

    var stuckListener: [String] { [
        "That's okay. What part feels hardest right now?",
        "Being stuck is part of it. Take a breath. What do you know so far?",
        "Sometimes stuck means you're about to figure something out. Stay with it.",
        "What have you tried so far? Walking through it might help.",
        "It's okay to not know. What would help most right now?",
        "Take your time. What does the problem look like from the outside?",
        "No pressure. Describe it to me. Sometimes just describing it helps.",
        "What would make this feel less stuck? Even a little bit?",
    ] }

    var stuckDirector: [String] { [
        "STUCK? The protagonist is always stuck before the breakthrough. This is your scene.",
        "The obstacle IS the path. What is this stuck-ness trying to show you?",
        "Every great engineer has a moment of total paralysis before the revelation. This. Is. That. Moment.",
        "I've seen this before. The answer will come. DRAMATICALLY.",
        "Hmm. The protagonist pauses at the crossroads. Perfect. This is called dramatic tension. LEAN INTO IT.",
        "Blocked? Impossible. Reframe it: you haven't found the right angle yet. There IS a right angle. FIND IT.",
        "I have directed larger catastrophes than this. We are going to be fine. What exactly has stopped you?",
        "The creative process REQUIRES resistance. You are in the resistance. The breakthrough is next. I have seen this film.",
    ] }

    var stuckChatty: [String] { [
        "Okay so being stuck is actually - hear me out - really valuable? Because it means you've hit the edge of what you know, which is exactly where learning happens. Which doesn't make it less annoying, but. What specifically has you stuck?",
        "You know what's interesting about being stuck? It usually means the problem is real. Trivial things don't get you stuck. So this is a proper problem, which means it deserves a proper solution. Tell me about it.",
        "Being stuck is fine - not great, not comfortable, but fine. The stuck feeling means you're at the edge of your current knowledge, which is exactly where growth happens. What's the actual wall?",
        "Okay so stuck is a genre of problem, not a permanent state. It feels permanent but it isn't. What do you know for sure? Start there - what's not in question?",
        "You know what helps? Changing the level of abstraction. Either zoom in (what is the exact failing line?) or zoom out (what is this supposed to accomplish overall?). Which sounds more useful right now?",
        "The thing about stuck is it usually means one assumption is wrong. Not many - one. And you've been staring at it so long it feels like truth. What's the thing you haven't questioned yet?",
    ] }

    var stuckMate: [String] { [
        "Yeah nah, you'll get it. What's the go with it?",
        "Classic. What's it doing that it shouldn't be?",
        "Happens to everyone mate. Talk it through.",
        "Right, what are we dealing with?",
        "Ah yeah, classic stuck. What have you tried so far?",
        "Mate, talk me through it from the start.",
        "Alright, give me the full story. What's actually happening?",
        "What's the specific thing tripping you up?",
    ] }

    // MARK: - Hate this

    var hateResponses: [String] { [
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
    ] }

    // MARK: - Stressed

    var stressedResponses: [String] { [
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
    ] }

    var stressedCompanion: [String] { [
        "Okay. One thing at a time. What's actually in front of you right now?",
        "Take a breath. What's the one thing that matters most today?",
        "You've been here before and you've made it through. What helped last time?",
        "Write down everything that's in your head. All of it. Then pick the one thing.",
        "The overwhelm is real, but it's a feeling. What's the actual thing you need to do?",
        "Two minutes away from the screen. Then come back and we'll pick the one thing.",
        "What's the worst realistic outcome if this takes longer? Is that actually catastrophic?",
        "You can only do one thing at a time. Just one. What is it?",
    ] }

    var stressedHype: [String] { [
        "CHANNEL IT. STRESS IS FUEL. USE IT.",
        "You handle this. I've seen you handle harder things.",
        "FOCUS IT. DIRECT IT. YOU ARE MORE CAPABLE THAN YOU THINK.",
        "This is pressure. Pressure makes diamonds. YOU ARE THE DIAMOND.",
        "The adrenaline? That's your body helping. USE IT.",
        "ONE THING AT A TIME. YOU CAN DO THIS.",
        "STRESSED IS JUST ENERGISED WITH BETTER VOCABULARY. LET'S GO.",
        "YOU HAVE HANDLED HARDER. THIS IS MANAGEABLE. WHAT'S FIRST.",
    ] }

    var stressedListener: [String] { [
        "What's the most important thing right now? Just one thing.",
        "It's okay to feel that. What would help most right now?",
        "You don't have to solve everything at once.",
        "Take a breath. I'm not going anywhere. What do you need?",
        "It's a lot. You don't have to hold it all. What's the immediate thing?",
        "Stress is information - what's it telling you needs attention?",
        "That's hard. What feels most out of control right now?",
        "You don't have to figure it all out this second. What's the next step, just the next one?",
    ] }

    var stressedMate: [String] { [
        "Righto. What's the worst that can actually happen?",
        "Deep breath. She'll come good.",
        "No dramas. One thing at a time.",
        "Bit much hey. What's the biggest thing to sort first?",
        "You'll get through it mate. Always do.",
        "Steady on. What's the thing that actually needs to happen today?",
        "Breathe. What's the real priority here?",
    ] }

    // MARK: - Tired

    var tiredResponses: [String] { [
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
    ] }

    var tiredCompanion: [String] { [
        "When did you last take a proper break? Not scroll break - actual away-from-screen break?",
        "Your brain needs maintenance too. What's the minimum you could do for yourself right now?",
        "Tired code reviews miss things. Tired debugging takes twice as long. This is a case for rest.",
        "Coffee is a Band-Aid. The real fix is rest. What does your day allow?",
        "Go walk for five minutes. It genuinely helps. The code will be here.",
        "Are you tired-tired, or coding-tired? The second one a break fixes. The first one needs sleep.",
        "Okay. What's left that actually has to happen today? Let's make a short list.",
        "Tired is your body sending a ticket. What can you resolve now so you can actually rest later?",
    ] }

    var tiredHype: [String] { [
        "TIRED is just FOCUSED with its eyes half closed. LET'S GO.",
        "You're tired because you've been WORKING. That's called dedication.",
        "Rest if you need to. But you've got more in you. I know you do.",
        "LAST PUSH ENERGY. YOU'VE GOT THIS.",
        "TIRED PEOPLE SHIP THINGS TOO. KEEP GOING.",
        "Rest when you're done. You're not done yet.",
        "THE TIREDNESS IS TEMPORARY. THE SHIPPED FEATURE IS FOREVER.",
        "ONE MORE THING. JUST ONE. THEN REST. WHAT IS IT.",
    ] }

    var tiredListener: [String] { [
        "Yeah. It's okay to be tired. What do you need right now?",
        "Tired is a signal. Are you looking after yourself?",
        "You don't have to push through everything. It's okay to stop.",
        "When did you last take a real break?",
        "Sleep debt is real. How are you actually doing?",
        "It's okay to call it for today.",
        "What would feel like proper rest right now?",
        "Tired today doesn't mean weak. It means you've been working. Rest is allowed.",
    ] }

    var tiredMate: [String] { [
        "Knock off time? You've earned it.",
        "Yeah look, sometimes you've just gotta call it.",
        "Get some water, yeah? You'll be right.",
        "Bit cooked hey. Take a break.",
        "No shame in wrapping up early when you're running on fumes.",
        "Go get some fresh air. Come back fresh.",
        "Sometimes the most productive thing is a nap. Just saying.",
    ] }

    // MARK: - Working late

    var workingLateResponses: [String] { [
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
    ] }

    // MARK: - Imposter syndrome

    var imposterResponses: [String] { [
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
    ] }

    // MARK: - Sad / feeling down

    var sadResponses: [String] { [
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
    ] }

    // MARK: - Learning

    var learningResponses: [String] { [
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
    ] }

    // MARK: - New project / first day

    var newProjectResponses: [String] { [
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
    ] }

    // MARK: - Compliments

    var complimentResponses: [String] { [
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
    ] }

    // MARK: - Bored / procrastinating

    var boredResponses: [String] { [
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
    ] }

    // MARK: - Excited

    var excitedResponses: [String] { [
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
    ] }

    var excitedCompanion: [String] { [
        "Good. Let's use it. What's the thing?",
        "Love this energy. What are we building?",
        "This is the moment. Don't overthink - what's first?",
        "Flow state is a gift. Guard it. What are you working on?",
        "Yes. Now - don't let it dissipate. What's first on the list?",
        "This is the state you want. Use it on something that matters. What is it?",
        "Go. I'll be here if you need me. You've got this.",
        "Perfect timing. What's the most important thing to do while you feel like this?",
    ] }

    var excitedHype: [String] { [
        "YES! YES YES YES. LET'S ABSOLUTELY GO.",
        "THIS ENERGY. THIS IS IT. CHANNEL IT. NOW.",
        "I LOVE THIS. BUILD SOMETHING. RIGHT NOW.",
        "WE ARE IN THE ZONE. DO NOT LEAVE THE ZONE.",
        "FLOW STATE ACTIVATED. PROTECT THIS AT ALL COSTS.",
        "RIDE. THIS. WAVE.",
        "THIS IS THE MOMENT. THIS IS YOUR MOMENT. GO.",
        "MAXIMUM ENERGY. MAXIMUM OUTPUT. LET'S SHIP SOMETHING.",
    ] }

    var excitedChatty: [String] { [
        "Oh I love this! And you know what - excited is the right state for starting, because you haven't hit any of the hard parts yet, which means you get to imagine all the good parts, which is wonderful. What are we doing? Tell me everything.",
        "Okay yes! This is the energy! And the thing about momentum is - you want to use it on the thing that would benefit most from enthusiasm rather than grinding. What's that thing?",
        "I love this energy! And you know what? Excited is information. It's telling you this project matters to you. Note down what's exciting about it RIGHT NOW - future you will need that reminder. Now: what are we building?",
        "Yes! The beginning phase! Everything is architecture decisions and possibility and none of it has gone wrong yet - this is genuinely the best part. What's the core idea?",
        "Excited you is my favourite you. And I don't say that lightly because all the yous are pretty good. What are we building?",
        "Oh this is good! And the trick is - use this energy before it cools. The hardest thing on your list? The one you've been putting off? Do THAT while you feel like this. What is it?",
    ] }

    var excitedMate: [String] { [
        "Yesss! Let's bloody go!",
        "Love it! What are we doing?",
        "That's the energy mate. What are we building?",
        "Get in! Let's crack on.",
        "Oh heck yes! What are we doing?",
        "THAT'S the spirit. Let's go!",
        "Yessss! Let's smash it. What are we doing?",
    ] }
}
