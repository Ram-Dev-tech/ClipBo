import Foundation

/// Deterministic, offline, rule-based content classifier with Prompt detection and Prompt vs Code arbitration.
public final class DefaultContentClassifier: ContentClassifierProtocol, Sendable {
    public init() {}

    public func classify(payload: PasteboardPayload) -> ClipClassification {
        var baseMetadata = payload.customMetadata

        // 1. Image Priority
        if payload.type == .image || payload.imageData != nil {
            return ClipClassification(
                type: .image,
                confidence: 1.0,
                normalizedContent: payload.textContent,
                customMetadata: baseMetadata
            )
        }

        guard let rawText = payload.textContent, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ClipClassification(type: .text, confidence: 1.0, customMetadata: baseMetadata)
        }

        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        // If this payload is a Finder file reference, keep it as .text and preserve file metadata
        if payload.customMetadata["isFileURL"] == "true" || payload.fileURL != nil {
            return ClipClassification(
                type: .text,
                confidence: 1.0,
                normalizedContent: trimmed,
                customMetadata: baseMetadata
            )
        }

        // 2. High-Confidence Isolated Web URL Detection
        if let urlClassification = evaluateIsolatedURL(trimmed, rawText: rawText, baseMetadata: baseMetadata) {
            return urlClassification
        }

        // 3. Color Metadata Detection (Color remains .text, but extracts colorHex metadata)
        let detectedColor = extractColorHex(trimmed)
        if let color = detectedColor {
            baseMetadata["colorHex"] = color
        }

        // 4. Unicode Emoji Evaluation
        let emojiResult = DefaultContentClassifier.evaluateEmojiContent(trimmed)
        if emojiResult.isEmoji {
            baseMetadata["isEmoji"] = "true"
            baseMetadata["emojiCount"] = String(emojiResult.count)
            baseMetadata["emojiRatio"] = String(format: "%.2f", emojiResult.ratio)
        }

        // 5. Prompt Evaluation with Code Arbitration
        let promptResult = evaluatePrompt(trimmed, rawText: rawText, detectedColor: detectedColor, baseMetadata: baseMetadata)
        let codeResult = evaluateCode(trimmed, rawText: rawText, detectedColor: detectedColor, baseMetadata: baseMetadata)

        // Prompt vs Code Arbitration:
        // If both fire, decide based on whether prompt instruction dominates or pure source code syntax dominates
        if let prompt = promptResult, let code = codeResult {
            if isInstructionDominant(trimmed: trimmed) {
                return prompt
            } else {
                return code
            }
        } else if let prompt = promptResult {
            return prompt
        } else if let code = codeResult {
            return code
        }

