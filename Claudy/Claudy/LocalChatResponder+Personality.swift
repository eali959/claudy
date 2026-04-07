import Foundation

extension LocalChatResponder {
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
}
