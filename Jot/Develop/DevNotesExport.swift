import Foundation
import UIKit

/// Turns change notes into a shareable PDF or text file.
@MainActor
enum DevNotesExport {
    enum Format {
        case pdf, text

        var fileExtension: String { self == .pdf ? "pdf" : "txt" }
    }

    /// One note, flattened so export doesn't hold SwiftData objects.
    struct Entry {
        let text: String
        let category: DevNote.Category
        let screen: String?
        let appVersion: String
        let createdAt: Date
        let duration: Double
        let isDone: Bool

        init(_ note: DevNote) {
            text = note.text
            category = note.category
            screen = note.screen
            appVersion = note.appVersion
            createdAt = note.createdAt
            duration = note.duration
            isDone = note.isDone
        }
    }

    /// Writes the export to a temporary file and returns its URL.
    static func write(_ notes: [DevNote], format: Format, now: Date = .now) throws -> URL {
        let entries = notes.sorted { $0.createdAt < $1.createdAt }.map(Entry.init)
        let stamp = now.formatted(.iso8601.year().month().day())
        let url = URL.temporaryDirectory.appending(path: "Jot change notes \(stamp).\(format.fileExtension)")
        switch format {
        case .text: try text(entries, now: now).write(to: url, atomically: true, encoding: .utf8)
        case .pdf: try pdf(entries, now: now).write(to: url)
        }
        return url
    }

    // MARK: Structure

    private struct Section {
        let title: String
        let entries: [Entry]
    }

    /// Open notes grouped by category (bugs first), then done notes.
    private static func sections(_ entries: [Entry]) -> [Section] {
        var sections = DevNote.Category.allCases.compactMap { category -> Section? in
            let matching = entries.filter { !$0.isDone && $0.category == category }
            return matching.isEmpty ? nil : Section(title: category.plural, entries: matching)
        }
        let done = entries.filter(\.isDone)
        if !done.isEmpty { sections.append(Section(title: "Done", entries: done)) }
        return sections
    }

    private static func summary(_ entries: [Entry], now: Date) -> String {
        let open = entries.count { !$0.isDone }
        let device = "iOS \(UIDevice.current.systemVersion)"
        return "Exported \(now.formatted(date: .abbreviated, time: .shortened)) · Jot \(Bundle.main.jotVersion) · \(device) · \(open) open of \(entries.count)"
    }

    private static func meta(_ entry: Entry) -> String {
        var parts: [String] = []
        if entry.isDone { parts.append(entry.category.label) }
        if let screen = entry.screen { parts.append("Screen: \(screen)") }
        parts.append(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
        parts.append("v\(entry.appVersion)")
        return parts.joined(separator: " · ")
    }

    private static func body(_ entry: Entry) -> String {
        entry.text.isEmpty ? "(No words caught; listen to the recording in Jot.)" : entry.text
    }

    // MARK: Text

    /// Plain text in Markdown style, so it reads well anywhere and pastes cleanly.
    static func text(_ entries: [Entry], now: Date = .now) -> String {
        var lines = ["# Jot change notes", "", summary(entries, now: now)]
        if entries.isEmpty {
            lines += ["", "No notes yet."]
        }
        for section in sections(entries) {
            lines += ["", "## \(section.title) (\(section.entries.count))", ""]
            for (index, entry) in section.entries.enumerated() {
                let box = entry.isDone ? "[x]" : "[ ]"
                let indent = String(repeating: " ", count: "\(index + 1). ".count)
                let textLines = body(entry).components(separatedBy: .newlines)
                lines.append("\(index + 1). \(box) \(textLines[0])")
                lines += textLines.dropFirst().map { indent + $0 }
                lines.append(indent + meta(entry))
                lines.append("")
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }

    // MARK: PDF

    static func pdf(_ entries: [Entry], now: Date = .now) -> Data {
        let content = attributed(entries, now: now)
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)   // US Letter
        let margin: CGFloat = 54
        let textRect = page.insetBy(dx: margin, dy: margin)

        let setter = CTFramesetterCreateWithAttributedString(content as CFAttributedString)
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: {
            let format = UIGraphicsPDFRendererFormat()
            format.documentInfo = [kCGPDFContextTitle as String: "Jot change notes", kCGPDFContextCreator as String: "Jot"]
            return format
        }())

        return renderer.pdfData { context in
            var location = 0
            var pageNumber = 1
            repeat {
                context.beginPage()
                let cg = context.cgContext
                // Core Text draws bottom-up; flip just for the text.
                cg.saveGState()
                cg.textMatrix = .identity
                cg.translateBy(x: 0, y: page.height)
                cg.scaleBy(x: 1, y: -1)
                let flipped = CGRect(x: textRect.minX, y: page.height - textRect.maxY, width: textRect.width, height: textRect.height)
                let frame = CTFramesetterCreateFrame(setter, CFRange(location: location, length: 0), CGPath(rect: flipped, transform: nil), nil)
                CTFrameDraw(frame, cg)
                cg.restoreGState()

                let footer = "Jot change notes · page \(pageNumber)" as NSString
                footer.draw(at: CGPoint(x: margin, y: page.height - margin / 2 - 6), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 9),
                    .foregroundColor: UIColor.gray,
                ])

                let visible = CTFrameGetVisibleStringRange(frame)
                guard visible.length > 0 else { break }
                location += visible.length
                pageNumber += 1
            } while location < content.length
        }
    }

    private static func attributed(_ entries: [Entry], now: Date) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let ink = UIColor(white: 0.08, alpha: 1)
        let muted = UIColor(white: 0.45, alpha: 1)
        let accent = UIColor(red: 1, green: 0.42, blue: 0.21, alpha: 1)   // brand orange

        func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
        }
        func paragraph(spacingBefore: CGFloat = 0, after: CGFloat = 0, indent: CGFloat = 0, firstLine: CGFloat = 0) -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacingBefore = spacingBefore
            style.paragraphSpacing = after
            style.firstLineHeadIndent = firstLine
            style.headIndent = indent
            style.lineSpacing = 2
            return style
        }
        func add(_ string: String, _ attributes: [NSAttributedString.Key: Any]) {
            result.append(NSAttributedString(string: string, attributes: attributes))
        }

        add("Jot change notes\n", [.font: rounded(26, .heavy), .foregroundColor: ink, .paragraphStyle: paragraph(after: 4)])
        add(summary(entries, now: now) + "\n", [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: muted, .paragraphStyle: paragraph(after: 10)])

        if entries.isEmpty {
            add("No notes yet.\n", [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: ink])
        }

        for section in sections(entries) {
            add("\(section.title.uppercased())  \(section.entries.count)\n", [
                .font: rounded(12, .bold), .foregroundColor: accent, .kern: 1.2,
                .paragraphStyle: paragraph(spacingBefore: 16, after: 8),
            ])
            for (index, entry) in section.entries.enumerated() {
                let number = "\(index + 1).  "
                let indent = (number as NSString).size(withAttributes: [.font: rounded(12, .bold)]).width
                add(number, [.font: rounded(12, .bold), .foregroundColor: entry.isDone ? muted : ink, .paragraphStyle: paragraph(indent: indent)])
                var textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12), .foregroundColor: entry.isDone ? muted : ink,
                    .paragraphStyle: paragraph(indent: indent),
                ]
                if entry.isDone { textAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
                add(body(entry) + "\n", textAttributes)
                add(meta(entry) + "\n", [
                    .font: UIFont.systemFont(ofSize: 9), .foregroundColor: muted,
                    .paragraphStyle: paragraph(after: 10, indent: indent, firstLine: indent),
                ])
            }
        }
        return result
    }
}
