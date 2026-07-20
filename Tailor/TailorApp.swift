import SwiftUI

@main
struct TailorApp: App {
    private let container: AppContainer

    init() {
        // UI automation must exercise the same feature flow without reaching
        // Photos, StoreKit, or a persisted user archive. The app remains on
        // production services for every normal launch.
        #if DEBUG
        container = ProcessInfo.processInfo.arguments.contains("-uiTesting")
            ? AppContainer.demo
            : AppContainer.makeProduction()
        #else
        container = AppContainer.makeProduction()
        #endif
    }

    var body: some Scene {
        WindowGroup { MilestoneRootView().environmentObject(container) }
    }
}

enum AppRoute: Int, CaseIterable, Hashable {
    case welcome, privacy, profile, references, scan, confirm, timeline, chapter, editor, preview, purchase, export, archive
}

struct DemoChapter: Identifiable {
    let id = UUID()
    var year: String
    var title: String
    var image: String
    var count: Int
}

private struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var step: AppRoute = .welcome
    @State private var petName = "Milo"
    @State private var species = "Dog"
    @State private var selectedReferences = 3
    @State private var scanProgress = 0.0
    @State private var purchased = false
    @State private var selectedStyle = "Warm Paper"
    @State private var chapters = [
        DemoChapter(year: "2017", title: "The beginning", image: "pawprint.fill", count: 36),
        DemoChapter(year: "2018–2020", title: "Days together", image: "leaf.fill", count: 184),
        DemoChapter(year: "2021–2024", title: "A life remembered", image: "sun.max.fill", count: 72)
    ]

    var body: some View {
        ZStack {
            TailorTheme.paper.ignoresSafeArea()
            Group {
                switch step {
                case .welcome: WelcomeView(next: advance)
                case .privacy: PrivacyView(next: advance, back: retreat)
                case .profile: ProfileView(name: $petName, species: $species, next: advance, back: retreat)
                case .references: ReferencesView(count: $selectedReferences, next: advance, back: retreat)
                case .scan: ScanView(progress: $scanProgress, next: advance, back: retreat)
                case .confirm: ConfirmView(name: petName, next: advance, back: retreat)
                case .timeline: TimelineView(name: petName, chapters: $chapters, edit: { step = .chapter }, next: advance, back: retreat)
                case .chapter: ChapterView(chapter: $chapters[0], back: { step = .timeline }, next: { step = .editor })
                case .editor: PreviewView(style: $selectedStyle, purchased: purchased, next: { step = .preview }, back: retreat)
                case .preview: PreviewView(style: $selectedStyle, purchased: purchased, next: { step = purchased ? .export : .purchase }, back: retreat)
                case .purchase: PurchaseView(purchase: { purchased = true; step = .export }, back: retreat)
                case .export: ExportView(name: petName, done: { step = .archive }, back: retreat)
                case .archive: ArchiveView(name: petName, restart: { step = .welcome })
                }
            }
            .animation(.easeInOut(duration: 0.28), value: step)
        }
    }

    private func advance() {
        guard let next = AppRoute(rawValue: step.rawValue + 1) else { return }
        container.router.navigate(to: next)
        step = next
    }
    private func retreat() {
        guard let previous = AppRoute(rawValue: step.rawValue - 1) else { return }
        container.router.navigate(to: previous)
        step = previous
    }
}

private enum TailorTheme {
    static let paper = Color(red: 0.97, green: 0.94, blue: 0.87)
    static let ink = Color(red: 0.08, green: 0.20, blue: 0.16)
    static let clay = Color(red: 0.71, green: 0.30, blue: 0.18)
    static let mist = Color(red: 0.84, green: 0.87, blue: 0.79)
}

private struct Screen<Content: View>: View {
    let title: String
    let eyebrow: String
    let back: (() -> Void)?
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let back { Button(action: back) { Image(systemName: "chevron.left").fontWeight(.bold) }.foregroundStyle(TailorTheme.ink) }
                Spacer()
                Text(eyebrow.uppercased()).font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(TailorTheme.clay)
            }.padding(.horizontal, 24).padding(.top, 18)
            ScrollView(showsIndicators: false) { VStack(alignment: .leading, spacing: 22) { Text(title).font(.system(size: 38, weight: .semibold, design: .serif)).foregroundStyle(TailorTheme.ink); content }.padding(24) }
        }
    }
}

