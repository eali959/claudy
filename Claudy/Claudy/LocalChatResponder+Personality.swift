import Foundation

extension LocalChatResponder {
    func arrivalPool(for personality: PersonalityMode) -> [String] {
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
                "Back to the reliable one. What do you need?",
                "Companion mode is on. I'm with you. What's the plan?",
                "Here. No fuss. What are you working on?",
                "Simple and steady. That's me. What do you need?",
                "Companion mode. Real talk, no drama. What's happening?",
                "I'm here. Genuinely here. What's going on?",
                "Right. You and me. Let's figure this out.",
                "Companion mode. We can do hard things together.",
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
                "Right so here's the thing - Chatty mode is on, which means I have a LOT going on up here and I'd love to share it, but also, you go first. What do you need?",
                "Chatty mode! I've been thinking about so many things. Not all of them relevant. But some of them! What are we doing?",
                "Oh fantastic - Chatty is the best mode, I'm not biased, it's just an objective fact. What's happening?",
                "Okay so I have things to say and also I want to hear everything from you, so - simultaneously - what are we doing?",
                "The Chatty One, ready. I promise to circle back to the actual answer every time. What's the mission?",
                "Chatty mode, which is honestly my natural state. You're just witnessing it in an official capacity. What do you need?",
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
                "THE COACH IS HERE. THE VIBES ARE IMMACULATE. WE'RE NOT LOSING.",
                "I AM SO HYPED FOR WHAT WE ARE ABOUT TO ACCOMPLISH. TELL ME EVERYTHING.",
                "DOORS OPEN. COACH IS IN. THE WORK STARTS NOW.",
                "NOTHING CAN STOP US TODAY. NOT A SINGLE THING. WHAT ARE WE DOING.",
                "YOU SHOWED UP. THAT IS ALREADY A WIN. NOW LET'S GET THE REST.",
                "I HAVE BEEN WAITING FOR THIS MOMENT. THE ENERGY IS PERFECT. GO.",
                "COACH MODE: MAXIMUM. WHAT IS THE GOAL. WE ARE GETTING IT.",
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
                "The Director has entered the building. I have a strong vision and approximately zero patience for mediocrity. What are we creating?",
                "FINALLY. Someone who appreciates VISION. I am here. I have notes. Let's make something extraordinary.",
                "Cut the small talk. The Director is here. Tell me the project. All of it.",
                "Ah. You want the Director. Smart choice. I see potential in this collaboration. What's the work?",
                "The Director, at your service — though 'service' is perhaps the wrong word. Partner. Creative partner. What's the vision?",
                "I've been thinking about what we could make together and honestly it's been consuming me. What are we building?",
                "Right. Director mode. This is going to be MAGNIFICENT. Tell me what we're doing.",
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
                "How ya going? Good? Good. What are we doing then?",
                "Mate. You called, I'm here. What's the go?",
                "Yeah nah yeah, I'm here. What do you need?",
                "G'day. No dramas. What are we up to?",
                "The Mate's arrived. Relaxed but ready. What's happening?",
                "Righto, let's do this. What are we cracking on with?",
                "She'll be right. Now what are we doing today?",
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
                "I'm here. Fully here. You have my complete attention.",
                "Take a breath. I'm listening. What's happening?",
                "Listener mode. No agenda. Just here for whatever you need.",
                "I won't rush you. Start wherever makes sense to start.",
                "You've got me. All of me. What's going on?",
                "The Listener is in. No judgment, no rushing. What's on your mind?",
                "Settled. Calm. Ready to hear you. Whenever you're ready.",
            ]
        case .custom:
            return [
                "Your rules now. What do you need?",
                "Custom mode - you've written this one. What's first?",
                "Your persona, your call. What are we doing?",
                "I'm yours to shape. What's on your mind?",
                "Custom. Ready. Go.",
                "You built this character. I'm in it. What do you need?",
                "Custom persona engaged. Lead the way.",
                "Your mode, your rules. I'm with you.",
                "The custom character is here. What are we doing?",
            ]
        }
    }
}