        // 6. Default Fallback -> TEXT
        return ClipClassification(
            type: .text,
            confidence: 1.0,
            colorHex: detectedColor,
            normalizedContent: trimmed,
            customMetadata: baseMetadata
        )
    }

    // MARK: - Prompt Evaluation
    private func evaluatePrompt(_ trimmed: String, rawText: String, detectedColor: String?, baseMetadata: [String: String]) -> ClipClassification? {
        let lower = trimmed.lowercased()
        var metadata = baseMetadata

        // 1. Structural Prompt Headers Check (e.g. Role:\n Task:\n Requirements:\n)
        let structuralHeaders = ["role:", "task:", "context:", "requirements:", "constraints:", "output:", "instructions:", "instructions :", "goal:", "prompt:", "rules:"]
        var matchedHeaders = 0
        let lines = trimmed.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        for line in lines {
            for header in structuralHeaders {
                if line.hasPrefix(header) {
                    matchedHeaders += 1
                    break
                }
            }
        }

        let isStructuredPrompt = matchedHeaders >= 2

        // 2. Strong Persona / Roleplay Starters
        let personaStarters = [
            "act as", "you are an expert", "you are a senior", "you are a professional", "you are a helpful", "you are a native",
            "you are a world-class", "you are an experienced", "you are an ai", "pretend you are", "imagine you are", "roleplay as",
            "i want you to act as", "i want you to pretend"
        ]

        var isPersona = false
        for starter in personaStarters {
            if lower.hasPrefix(starter) {
                isPersona = true
                break
            }
        }

        // 3. Strong Direct Imperative Prompt Starters
        let imperativeStarters = [
            "write a ", "write an ", "write this ", "write the ", "write me ", "write code ", "write a function", "write a script", "write a python", "write a swift", "write a javascript", "write python ", "write swift ",
            "create a ", "create an ", "create this ", "create the ", "create a detailed", "create a function", "create a script",
            "generate a ", "generate an ", "generate this ", "generate the ", "generate code ", "generate a list", "generate a professional",
            "build a ", "build an ", "build this ", "develop a ", "develop an ", "design a ", "design an ", "design a modern",
            "summarize the ", "summarize this ", "summarise the ", "summarise this ", "summarize following",
            "explain this code", "explain how ", "explain the following", "explain this step", "explain step by step",
            "analyze this ", "analyze the ", "analyse this ", "analyse the ", "analyze following",
            "rewrite this ", "rewrite the ", "rewrite following",
            "translate this ", "translate the ", "translate following", "translate into ",
            "your task is to", "your role is to", "i want you to write", "i want you to create", "i want you to build"
        ]

        var isImperative = false
        for starter in imperativeStarters {
            if lower.hasPrefix(starter) {
                isImperative = true
                break
            }
        }

        // 4. Conversational / Task Request patterns with instruction substance
        let conversationalStarters = [
            "can you write ", "can you create ", "can you generate ", "can you explain ", "can you help me write ",
            "can you help me create ", "can you build ", "please write a ", "please create a ", "please generate a ",
            "please explain ", "please summarize ", "please translate "
        ]

        var isConversationalPrompt = false
        for starter in conversationalStarters {
            if lower.hasPrefix(starter) {
                isConversationalPrompt = true
                break
            }
        }

        // False Positive Protection:
        // Ordinary sentences like "I want to create a new folder", "Can you help me tomorrow?", "I need to write an email"
        // should NOT become prompts.
        let personalProseStarters = [
            "i want to create a new folder", "i want to create a folder", "can you help me tomorrow",
            "i need to write an email", "i need to create", "i want to make a cake", "please explain this movie"
        ]
        for prose in personalProseStarters {
            if lower.hasPrefix(prose) {
                return nil
            }
        }

        guard isStructuredPrompt || isPersona || isImperative || isConversationalPrompt else {
            return nil
        }

        // Determine Prompt Sub-Type and Language
        var promptType = "general"
        var detectedLang: String? = nil

        let languages: [(name: String, keywords: [String])] = [
            ("Python", ["python", "django", "flask", "numpy", "pandas", "fastapi"]),
            ("Swift", ["swift", "swiftui", "appkit", "uikit", "combine"]),
            ("JavaScript", ["javascript", "react", "nodejs", "node.js", "vue", "nextjs", "express.js"]),
            ("TypeScript", ["typescript", "tsconfig"]),
            ("Rust", ["rust", "cargo"]),
            ("Go", ["golang", "go code", "go function"]),
            ("C++", ["c++", "cpp"]),
            ("SQL", ["sql", "postgres", "postgresql", "mysql", "sqlite"]),
            ("HTML", ["html", "css", "tailwind"])
        ]

        let promptWords = Set(lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
        for lang in languages {
            for kw in lang.keywords {
                if kw.contains(" ") || kw.contains(".") {
                    if lower.contains(kw) {
                        detectedLang = lang.name
                        promptType = "coding"
                        break
                    }
                } else if promptWords.contains(kw) {
                    detectedLang = lang.name
                    promptType = "coding"
                    break
                }
            }
            if detectedLang != nil { break }
        }

        if isStructuredPrompt {
            promptType = "structured"
        } else if promptType == "general" {
            if isPersona {
                promptType = "roleplay"
            } else if lower.contains("summarize") || lower.contains("summarise") {
                promptType = "summarization"
            } else if lower.contains("translate") {
                promptType = "translation"
            } else if lower.contains("analyze") || lower.contains("analyse") {
                promptType = "analysis"
            } else if lower.contains("email") || lower.contains("letter") || lower.contains("essay") || lower.contains("article") || lower.contains("story") {
                promptType = "writing"
            }
        }

        metadata["promptType"] = promptType
        metadata["promptConfidence"] = "0.92"
        if let lang = detectedLang {
            metadata["detectedLanguage"] = lang
        }
        if let color = detectedColor {
            metadata["colorHex"] = color
        }

        return ClipClassification(
            type: .prompt,
            confidence: 0.92,
            detectedLanguage: detectedLang,
            colorHex: detectedColor,
            normalizedContent: rawText,
            customMetadata: metadata
        )
    }

    /// Determines if an ambiguous snippet is primarily an instruction (Prompt) or source code.
    private func isInstructionDominant(trimmed: String) -> Bool {
        let lower = trimmed.lowercased()

        // If the text starts with prompt verbs/instructions, it is primarily a prompt containing code
        let promptStarters = [
            "act as", "you are", "write ", "create ", "generate ", "develop ", "design ",
            "build ", "explain", "analyze", "analyse", "summarize", "summarise", "translate",
            "role:", "task:", "prompt:", "i want you to", "can you write", "please write"
        ]

        for starter in promptStarters {
            if lower.hasPrefix(starter) {
                return true
            }
        }

        // If the first line is pure source code (e.g. def, func, const, class, import) without prompt directive
        let firstLine = trimmed.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? ""
        if firstLine.hasPrefix("def ") || firstLine.hasPrefix("func ") || firstLine.hasPrefix("import ") ||
           firstLine.hasPrefix("const ") || firstLine.hasPrefix("package ") || firstLine.hasPrefix("class ") ||
           firstLine.hasPrefix("SELECT ") || firstLine.hasPrefix("public class") {
            return false
        }

        return false
    }

    // MARK: - Unicode Emoji Evaluation
    public static func isEmojiCharacter(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        guard let first = scalars.first else { return false }

        if first.properties.isEmojiPresentation {
            return true
        }

        if scalars.count >= 2 && scalars.allSatisfy({ (0x1F1E6...0x1F1FF).contains($0.value) }) {
            return true
        }

        if scalars.contains(where: { $0.value == 0xFE0F || $0.value == 0x200D || (0x1F3FB...0x1F3FF).contains($0.value) }) &&
           scalars.contains(where: { $0.properties.isEmoji }) {
            return true
        }

        if (0x1F300...0x1FAFF).contains(first.value) || (0x2600...0x27BF).contains(first.value) {
            return first.properties.isEmoji
        }

        return false
    }

    public static func evaluateEmojiContent(_ text: String) -> (isEmoji: Bool, count: Int, ratio: Double) {
        let nonWhitespaceChars = text.filter { !$0.isWhitespace && !$0.isNewline }
        guard !nonWhitespaceChars.isEmpty else {
            return (false, 0, 0.0)
        }

        var emojiCount = 0
        for char in nonWhitespaceChars {
            if isEmojiCharacter(char) {
                emojiCount += 1
            }
        }

        let totalCount = nonWhitespaceChars.count
        let ratio = Double(emojiCount) / Double(totalCount)
        let isPredominant = (emojiCount > 0) && (ratio >= 0.60 || (emojiCount == totalCount))

        return (isPredominant, emojiCount, ratio)
    }

    // MARK: - URL Evaluation
    private func evaluateIsolatedURL(_ trimmed: String, rawText: String, baseMetadata: [String: String]) -> ClipClassification? {
        guard !trimmed.contains("\n") && !trimmed.contains("\r") && !trimmed.contains(" ") else {
            return nil
        }

        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else {
            return nil
        }

        guard scheme == "http" || scheme == "https" || scheme == "ftp" else {
            return nil
        }

        let cleanDomain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        var metadata = baseMetadata
        metadata["urlDomain"] = cleanDomain
        metadata["urlScheme"] = scheme

        if cleanDomain.contains("youtube.com") || cleanDomain == "youtu.be" {
            metadata["siteType"] = "YouTube"
        } else if cleanDomain.contains("github.com") {
            metadata["siteType"] = "GitHub"
        }

        return ClipClassification(
            type: .url,
            confidence: 1.0,
            urlDomain: cleanDomain,
            normalizedContent: trimmed,
            customMetadata: metadata
        )
    }

    // MARK: - Color Hex Extraction
    private func extractColorHex(_ text: String) -> String? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let hexRegex = try? NSRegularExpression(pattern: "^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$", options: [])
        if let regex = hexRegex, regex.firstMatch(in: clean, options: [], range: NSRange(location: 0, length: clean.utf16.count)) != nil {
            if clean.count == 4 {
                let chars = Array(clean.dropFirst())
                return "#\(chars[0])\(chars[0])\(chars[1])\(chars[1])\(chars[2])\(chars[2])".uppercased()
            }
            return clean.uppercased()
        }

        if clean.lowercased().hasPrefix("rgb(") || clean.lowercased().hasPrefix("rgba(") {
            let components = clean.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).filter { !$0.isEmpty }
            if components.count >= 3,
               let r = Int(components[0]), let g = Int(components[1]), let b = Int(components[2]),
               r <= 255, g <= 255, b <= 255 {
                return String(format: "#%02X%02X%02X", r, g, b)
            }
        }

        return nil
    }

    // MARK: - Code Evaluation
    private func evaluateCode(_ trimmed: String, rawText: String, detectedColor: String?, baseMetadata: [String: String]) -> ClipClassification? {
        var metadata = baseMetadata

        // 1. JSON Evaluation
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if let data = trimmed.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data, options: [])) != nil {
                metadata["detectedLanguage"] = "JSON"
                if let color = detectedColor { metadata["colorHex"] = color }
                return ClipClassification(
                    type: .code,
                    confidence: 0.95,
                    detectedLanguage: "JSON",
                    colorHex: detectedColor,
                    normalizedContent: rawText,
                    customMetadata: metadata
                )
            }
        }

        // 2. SQL Evaluation
        let sqlKeywords = ["SELECT ", "FROM ", "WHERE ", "INSERT INTO ", "UPDATE ", "DELETE FROM ", "CREATE TABLE ", "JOIN ", "GROUP BY ", "ORDER BY "]
        let upperText = trimmed.uppercased()
        var sqlMatches = 0
        for keyword in sqlKeywords {
            if upperText.contains(keyword) {
                sqlMatches += 1
            }
        }
        if sqlMatches >= 2 {
            metadata["detectedLanguage"] = "SQL"
            if let color = detectedColor { metadata["colorHex"] = color }
            return ClipClassification(
                type: .code,
                confidence: 0.9,
                detectedLanguage: "SQL",
                colorHex: detectedColor,
                normalizedContent: rawText,
                customMetadata: metadata
            )
        }

        // 3. HTML Evaluation
        if (trimmed.contains("<html") || trimmed.contains("<!DOCTYPE") || (trimmed.contains("<div") && trimmed.contains("</div>")) || (trimmed.contains("<span") && trimmed.contains("</span>")) || (trimmed.contains("<p>") && trimmed.contains("</p>"))) {
            metadata["detectedLanguage"] = "HTML"
            if let color = detectedColor { metadata["colorHex"] = color }
            return ClipClassification(
                type: .code,
                confidence: 0.9,
                detectedLanguage: "HTML",
                colorHex: detectedColor,
                normalizedContent: rawText,
                customMetadata: metadata
            )
        }

        // 4. CSS Evaluation
        if trimmed.contains("{") && trimmed.contains("}") && (trimmed.contains("margin:") || trimmed.contains("padding:") || trimmed.contains("color:") || trimmed.contains("display:") || trimmed.contains("background:")) {
            metadata["detectedLanguage"] = "CSS"
            if let color = detectedColor { metadata["colorHex"] = color }
            return ClipClassification(
                type: .code,
                confidence: 0.9,
                detectedLanguage: "CSS",
                colorHex: detectedColor,
                normalizedContent: rawText,
                customMetadata: metadata
            )
        }

        // 5. Shell / Command Evaluation
        let shellPrefixes = ["#!/bin/bash", "#!/bin/sh", "#!/usr/bin/env", "sudo ", "git ", "npm ", "swift ", "brew ", "docker ", "cargo ", "kubectl "]
        for prefix in shellPrefixes {
            if trimmed.hasPrefix(prefix) {
                metadata["detectedLanguage"] = "Shell"
                if let color = detectedColor { metadata["colorHex"] = color }
                return ClipClassification(
                    type: .code,
                    confidence: 0.88,
                    detectedLanguage: "Shell",
                    colorHex: detectedColor,
                    normalizedContent: rawText,
                    customMetadata: metadata
                )
            }
        }

        // 6. Multi-token heuristic evaluation for Swift, Python, JS/TS, Rust, Go, C++
        var score = 0
        var detectedLang: String? = nil

        // Swift
        if trimmed.contains("import SwiftUI") || trimmed.contains("import Foundation") || trimmed.contains("@MainActor") || trimmed.contains("guard let ") || (trimmed.contains("func ") && (trimmed.contains("->") || trimmed.contains("public func") || trimmed.contains("private func"))) {
            score += 3
            detectedLang = "Swift"
        }

        // Python
        if (trimmed.contains("def ") && trimmed.contains(":")) || trimmed.contains("import numpy") || (trimmed.contains("from ") && trimmed.contains(" import ")) || trimmed.contains("if __name__ == '__main__':") || (trimmed.contains("print(") && trimmed.contains("def ")) {
            score += 3
            detectedLang = "Python"
        }

        // JavaScript / TypeScript
        if (trimmed.contains("const ") || trimmed.contains("let ")) && (trimmed.contains("=>") || trimmed.contains("console.log(") || trimmed.contains("export default") || trimmed.contains("async (") || trimmed.contains("interface ")) {
            score += 3
            detectedLang = trimmed.contains("interface ") || trimmed.contains(": string") || trimmed.contains(": number") ? "TypeScript" : "JavaScript"
        }

        // Rust
        if (trimmed.contains("fn ") && trimmed.contains("->")) || trimmed.contains("let mut ") || trimmed.contains("pub struct ") || trimmed.contains("impl ") {
            score += 3
            detectedLang = "Rust"
        }

        // Go
        if trimmed.contains("package main") || trimmed.contains("func main()") || trimmed.contains("fmt.Println") || (trimmed.contains("func (") && trimmed.contains(") ")) {
            score += 3
            detectedLang = "Go"
        }

        // C / C++
        if trimmed.contains("#include <") || trimmed.contains("int main(") || trimmed.contains("std::cout") {
            score += 3
            detectedLang = "C++"
        }

        // General code syntax markers
        if (trimmed.contains("class ") || trimmed.contains("struct ") || trimmed.contains("enum ")) && trimmed.contains("{") && trimmed.contains("}") {
            score += 2
        }

        if score < 3 {
            return nil
        }

        if let lang = detectedLang {
            metadata["detectedLanguage"] = lang
        }
        if let color = detectedColor {
            metadata["colorHex"] = color
        }

        return ClipClassification(
            type: .code,
            confidence: 0.85,
            detectedLanguage: detectedLang ?? "Code",
            colorHex: detectedColor,
            normalizedContent: rawText,
            customMetadata: metadata
        )
    }
}