private struct PrimaryButton: View {
    let title: String; let action: () -> Void
    var body: some View { Button(action: action) { HStack { Text(title); Spacer(); Image(systemName: "arrow.right") }.fontWeight(.bold).padding(18).background(TailorTheme.ink).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 18)) } }
}

private struct WelcomeView: View {
    let next: () -> Void
    var body: some View { Screen(title: "Keep a life close.", eyebrow: "Tailor", back: nil) {
        ZStack { RoundedRectangle(cornerRadius: 30).fill(LinearGradient(colors: [TailorTheme.ink, TailorTheme.clay], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(height: 300); VStack(spacing: 14) { Image(systemName: "heart.fill").font(.system(size: 68)).foregroundStyle(TailorTheme.paper); Text("Made from the moments\nyou already have.").font(.title3.weight(.medium)).multilineTextAlignment(.center).foregroundStyle(.white) } }
        Text("Tailor helps you gather real photographs into a private life archive. Nothing leaves your iPhone.").font(.body).foregroundStyle(TailorTheme.ink.opacity(0.76))
        PrimaryButton(title: "Create a life archive", action: next)
        Text("How we protect your photos").font(.footnote.weight(.semibold)).foregroundStyle(TailorTheme.clay).frame(maxWidth: .infinity)
    } }
}

private struct PrivacyView: View {
    let next: () -> Void; let back: () -> Void
    var body: some View { Screen(title: "Your photos stay yours.", eyebrow: "Privacy", back: back) {
        ForEach([( "iphone", "Processed on this device"), ("lock.fill", "Never uploaded as an album"), ("checkmark.seal.fill", "Only photos you approve are used")], id: \.1) { item in HStack(spacing: 16) { Image(systemName: item.0).frame(width: 36).font(.title2).foregroundStyle(TailorTheme.clay); Text(item.1).font(.headline).foregroundStyle(TailorTheme.ink) }.padding().background(.white.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 18)) }
        Text("You can grant full access, select a few photos, or continue with manual selection.").foregroundStyle(TailorTheme.ink.opacity(0.7))
        PrimaryButton(title: "Allow photo access", action: next)
    } }
}

private struct ProfileView: View {
    @Binding var name: String; @Binding var species: String; let next: () -> Void; let back: () -> Void
    var body: some View { Screen(title: "Tell us about them.", eyebrow: "Profile", back: back) {
        Picker("Species", selection: $species) { Text("Dog").tag("Dog"); Text("Cat").tag("Cat") }.pickerStyle(.segmented)
        TextField("Their name", text: $name).textFieldStyle(.roundedBorder).font(.title3)
        HStack { YearField(title: "Came home", value: "2017"); YearField(title: "Left us", value: "2024") }
        Text("Years shape the timeline. They do not need to be exact.").font(.footnote).foregroundStyle(TailorTheme.ink.opacity(0.65))
        PrimaryButton(title: "Choose reference photos", action: next)
    } }
}
private struct YearField: View { let title: String; let value: String; var body: some View { VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(TailorTheme.ink.opacity(0.65)); Text(value).font(.title3.weight(.semibold)).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius: 12)) } } }

private struct ReferencesView: View {
    @Binding var count: Int; let next: () -> Void; let back: () -> Void
    var body: some View { Screen(title: "Help us recognize them.", eyebrow: "Reference photos", back: back) {
        Text("Choose 3–5 clear photos from different ages and angles.").foregroundStyle(TailorTheme.ink.opacity(0.75))
        HStack(spacing: 12) { ForEach(0..<5, id: \.self) { index in Button { count = max(count, index + 1) } label: { ZStack { RoundedRectangle(cornerRadius: 16).fill(index < count ? TailorTheme.mist : .white.opacity(0.55)); Image(systemName: index < count ? "photo.fill" : "plus").font(.title2).foregroundStyle(TailorTheme.ink) }.frame(height: 92) } } }
        Text("\(count) of 3 minimum selected").font(.footnote.weight(.medium)).foregroundStyle(count >= 3 ? TailorTheme.ink : TailorTheme.clay)
        PrimaryButton(title: "Start looking", action: next).disabled(count < 3)
    } }
}

