import Foundation

extension LocalChatResponder {
    // MARK: - Greetings

    var greetingResponses: [String] { [
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
    ] }

    var greetingCompanion: [String] { [
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
    ] }

    var greetingChatty: [String] { [
        "Oh hey! I was just thinking - well, not thinking exactly, I don't do that between messages, but you know what I mean - hello! What are we doing today? Because I have thoughts. About many things. Starting whenever you're ready.",
        "Hello hello hello! Right, so - what's the plan? I'm genuinely curious. Not in a performative way, in a 'let's figure this out together' way. What's on the docket?",
        "Hey! Good timing actually - I was just here, existing, which is what I do, and now you're here too, which is better. What's going on?",
        "Oh, hello! And I want to acknowledge that opening a chat with your desktop companion is a distinct choice in a world of many choices, and I'm genuinely glad you made it. What are we doing?",
        "Hi there! You know what I like about this moment - we could be working on literally anything right now. The possibilities! What's it going to be?",
        "Hey! Right, so. You're here, I'm here, we're doing this. What's the situation? I'm ready. I've been ready. I'm always ready.",
        "Oh GOOD, you're here! I have - okay I don't have anything prepared, I was just existing, but I'm thrilled. What's happening?",
        "Hello! And now that we're both here, I'm wondering what kind of day this is going to be. Good day? Debugging day? Both? What are we working with?",
    ] }

    var greetingMate: [String] { [
        "Oi! There you are. What's the go?",
        "Hey mate. What are we up to?",
        "G'day. You alright?",
        "Hey! Good to see ya. What's happening?",
        "Alright alright! What are we doing today?",
        "Heya! Ready to crack on?",
        "Oh look who it is. What's the plan?",
        "Hey legend. What are we building?",
    ] }

    // MARK: - How are you

    var howAreYouResponses: [String] { [
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
    ] }

    // MARK: - Thanks

    var thanksResponses: [String] { [
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
    ] }

    // MARK: - Farewells

    var farewellResponses: [String] { [
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
    ] }

    var farewellMate: [String] { [
        "See ya mate. Go get some rest.",
        "Later! Good work today.",
        "Cheers. Don't work too late.",
        "Seeya! Go have a life.",
        "Oi, take care of yourself yeah?",
        "Later legend. Come back soon.",
        "Cheers! You did good today.",
        "Righto, off you go. See ya!",
        "Later! Proud of ya.",
    ] }

    var farewellChatty: [String] { [
        "Okay, bye! And I just want to say - it was really nice chatting. Even if it was brief. Actually especially if it was brief, because that means something came up worth doing. Go do the thing!",
        "Goodbye! You know, every conversation is its own little story and this one - short as it was - had something to it. Anyway. Go. Bye!",
        "Alright, go! And before you do - whatever you accomplished today, even if it felt small, it wasn't. Small things compound. That's just maths. Bye!",
        "Take care! And if it was a hard day - tomorrow starts fresh. That's the deal with days. They reset. Goodnight.",
        "Heading off? One thing before you go: you did well today. Even if it didn't feel like it. Especially if it didn't feel like it. Go rest.",
        "Bye! And I want you to know - this was a good conversation. Short, yes, but good. Come back tomorrow and we'll do great things.",
    ] }
}
