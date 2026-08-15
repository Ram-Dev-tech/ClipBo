import Foundation
import ClipBo

public struct ClassificationTests {
    public static func runAll() {
        print("  ▶ Running ClassificationTests...")
        let classifier = DefaultContentClassifier()

        // 1. Plain Prose / Text Tests (verify NO false code or URL classification)
        let prose1 = PasteboardPayload.text("Hello ClipBo")
        let res1 = classifier.classify(payload: prose1)
        assert(res1.type == .text, "Prose 'Hello ClipBo' should be text, got \(res1.type)")
        assert(res1.customMetadata["detectedLanguage"] == nil, "Prose should not have detectedLanguage")

        let prose2 = PasteboardPayload.text("The quick brown fox jumps over the lazy dog. It returned a value to the caller.")
        let res2 = classifier.classify(payload: prose2)
        assert(res2.type == .text, "Prose sentence should be text, got \(res2.type)")

        let prose3 = PasteboardPayload.text("We should meet tomorrow at 10 AM to discuss the roadmap and review the design.")
        let res3 = classifier.classify(payload: prose3)
        assert(res3.type == .text, "Meeting note should be text, got \(res3.type)")

        // 2. Unicode-Aware Emoji Classification Tests
        print("    ▶ Testing Unicode-aware emoji classification...")
        let emoji1 = PasteboardPayload.text("😀")
        let resEmoji1 = classifier.classify(payload: emoji1)
        assert(resEmoji1.customMetadata["isEmoji"] == "true", "Expected '😀' to be classified with isEmoji = true")

        let emoji2 = PasteboardPayload.text("😀😂🔥")
        let resEmoji2 = classifier.classify(payload: emoji2)
        assert(resEmoji2.customMetadata["isEmoji"] == "true", "Expected '😀😂🔥' to be classified with isEmoji = true")
        assert(resEmoji2.customMetadata["emojiCount"] == "3", "Expected emojiCount == 3")

        let emoji3 = PasteboardPayload.text("🚀🚀🚀")
        let resEmoji3 = classifier.classify(payload: emoji3)
        assert(resEmoji3.customMetadata["isEmoji"] == "true", "Expected '🚀🚀🚀' to be classified with isEmoji = true")

        let emojiHeart = PasteboardPayload.text("❤️")
        let resEmojiHeart = classifier.classify(payload: emojiHeart)
        assert(resEmojiHeart.customMetadata["isEmoji"] == "true", "Expected '❤️' to be classified with isEmoji = true")

        let emojiSkinTone = PasteboardPayload.text("👍🏽")
        let resEmojiSkinTone = classifier.classify(payload: emojiSkinTone)
        assert(resEmojiSkinTone.customMetadata["isEmoji"] == "true", "Expected '👍🏽' with skin tone to be isEmoji = true")

        let emojiZWJ = PasteboardPayload.text("👨‍💻")
        let resEmojiZWJ = classifier.classify(payload: emojiZWJ)
        assert(resEmojiZWJ.customMetadata["isEmoji"] == "true", "Expected '👨‍💻' ZWJ sequence to be isEmoji = true")

        let emojiFlag = PasteboardPayload.text("🇮🇳")
        let resEmojiFlag = classifier.classify(payload: emojiFlag)
        assert(resEmojiFlag.customMetadata["isEmoji"] == "true", "Expected flag '🇮🇳' to be isEmoji = true")

        let emojiRainbow = PasteboardPayload.text("🏳️‍🌈")
        let resEmojiRainbow = classifier.classify(payload: emojiRainbow)
        assert(resEmojiRainbow.customMetadata["isEmoji"] == "true", "Expected flag '🏳️‍🌈' to be isEmoji = true")

        // False-positive prose suppression (sentences with a single emoji MUST remain ordinary Text)
        let textWithEmoji1 = PasteboardPayload.text("Hello 😀")
        let resTextWithEmoji1 = classifier.classify(payload: textWithEmoji1)
        assert(resTextWithEmoji1.customMetadata["isEmoji"] == nil, "Sentence 'Hello 😀' should NOT have isEmoji = true")

        let textWithEmoji2 = PasteboardPayload.text("I love this app ❤️")
        let resTextWithEmoji2 = classifier.classify(payload: textWithEmoji2)
        assert(resTextWithEmoji2.customMetadata["isEmoji"] == nil, "Sentence 'I love this app ❤️' should NOT have isEmoji = true")
        print("      ✔ Unicode emoji classification & false-positive suppression verified")

        // 3. Isolated URL Tests
        let url1 = PasteboardPayload.text("https://github.com/apple/swift")
        let resUrl1 = classifier.classify(payload: url1)
        assert(resUrl1.type == .url, "GitHub URL should be URL, got \(resUrl1.type)")
        assert(resUrl1.urlDomain == "github.com", "Expected github.com domain, got \(resUrl1.urlDomain ?? "nil")")
        assert(resUrl1.customMetadata["siteType"] == "GitHub", "Expected GitHub siteType")

        let url2 = PasteboardPayload.text("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        let resUrl2 = classifier.classify(payload: url2)
        assert(resUrl2.type == .url, "YouTube URL should be URL, got \(resUrl2.type)")
        assert(resUrl2.urlDomain == "youtube.com", "Expected youtube.com domain, got \(resUrl2.urlDomain ?? "nil")")
        assert(resUrl2.customMetadata["siteType"] == "YouTube", "Expected YouTube siteType")

        let url3 = PasteboardPayload.text("http://example.com/api?user=123&active=true")
        let resUrl3 = classifier.classify(payload: url3)
        assert(resUrl3.type == .url, "HTTP API URL should be URL, got \(resUrl3.type)")
        assert(resUrl3.urlDomain == "example.com", "Expected example.com domain")

        // Embedded URL inside sentence (should remain TEXT)
        let embeddedUrl = PasteboardPayload.text("Check out https://github.com/apple/swift for the open source compiler.")
        let resEmbedded = classifier.classify(payload: embeddedUrl)
        assert(resEmbedded.type == .text, "Embedded URL in sentence should be text, got \(resEmbedded.type)")

        // 4. Code Classification Tests
        let swiftCode = PasteboardPayload.text("import SwiftUI\n\npublic func setupOverlay() -> Void {\n    panel.level = .floating\n}")
        let resSwift = classifier.classify(payload: swiftCode)
        assert(resSwift.type == .code, "Swift code should be code, got \(resSwift.type)")
        assert(resSwift.detectedLanguage == "Swift", "Expected Swift language, got \(resSwift.detectedLanguage ?? "nil")")

        let pythonCode = PasteboardPayload.text("def calculate_total(items):\n    return sum(item.price for item in items)\n\nprint(calculate_total([]))")
        let resPy = classifier.classify(payload: pythonCode)
        assert(resPy.type == .code, "Python code should be code, got \(resPy.type)")
        assert(resPy.detectedLanguage == "Python", "Expected Python language, got \(resPy.detectedLanguage ?? "nil")")

        let jsCode = PasteboardPayload.text("const fetchUsers = async () => {\n    const response = await fetch('/api/users');\n    console.log(response);\n};")
        let resJs = classifier.classify(payload: jsCode)
        assert(resJs.type == .code, "JS code should be code, got \(resJs.type)")
        assert(resJs.detectedLanguage == "JavaScript" || resJs.detectedLanguage == "TypeScript", "Expected JS/TS language")

        let jsonCode = PasteboardPayload.text("{\n  \"name\": \"ClipBo\",\n  \"version\": \"1.0.0\",\n  \"active\": true\n}")
        let resJson = classifier.classify(payload: jsonCode)
        assert(resJson.type == .code, "JSON should be code, got \(resJson.type)")
        assert(resJson.detectedLanguage == "JSON", "Expected JSON language, got \(resJson.detectedLanguage ?? "nil")")

        let sqlCode = PasteboardPayload.text("SELECT id, name, email FROM users WHERE active = 1 ORDER BY created_at DESC;")
        let resSql = classifier.classify(payload: sqlCode)
        assert(resSql.type == .code, "SQL should be code, got \(resSql.type)")
        assert(resSql.detectedLanguage == "SQL", "Expected SQL language, got \(resSql.detectedLanguage ?? "nil")")

        let htmlCode = PasteboardPayload.text("<div class=\"main-container\">\n  <h1>ClipBo Header</h1>\n</div>")
        let resHtml = classifier.classify(payload: htmlCode)
        assert(resHtml.type == .code, "HTML should be code, got \(resHtml.type)")
        assert(resHtml.detectedLanguage == "HTML", "Expected HTML language, got \(resHtml.detectedLanguage ?? "nil")")

        let cssCode = PasteboardPayload.text(".card-container {\n  margin: 12px;\n  padding: 8px;\n  display: flex;\n  background: #ffffff;\n}")
        let resCss = classifier.classify(payload: cssCode)
        assert(resCss.type == .code, "CSS should be code, got \(resCss.type)")
        assert(resCss.detectedLanguage == "CSS", "Expected CSS language, got \(resCss.detectedLanguage ?? "nil")")

        let shellCode = PasteboardPayload.text("git commit -m \"feat: implement smart classification engine\"")
        let resShell = classifier.classify(payload: shellCode)
        assert(resShell.type == .code, "Git command should be code, got \(resShell.type)")
        assert(resShell.detectedLanguage == "Shell", "Expected Shell language, got \(resShell.detectedLanguage ?? "nil")")

        // 5. Positive PROMPT Detection Tests (Phase 7)
        print("    ▶ Testing Positive PROMPT classification...")
        let prompt1 = PasteboardPayload.text("Act as a Python expert and explain how asyncio works.")
        let resPrompt1 = classifier.classify(payload: prompt1)
        assert(resPrompt1.type == .prompt, "Expected .prompt for 'Act as a Python expert', got \(resPrompt1.type)")
        assert(resPrompt1.detectedLanguage == "Python", "Expected Python detected language, got \(resPrompt1.detectedLanguage ?? "nil")")
        assert(resPrompt1.customMetadata["promptType"] == "coding", "Expected coding promptType")

        let prompt2 = PasteboardPayload.text("Write a Swift function that calculates Fibonacci numbers.")
        let resPrompt2 = classifier.classify(payload: prompt2)
        assert(resPrompt2.type == .prompt, "Expected .prompt for 'Write a Swift function...', got \(resPrompt2.type)")
        assert(resPrompt2.detectedLanguage == "Swift", "Expected Swift language in prompt")

        let prompt3 = PasteboardPayload.text("Create a detailed study plan for learning Rust.")
        let resPrompt3 = classifier.classify(payload: prompt3)
        assert(resPrompt3.type == .prompt, "Expected .prompt for 'Create a detailed study plan...'")
        assert(resPrompt3.detectedLanguage == "Rust")

        let prompt4 = PasteboardPayload.text("Explain this code step by step.")
        let resPrompt4 = classifier.classify(payload: prompt4)
        assert(resPrompt4.type == .prompt, "Expected .prompt for 'Explain this code...'")

        let prompt5 = PasteboardPayload.text("You are an expert UI designer. Design a macOS clipboard manager.")
        let resPrompt5 = classifier.classify(payload: prompt5)
        assert(resPrompt5.type == .prompt, "Expected .prompt for 'You are an expert UI designer...'")
        assert(resPrompt5.customMetadata["promptType"] == "roleplay")

        let prompt6 = PasteboardPayload.text("Generate a professional email for asking for leave.")
        let resPrompt6 = classifier.classify(payload: prompt6)
        assert(resPrompt6.type == .prompt, "Expected .prompt for 'Generate a professional email...'")
        assert(resPrompt6.customMetadata["promptType"] == "writing")

        let prompt7 = PasteboardPayload.text("Summarize the following article.")
        let resPrompt7 = classifier.classify(payload: prompt7)
        assert(resPrompt7.type == .prompt, "Expected .prompt for 'Summarize the following article.'")
        assert(resPrompt7.customMetadata["promptType"] == "summarization")

        let prompt8 = PasteboardPayload.text("Translate this paragraph into Hindi.")
        let resPrompt8 = classifier.classify(payload: prompt8)
        assert(resPrompt8.type == .prompt, "Expected .prompt for 'Translate this paragraph...'")
        assert(resPrompt8.customMetadata["promptType"] == "translation")

        let prompt9 = PasteboardPayload.text("Your task is to analyze this financial dataset.")
        let resPrompt9 = classifier.classify(payload: prompt9)
        assert(resPrompt9.type == .prompt, "Expected .prompt for 'Your task is to analyze...'")
        assert(resPrompt9.customMetadata["promptType"] == "analysis")

        // Structured prompt format
        let structuredPrompt = PasteboardPayload.text("Role:\nYou are a senior macOS engineer.\n\nTask:\nBuild a clean AppKit panel.\n\nRequirements:\nMust be resizable.")
        let resStructured = classifier.classify(payload: structuredPrompt)
        assert(resStructured.type == .prompt, "Expected .prompt for structured prompt format")
        assert(resStructured.customMetadata["promptType"] == "structured")
        print("      ✔ Positive PROMPT detection & metadata verified")

        // 6. PROMPT vs CODE Arbitration Tests
        print("    ▶ Testing PROMPT vs CODE arbitration & edge cases...")
        // Instruction containing code -> PROMPT
        let promptWithCode = PasteboardPayload.text("Write this Python code:\n\ndef hello():\n    print('hi')")
        let resPromptWithCode = classifier.classify(payload: promptWithCode)
        assert(resPromptWithCode.type == .prompt, "Instruction with code should be .prompt, got \(resPromptWithCode.type)")

        // Code containing comment with prompt words -> CODE
        let codeWithComment = PasteboardPayload.text("# Write a Python program\ndef hello():\n    print('hi')")
        let resCodeWithComment = classifier.classify(payload: codeWithComment)
        assert(resCodeWithComment.type == .code, "Pure source code with header comment should be .code, got \(resCodeWithComment.type)")

        // Pure Code snippets must strictly remain CODE
        let pureFunc = PasteboardPayload.text("func calculateTotal() -> Int {\n    return 42\n}")
        assert(classifier.classify(payload: pureFunc).type == .code, "func calculateTotal must be .code")

        let pureConst = PasteboardPayload.text("const app = () => {\n    console.log('hello');\n};")
        assert(classifier.classify(payload: pureConst).type == .code, "const app must be .code")

        let pureSelect = PasteboardPayload.text("SELECT * FROM users;")
        assert(classifier.classify(payload: pureSelect).type == .code, "SELECT query must be .code")
        print("      ✔ PROMPT vs CODE arbitration verified")

        // 7. TEXT False-Positive Protection Tests
        print("    ▶ Testing TEXT false-positive protection...")
        let text1 = PasteboardPayload.text("I want to create a new folder.")
        assert(classifier.classify(payload: text1).type == .text, "'I want to create a new folder.' must remain .text")

        let text2 = PasteboardPayload.text("Can you help me tomorrow?")
        assert(classifier.classify(payload: text2).type == .text, "'Can you help me tomorrow?' must remain .text")

        let text3 = PasteboardPayload.text("I need to write an email.")
        assert(classifier.classify(payload: text3).type == .text, "'I need to write an email.' must remain .text")

        let text4 = PasteboardPayload.text("Please explain this movie.")
        assert(classifier.classify(payload: text4).type == .text, "'Please explain this movie.' must remain .text")
        print("      ✔ TEXT false-positive protection verified")

        // 8. Color Metadata Tests
        let hexColor = PasteboardPayload.text("#FF5733")
        let resHex = classifier.classify(payload: hexColor)
        assert(resHex.type == .text, "Color #FF5733 should have type .text, got \(resHex.type)")
        assert(resHex.colorHex == "#FF5733", "Expected colorHex #FF5733, got \(resHex.colorHex ?? "nil")")

        let shortHex = PasteboardPayload.text("#FFF")
        let resShortHex = classifier.classify(payload: shortHex)
        assert(resShortHex.type == .text, "Color #FFF should have type .text")
        assert(resShortHex.colorHex == "#FFFFFF", "Expected #FFFFFF, got \(resShortHex.colorHex ?? "nil")")

        let rgbColor = PasteboardPayload.text("rgb(255, 0, 0)")
        let resRgb = classifier.classify(payload: rgbColor)
        assert(resRgb.type == .text)
        assert(resRgb.colorHex == "#FF0000", "Expected #FF0000, got \(resRgb.colorHex ?? "nil")")

        let notColor = PasteboardPayload.text("Issue #123 was resolved yesterday.")
        let resNotColor = classifier.classify(payload: notColor)
        assert(resNotColor.type == .text)
        assert(resNotColor.colorHex == nil, "Issue #123 should not be detected as colorHex")

        // 9. Image Classification
        let imgData = Data([0x89, 0x50, 0x4E, 0x47])
        let imgPayload = PasteboardPayload.image(data: imgData, width: 100, height: 100)
        let resImg = classifier.classify(payload: imgPayload)
        assert(resImg.type == ClipType.image, "Image payload should be classified as .image")

        print("  ✔ ClassificationTests passed")
    }
}