private struct ScanView: View {
    @Binding var progress: Double; let next: () -> Void; let back: () -> Void
    var body: some View { Screen(title: "Looking through the moments.", eyebrow: "On-device scan", back: back) {
        VStack(spacing: 18) { ZStack { Circle().stroke(TailorTheme.mist, lineWidth: 16); Circle().trim(from: 0, to: max(progress, 0.08)).stroke(TailorTheme.clay, style: StrokeStyle(lineWidth: 16, lineCap: .round)).rotationEffect(.degrees(-90)); Text("\(Int(progress * 100))%").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(TailorTheme.ink) }.frame(width: 180, height: 180)
            Text(progress == 0 ? "Ready to check your selected library." : "Checking photos safely on this device.").multilineTextAlignment(.center).foregroundStyle(TailorTheme.ink.opacity(0.72))
        }.frame(maxWidth: .infinity).padding(.vertical, 20)
        PrimaryButton(title: progress < 1 ? "Scan now" : "Review matches", action: { if progress < 1 { withAnimation(.easeInOut(duration: 1.1)) { progress = 1 } } else { next() } })
        Text("Pause and come back anytime. Your progress is kept.").font(.footnote).foregroundStyle(TailorTheme.ink.opacity(0.6))
    } }
}

private struct ConfirmView: View {
    let name: String; let next: () -> Void; let back: () -> Void
    var body: some View { Screen(title: "We found 184 moments.", eyebrow: "Review", back: back) {
        Text("Choose what belongs in \(name)’s archive. High-confidence photos are selected, never locked.").foregroundStyle(TailorTheme.ink.opacity(0.72))
        ForEach([( "High confidence", 126, TailorTheme.ink), ("Needs your confirmation", 42, TailorTheme.clay), ("Excluded", 16, Color.gray)], id: \.0) { group in HStack { VStack(alignment: .leading) { Text(group.0).font(.headline); Text("\(group.1) photos").font(.caption) }; Spacer(); Image(systemName: "chevron.right") }.padding().background(group.2.opacity(0.12)).foregroundStyle(TailorTheme.ink).clipShape(RoundedRectangle(cornerRadius: 18)) }
        PrimaryButton(title: "Create timeline", action: next)
    } }
}

private struct TimelineView: View {
    let name: String; @Binding var chapters: [DemoChapter]; let edit: () -> Void; let next: () -> Void; let back: () -> Void
    var body: some View { Screen(title: "\(name)’s life, in moments.", eyebrow: "Timeline", back: back) {
        Text("Made from photos you chose. You can change every chapter.").foregroundStyle(TailorTheme.ink.opacity(0.72))
        ForEach(chapters) { chapter in Button(action: edit) { HStack(spacing: 16) { Image(systemName: chapter.image).font(.title2).foregroundStyle(TailorTheme.clay).frame(width: 48, height: 60).background(TailorTheme.mist).clipShape(RoundedRectangle(cornerRadius: 14)); VStack(alignment: .leading) { Text(chapter.year).font(.caption.weight(.bold)).foregroundStyle(TailorTheme.clay); Text(chapter.title).font(.headline).foregroundStyle(TailorTheme.ink); Text("\(chapter.count) selected photos").font(.caption).foregroundStyle(TailorTheme.ink.opacity(0.6)) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(TailorTheme.ink.opacity(0.5)) }.padding(10).background(.white.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 18)) } }
        PrimaryButton(title: "Edit album", action: next)
    } }
}

private struct ChapterView: View {
    @Binding var chapter: DemoChapter; let back: () -> Void; let next: () -> Void
    var body: some View { Screen(title: "Edit this chapter.", eyebrow: chapter.year, back: back) {
        TextField("Chapter title", text: $chapter.title).textFieldStyle(.roundedBorder).font(.title3)
        TextEditor(text: .constant("A few quiet pages made from the days you chose.")).frame(height: 90).padding(8).background(.white.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 14))
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) { ForEach(0..<9, id: \.self) { _ in RoundedRectangle(cornerRadius: 12).fill(TailorTheme.mist).frame(height: 88).overlay(Image(systemName: "photo").foregroundStyle(TailorTheme.ink.opacity(0.65))) } }
        PrimaryButton(title: "Save chapter", action: next)
    } }
}

