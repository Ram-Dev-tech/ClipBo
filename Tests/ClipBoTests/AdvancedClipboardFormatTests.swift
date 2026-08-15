import Cocoa
import ClipBo

public struct AdvancedClipboardFormatTests {
    public static func runAll() {
        print("  ▶ Running AdvancedClipboardFormatTests...")
        let reader = ClipboardReader()
        let classifier = DefaultContentClassifier()

        // -------------------------------------------------------------
        // 1. RTF Tests
        // -------------------------------------------------------------
        print("    ▶ Testing RTF extraction and normalization...")
        let pbRTF = NSPasteboard(name: NSPasteboard.Name("com.clipbo.test.rtf.\(UUID().uuidString)"))
        pbRTF.clearContents()
        
        let validRTFString = "{\\rtf1\\ansi\\deff0 {\\fonttbl{\\f0 Helvetica;}}\\f0\\fs24 Hello {\\b World} from RTF!}"
        if let rtfData = validRTFString.data(using: .utf8) {
            pbRTF.setData(rtfData, forType: .rtf)
            let payload = reader.read(from: pbRTF)
            assert(payload != nil, "Expected payload for valid RTF")
            assert(payload?.detectedFormat == "rtf", "Expected detectedFormat == 'rtf'")
            assert(payload?.textContent?.contains("Hello") == true, "Expected text to contain 'Hello'")
            assert(payload?.textContent?.contains("World") == true, "Expected text to contain 'World'")

            let classification = classifier.classify(payload: payload!)
            assert(classification.type == .text, "Expected .text classification for prose RTF")
            assert(classification.customMetadata["clipboardFormat"] == "rtf", "Expected clipboardFormat metadata")
        }

        // Test Empty / Malformed RTF
        let pbMalformedRTF = NSPasteboard(name: NSPasteboard.Name("com.clipbo.test.malformed_rtf.\(UUID().uuidString)"))
        pbMalformedRTF.clearContents()
        pbMalformedRTF.setData(Data([0x00, 0xFF, 0xFE, 0x12]), forType: .rtf)
        let malformedPayload = reader.read(from: pbMalformedRTF)
        // Should safely return nil or empty without crashing
        print("      ✔ Malformed RTF handled safely without crash (returned: \(malformedPayload == nil ? "nil" : "payload"))")

        // -------------------------------------------------------------
        // 2. HTML Tests
        // -------------------------------------------------------------
        print("    ▶ Testing HTML extraction and normalization...")
        let pbHTML = NSPasteboard(name: NSPasteboard.Name("com.clipbo.test.html.\(UUID().uuidString)"))
        pbHTML.clearContents()
        
        let validHTMLString = "<html><head><style>p { color: red; }</style></head><body><h1>ClipBo Heading</h1><p>Welcome to <strong>ClipBo</strong> clipboard.</p></body></html>"
        if let htmlData = validHTMLString.data(using: .utf8) {
            pbHTML.setData(htmlData, forType: .html)
            let payload = reader.read(from: pbHTML)
            assert(payload != nil, "Expected payload for valid HTML")
            assert(payload?.detectedFormat == "html", "Expected detectedFormat == 'html'")
            assert(payload?.textContent?.contains("ClipBo Heading") == true, "Expected text to contain 'ClipBo Heading'")
            assert(payload?.textContent?.contains("Welcome to ClipBo clipboard.") == true, "Expected stripped text")
            assert(payload?.textContent?.contains("<style>") == false, "Expected HTML tags to be stripped")

            let classification = classifier.classify(payload: payload!)
            assert(classification.type == .text, "Expected .text classification for prose HTML")
            assert(classification.customMetadata["clipboardFormat"] == "html", "Expected clipboardFormat metadata")
        }

        // Test Malformed HTML
        let pbMalformedHTML = NSPasteboard(name: NSPasteboard.Name("com.clipbo.test.malformed_html.\(UUID().uuidString)"))
        pbMalformedHTML.clearContents()
        let brokenHTML = "<div class='unclosed'><p>Broken HTML text without closing tags"
        if let brokenData = brokenHTML.data(using: .utf8) {
            pbMalformedHTML.setData(brokenData, forType: .html)
            let payload = reader.read(from: pbMalformedHTML)
            assert(payload != nil, "Malformed HTML should still extract readable text")
            assert(payload?.textContent?.contains("Broken HTML text") == true, "Expected readable text")
            print("      ✔ Malformed HTML handled safely without crash")
        }

        // -------------------------------------------------------------
        // 3. Finder File URL Tests
        // -------------------------------------------------------------
        print("    ▶ Testing Finder File URL extraction...")
        let pbFile = NSPasteboard(name: NSPasteboard.Name("com.clipbo.test.file.\(UUID().uuidString)"))
        pbFile.clearContents()
        
        let testFileURL = URL(fileURLWithPath: "/Users/test/Documents/Quarterly_Report_2026.pdf")
        pbFile.writeObjects([testFileURL as NSURL])
        
        let filePayload = reader.read(from: pbFile)
        assert(filePayload != nil, "Expected payload for Finder file URL")
        assert(filePayload?.detectedFormat == "fileURL", "Expected detectedFormat == 'fileURL'")
        assert(filePayload?.fileName == "Quarterly_Report_2026.pdf", "Expected fileName == 'Quarterly_Report_2026.pdf', got \(filePayload?.fileName ?? "nil")")
        assert(filePayload?.fileURL?.path == "/Users/test/Documents/Quarterly_Report_2026.pdf", "Expected path match")
        assert(filePayload?.customMetadata["isFileURL"] == "true", "Expected isFileURL == 'true'")
        assert(filePayload?.fileUTI != nil, "Expected fileUTI extracted")

        let fileClassification = classifier.classify(payload: filePayload!)
        assert(fileClassification.type == .text, "Finder file reference must be classified as .text (not web .url)")
        assert(fileClassification.customMetadata["fileName"] == "Quarterly_Report_2026.pdf", "Expected fileName in classification metadata")
        assert(fileClassification.customMetadata["isFileURL"] == "true", "Expected isFileURL in classification metadata")

        // -------------------------------------------------------------
        // 4. Single Clip from Multiple Representations
        // -------------------------------------------------------------
        print("    ▶ Testing single-clip creation from multi-format pasteboard...")
        let pbMulti = NSPasteboard(name: NSPasteboard.Name("com.clipbo.test.multi.\(UUID().uuidString)"))
        pbMulti.clearContents()
        pbMulti.setString("Plain text representation", forType: .string)
        if let rtf = "{\\rtf1\\ansi RTF representation}".data(using: .utf8) {
            pbMulti.setData(rtf, forType: .rtf)
        }
        if let html = "<p>HTML representation</p>".data(using: .utf8) {
            pbMulti.setData(html, forType: .html)
        }

        let multiPayload = reader.read(from: pbMulti)
        assert(multiPayload != nil, "Expected exactly one payload for multi-format pasteboard")
        print("      ✔ Multi-format pasteboard parsed into exactly one normalized payload (\(multiPayload?.detectedFormat ?? "nil"))")

        print("  ✔ AdvancedClipboardFormatTests passed")
    }
}
