import SwiftUI

struct PreviewFeatureView: View {
    let name: String; @Binding var style: AlbumStyle; let purchased: Bool; let next: () -> Void; let back: () -> Void
    var body: some View { TailorScreen(eyebrow: "PREVIEW", title: "A book to keep.", back: back) {
        HStack(spacing: 8) { templateSwatch(.warmPaper, title: "WARM\nPAPER"); templateSwatch(.quietNight, title: "QUIET\nNIGHT"); templateSwatch(.fieldNotes, title: "FIELD\nNOTES") }
        let texture = style == .warmPaper ? "WarmPaper" : (style == .quietNight ? "QuietNight" : "FieldNotes")
        RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.87, green: 0.83, blue: 0.74)).frame(height: 270).overlay(EditorialImage(name: texture).scaledToFill().opacity(0.16).clipped()).overlay(RoundedRectangle(cornerRadius: 3).fill(TailorColor.paper).frame(width: 176, height: 226).shadow(color: .black.opacity(0.16), radius: 7, y: 5).overlay(VStack(alignment: .leading, spacing: 3) { Spacer(); Text("TAILOR · SAMPLE").font(.caption2).tracking(1.2).foregroundStyle(TailorColor.clay); Text(name).font(.title.weight(.regular)); Text("A life in moments").font(.caption) }.frame(width: 138, alignment: .leading).padding(.bottom, 20).foregroundStyle(TailorColor.ink))).clipShape(RoundedRectangle(cornerRadius: 20))
        TailorInfoCard(symbol: "lock", title: purchased ? "Full album unlocked." : "Preview pages are watermarked.", message: purchased ? "Your full album is ready to render." : "Cover, contents, and two sample pages are available before unlocking.")
    }.safeAreaInset(edge: .bottom) { VStack(spacing: 8) { TailorPrimaryButton(title: purchased ? "Generate full PDF" : "Unlock complete album · $19.99", action: next); Button("Edit timeline", action: back).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) }.padding(.horizontal, 24).padding(.vertical, 10).background(TailorColor.paper) } }
    private func templateSwatch(_ choice: AlbumStyle, title: String) -> some View { Button { style = choice } label: { Text(title).font(.caption.weight(.bold)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading).padding(10).foregroundStyle(choice == .quietNight ? .white : TailorColor.ink).background(choice == .quietNight ? TailorColor.ink : (choice == .fieldNotes ? TailorColor.mist : TailorColor.paper)).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(style == choice ? TailorColor.clay : .clear, lineWidth: 2)) }.buttonStyle(.plain).accessibilityAddTraits(style == choice ? .isSelected : []) }
}
struct PurchaseFeatureView: View {
    let purchase: () -> Void; let restore: () -> Void; let errorMessage: String?; let next: () -> Void; let back: () -> Void
    var body: some View { TailorScreen(eyebrow: "ONE-TIME UNLOCK", title: "Keep every page.", back: back) {
        Text("$19.99 · One-time purchase").font(.title2.weight(.semibold))
        ForEach(["Full, watermark-free PDF", "Every chapter and selected photo", "Print-ready A4 and US Letter", "Stays private on your device"], id: \.self) { Label($0, systemImage: "checkmark.circle.fill").foregroundStyle(TailorColor.ink) }
        TailorInfoCard(symbol: "person.crop.circle.badge.checkmark", title: "No subscription. No account.", message: "Your full album remains editable on this iPhone.")
        if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
        TailorPrimaryButton(title: "Unlock complete album", action: purchase)
        Button("Restore purchase", action: restore).foregroundStyle(TailorColor.clay).frame(maxWidth: .infinity)
    } }
}

struct ExportFeatureView: View {
    let name: String; let exportURL: URL?; let errorMessage: String?; let createPDF: () -> Void; let done: () -> Void; let back: () -> Void
    var body: some View { TailorScreen(eyebrow: "EXPORT", title: "Your archive is ready.", back: back) {
        VStack(spacing: 14) { Image(systemName: "checkmark").font(.system(size: 42, weight: .medium)).foregroundStyle(TailorColor.clay).frame(width: 86, height: 86).background(TailorColor.mist).clipShape(Circle()); Text("Your archive\nis ready.").font(.largeTitle).multilineTextAlignment(.center); Text("\(name)’s Life Archive is saved privately on this iPhone. Share a copy whenever you’re ready.").multilineTextAlignment(.center).foregroundStyle(TailorColor.ink.opacity(0.75)) }.frame(maxWidth: .infinity).padding(.vertical, 22)
        RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.87, green: 0.83, blue: 0.74)).frame(height: 178).overlay(RoundedRectangle(cornerRadius: 3).fill(TailorColor.paper).frame(width: 120, height: 150).overlay(VStack { Spacer(); Text(name).font(.title3); Text("A life in moments").font(.caption2); Spacer().frame(height: 20) }.foregroundStyle(TailorColor.ink)).shadow(radius: 5, y: 3)).clipShape(RoundedRectangle(cornerRadius: 18))
        TailorInfoCard(symbol: "lock.shield", title: "Processed on this iPhone", message: "Your photos are not uploaded. Keep a backup somewhere you trust.")
        if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
    }.safeAreaInset(edge: .bottom) { VStack(spacing: 8) { TailorPrimaryButton(title: exportURL == nil ? "Generate PDF" : "Save and share PDF", action: exportURL == nil ? createPDF : done); if let exportURL { ShareLink(item: exportURL) { Text("Share PDF") }.font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) }; Button("Return to timeline", action: back).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) }.padding(.horizontal, 24).padding(.vertical, 10).background(TailorColor.paper) } }
}

struct ArchivesFeatureView: View {
    let name: String; let restart: () -> Void; let delete: () -> Void
    @State private var confirmDeletion = false
    var body: some View { TailorScreen(eyebrow: "TAILOR     SETTINGS", title: "Your\narchives.", back: nil) {
        HStack(spacing: 12) { RoundedRectangle(cornerRadius: 7).fill(TailorColor.ink).frame(width: 54, height: 68).overlay(Text(String(name.prefix(1))).font(.title3).foregroundStyle(.white)); VStack(alignment: .leading) { Text("\(name)’s Life Archive").font(.callout.weight(.bold)); Text("Exported today · Warm Paper").font(.footnote).foregroundStyle(TailorColor.ink.opacity(0.7)) }; Spacer(); Image(systemName: "chevron.right") }.padding(16).background(.white.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(TailorColor.mist, lineWidth: 1))
        VStack(spacing: 0) { ForEach(["Rescan for new photos", "Manage photo access", "About Tailor"], id: \.self) { item in HStack { Text(item); Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(.vertical, 16).overlay(Divider(), alignment: .bottom) }; Button(role: .destructive) { confirmDeletion = true } label: { HStack { Text("Delete all local Tailor data"); Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(.vertical, 16) } }.foregroundStyle(TailorColor.ink)
        TailorInfoCard(symbol: "lock.shield", title: "Your system photos stay untouched.", message: "Deletion removes Tailor’s local matches, edits, and generated PDFs after its confirmation.")
    }.safeAreaInset(edge: .bottom) { TailorPrimaryButton(title: "Create another archive", action: restart).padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) }.confirmationDialog("Delete all local Tailor data?", isPresented: $confirmDeletion, titleVisibility: .visible) { Button("Delete local data", role: .destructive, action: delete); Button("Cancel", role: .cancel) {} } message: { Text("This removes Tailor’s local pet profiles, photo matches, decisions, edits, and generated PDFs from this iPhone. Your original Photos library will not be changed. This cannot be undone.") } }
}