private struct PreviewView: View {
    @Binding var style: String; let purchased: Bool; let next: () -> Void; let back: () -> Void
    var body: some View { Screen(title: "A book to keep.", eyebrow: "Preview", back: back) {
        Picker("Style", selection: $style) { ForEach(["Warm Paper", "Quiet Night", "Field Notes"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
        RoundedRectangle(cornerRadius: 24).fill(style == "Quiet Night" ? TailorTheme.ink : TailorTheme.mist).frame(height: 300).overlay(VStack(spacing: 12) { Image(systemName: "book.closed.fill").font(.system(size: 54)); Text("Milo").font(.system(size: 34, weight: .semibold, design: .serif)); Text("A life in moments").font(.caption) }.foregroundStyle(style == "Quiet Night" ? .white : TailorTheme.ink))
        Text(purchased ? "Your full album is ready to render." : "Preview includes cover, contents, and two watermarked sample pages.").foregroundStyle(TailorTheme.ink.opacity(0.72))
        PrimaryButton(title: purchased ? "Generate full PDF" : "Unlock complete album · $19.99", action: next)
    } }
}

private struct PurchaseView: View {
    let purchase: () -> Void; let back: () -> Void
    var body: some View { Screen(title: "Keep every page.", eyebrow: "One-time unlock", back: back) {
        ForEach(["Full, watermark-free PDF", "Every chapter and selected photo", "Print-ready A4 and US Letter", "Stays private on your device"], id: \.self) { item in Label(item, systemImage: "checkmark.circle.fill").foregroundStyle(TailorTheme.ink).padding(.vertical, 4) }
        Text("$19.99 · one-time purchase").font(.title2.weight(.bold)).foregroundStyle(TailorTheme.ink)
        PrimaryButton(title: "Unlock complete album", action: purchase)
        Button("Restore purchase") {}.font(.footnote.weight(.bold)).foregroundStyle(TailorTheme.clay).frame(maxWidth: .infinity)
    } }
}

private struct ExportView: View {
    let name: String; let done: () -> Void; let back: () -> Void
    var body: some View { Screen(title: "Your archive is ready.", eyebrow: "Export", back: back) {
        VStack(spacing: 16) { Image(systemName: "checkmark.seal.fill").font(.system(size: 76)).foregroundStyle(TailorTheme.clay); Text("\(name)’s Life Archive").font(.title2.weight(.semibold)).foregroundStyle(TailorTheme.ink); Text("Saved privately on this iPhone. You can share a copy whenever you’re ready.").multilineTextAlignment(.center).foregroundStyle(TailorTheme.ink.opacity(0.72)) }.frame(maxWidth: .infinity).padding(.vertical, 36)
        PrimaryButton(title: "Save and share PDF", action: done)
        Button("Return to timeline") { back() }.foregroundStyle(TailorTheme.clay).frame(maxWidth: .infinity)
    } }
}

private struct ArchiveView: View {
    let name: String; let restart: () -> Void
    var body: some View { Screen(title: "Your archives.", eyebrow: "Tailor", back: nil) {
        HStack { Image(systemName: "book.closed.fill").font(.title).foregroundStyle(TailorTheme.clay); VStack(alignment: .leading) { Text("\(name)’s Life Archive").font(.headline); Text("Exported just now").font(.caption).foregroundStyle(TailorTheme.ink.opacity(0.6)) }; Spacer(); Image(systemName: "chevron.right") }.padding().background(.white.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius: 18))
        Button("Rescan for new photos") {}.foregroundStyle(TailorTheme.ink)
        Button("Manage photo access") {}.foregroundStyle(TailorTheme.ink)
        Button("Delete all local Tailor data") {}.foregroundStyle(.red)
        PrimaryButton(title: "Create another archive", action: restart)
    } }
}
