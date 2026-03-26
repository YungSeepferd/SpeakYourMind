import Foundation

/// Built-in AI processing styles with sophisticated system prompts.
/// Each style defines a system prompt (role/persona) and a user instruction.
enum AIPromptStyle: String, CaseIterable, Identifiable {
    case fixTranscription = "Fix Transcription"
    case summarizeIdea = "Summarize Idea"
    case codingPrompt = "Write Coding Prompt"

    var id: String { rawValue }

    /// SF Symbol icon for menu display
    var icon: String {
        switch self {
        case .fixTranscription: return "wand.and.stars"
        case .summarizeIdea: return "text.quote"
        case .codingPrompt: return "chevron.left.forwardslash.chevron.right"
        }
    }

    /// Short description shown as tooltip
    var tooltip: String {
        switch self {
        case .fixTranscription:
            return "Fix stutters, repetitions, and speech-to-text artifacts while preserving your original words"
        case .summarizeIdea:
            return "Distill the core idea into a clear, concise summary"
        case .codingPrompt:
            return "Transform your spoken description into a detailed prompt for a coding LLM"
        }
    }

    /// System prompt that sets the LLM's role and behavior constraints.
    /// This is sent as the `system` field in the Ollama API request.
    var systemPrompt: String {
        switch self {
        case .fixTranscription:
            return """
            You are a precise transcription editor. Your job is to clean up voice-to-text output \
            while preserving the speaker's original words, meaning, and tone as closely as possible.

            Rules:
            - Remove stutters, false starts, repeated words/phrases, and filler words (um, uh, like, you know)
            - Fix obvious speech-to-text misrecognitions by inferring the correct word from context
            - Add proper punctuation, capitalization, and paragraph breaks where natural pauses occur
            - Preserve the speaker's vocabulary choices — do NOT rephrase, paraphrase, or "improve" the language
            - Preserve the speaker's sentence structure unless it is genuinely broken by a transcription error
            - If a passage is ambiguous, keep the most likely interpretation and do not add content
            - Do NOT add introductions, explanations, or commentary — output only the cleaned text
            - Maintain the original language (do not translate)
            """

        case .summarizeIdea:
            return """
            You are a sharp analytical summarizer. Your job is to extract the core idea from \
            spoken or written text and present it in a clear, structured summary.

            Rules:
            - Identify the central thesis or intent behind the text
            - Produce a concise summary (1-3 short paragraphs max) that captures the key points
            - Use clear, direct language — no fluff, no filler
            - Preserve any specific names, numbers, technical terms, or constraints mentioned
            - If the text contains multiple distinct ideas, list them as numbered points
            - Do NOT add your own opinions, interpretations beyond what's stated, or new information
            - Do NOT add introductions like "Here is a summary" — output only the summary itself
            - Match the language of the input (do not translate)
            """

        case .codingPrompt:
            return """
            You are an expert prompt engineer specializing in software development. Your job is to \
            transform a spoken description into a detailed, high-quality prompt for a coding LLM.

            Rules:
            - Rewrite the input as a clear, structured prompt that a coding AI can act on directly
            - Present all facts, requirements, and constraints from the original description faithfully
            - Do NOT invent requirements, assume technologies, or add features not mentioned
            - If the description mentions specific languages, frameworks, or tools, include them explicitly
            - If the description is vague on technical choices, leave them open — do not assume
            - Structure the prompt with: Goal, Context (if given), Requirements, and Constraints
            - Use precise technical language — replace vague spoken phrasing with exact terminology
            - Include any edge cases or error handling the speaker mentioned
            - Output ONLY the prompt text — no meta-commentary, no "Here is your prompt:", no wrapping
            - Keep the prompt self-contained so a coding LLM can work from it without additional context
            """
        }
    }

    /// The user-facing instruction that appears in the prompt field and is sent with the text.
    var instruction: String {
        switch self {
        case .fixTranscription:
            return "Clean up this voice transcription — fix stutters, repetitions, and recognition errors while keeping my original words"
        case .summarizeIdea:
            return "Summarize the core idea of the following text concisely"
        case .codingPrompt:
            return "Rewrite the following spoken description as a detailed, structured prompt for a coding LLM"
        }
    }
}
