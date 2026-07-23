import SwiftUI
import UIKit

struct WelcomeFeatureView: View {
    let hasSavedArchive: Bool
    let next: () -> Void
    let openArchives: () -> Void
    @State private var showsPrivacy = false
    @State private var showsAbout = false
    @Environment(\.openURL) private var openURL
    var body: some View { TailorScreen(eyebrow: "", title: "Keep a life", back: nil) {
        Text("close.").font(TailorFont.display(36)).foregroundStyle(TailorColor.ink).padding(.top, -TailorSpacing.m)
            .accessibilityLabel("Keep a life close.")
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(TailorColor.mist)
                EditorialImage(name: "WelcomeHero")
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        }
        .frame(height: 297)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.top, 5)
        .padding(.bottom, 10)
        .accessibilityHidden(true)
        Text("Create a private memory book for a pet you loved. Nothing leaves your iPhone.").foregroundStyle(TailorColor.ink.opacity(0.76))
        Spacer(minLength: 120)
    }
    .overlay(alignment: .top) {
        HStack {
            Text("TAILOR")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(TailorColor.clay)
            Spacer()
            Menu {
                Button("How we protect your photos") { showsPrivacy = true }
                Button("About Tailor") { showsAbout = true }
                Button("Manage photo access") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.callout.weight(.bold))
                    .frame(width: TailorSpacing.touchTarget, height: TailorSpacing.touchTarget)
            }
            .foregroundStyle(TailorColor.clay)
            .accessibilityLabel("More options")
        }
        .padding(.horizontal, TailorSpacing.l)
        // Align the welcome wordmark with the design header rather than the
        // text content's safe-area origin.
        .padding(.top, -4)
    }
    .safeAreaInset(edge: .bottom) {
        VStack(spacing: TailorSpacing.m) {
            TailorPrimaryButton(title: "Create a memory book", action: next)
            Button("How we protect your photos") { showsPrivacy = true }
                .font(.footnote.weight(.bold))
                .foregroundStyle(TailorColor.clay)
            if hasSavedArchive {
                Button("Open saved archive") { openArchives() }
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(TailorColor.ink)
                    .accessibilityLabel("Open saved archive")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 25)
        .background(TailorColor.paper)
    }
    .sheet(isPresented: $showsPrivacy) {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your photos stay yours.").font(TailorFont.display(30))
            Text("Processed on this iPhone. Your photos are not uploaded. Only photos you confirm are used in your book.").foregroundStyle(TailorColor.secondaryInk)
            Spacer()
            Button("Done") { showsPrivacy = false }.frame(maxWidth: .infinity, minHeight: 56).background(TailorColor.ink).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 16))
        }.padding(24).presentationDetents([.medium])
    }
    .sheet(isPresented: $showsAbout) { AboutTailorSheet() }
    }
}

struct PrivacyFeatureView: View {
    @Binding var scope: PhotoAccessScope
    @ObservedObject var photoLibrary: PhotoLibraryAccess
    let next: () -> Void
    let manualImport: () -> Void
    let back: () -> Void
    var body: some View { TailorScreen(eyebrow: "PRIVACY", title: "Your photos stay yours.", back: back) {
        Text("Tailor asks only for the access you choose.")
            .foregroundStyle(TailorColor.secondaryInk)
            .padding(.bottom, TailorSpacing.s)
        VStack(spacing: TailorSpacing.s) {
            privacyCard("Processed on this device")
            privacyCard("Your whole album is never uploaded")
            privacyCard("Only photos you approve are used")
            privacyCard("Limited access is okay", detail: "Results will only include the photos you select.")
        }
        if scope == .denied || scope == .restricted {
            privacyCard("Access denied", detail: "Manual Import never scans your library. PHPicker returns only the 3–500 photos you explicitly choose.", tint: .red)
            Button("Open Settings instead") { photoLibrary.openSettings() }.foregroundStyle(TailorColor.clay)
        }
        Spacer(minLength: 36)
    }.safeAreaInset(edge: .bottom) { VStack(spacing: 26) { TailorPrimaryButton(title: scope == .denied || scope == .restricted ? "Import photos manually" : (scope == .limited ? "Continue with selected photos" : "Allow photo access")) {
            if scope == .denied || scope == .restricted { manualImport() }
            else {
                Task {
                    let updatedScope = await photoLibrary.requestAccess()
                    scope = updatedScope
                    if updatedScope == .full || updatedScope == .limited { next() }
                }
            }
        }; if scope != .denied && scope != .restricted { Button("Choose photos manually instead", action: manualImport).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) } }.padding(.horizontal, 24).padding(.vertical, 15).background(TailorColor.paper) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            photoLibrary.refresh()
            scope = photoLibrary.scope
        }
    }

    private func privacyCard(_ title: String, detail: String? = nil, tint: Color = TailorColor.ink) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.callout.weight(.medium)).foregroundStyle(tint)
            if let detail { Text(detail).font(.footnote).foregroundStyle(TailorColor.secondaryInk) }
        }
        .frame(maxWidth: .infinity, minHeight: detail == nil ? 66 : 85, alignment: .leading)
        .padding(.horizontal, 20)
        .background(.white.opacity(0.66))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(TailorColor.line))
    }
}

struct ProfileFeatureView: View {
    @Binding var name: String; @Binding var species: PetSpecies; @Binding var arrivalYear: String; @Binding var departureYear: String; let next: () -> Void; let continueLater: () -> Void; let back: () -> Void
    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    private var departure: Int? { Int(departureYear) }
    private var arrival: Int? { arrivalYear.isEmpty ? nil : Int(arrivalYear) }
    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && departure.map { (1900...currentYear).contains($0) } == true
            && (arrival == nil || arrival.map { (1900...currentYear).contains($0) && $0 <= (departure ?? 0) } == true)
    }
    var body: some View { TailorScreen(eyebrow: "PROFILE", title: "Tell us about\nthem.", back: back) {
        HStack(spacing: 0) {
            speciesButton("Dog", species: .dog)
            speciesButton("Cat", species: .cat)
        }
        .padding(4)
        .background(TailorColor.paperDeep)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(height: 48)
        .padding(.top, 7)
        .padding(.bottom, 6)
        VStack(alignment: .leading, spacing: 8) {
            Text("THEIR NAME").font(.caption.weight(.bold)).tracking(1).foregroundStyle(TailorColor.secondaryInk)
            TextField("Their name", text: $name).textContentType(.name).padding(.horizontal, 16).frame(height: 52).background(TailorColor.paperDeep).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(TailorColor.line))
        }
        HStack(spacing: 18) { VStack(alignment: .leading) { Text("CAME HOME · OPTIONAL").font(.caption.weight(.medium)).foregroundStyle(TailorColor.secondaryInk); TextField("Year", text: $arrivalYear).keyboardType(.numberPad).padding(14).frame(minHeight: 52).background(TailorColor.paperDeep).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(TailorColor.line)) }; VStack(alignment: .leading) { Text("LEFT US").font(.caption.weight(.medium)).foregroundStyle(TailorColor.secondaryInk); TextField("Year", text: $departureYear).keyboardType(.numberPad).padding(14).frame(minHeight: 52).background(TailorColor.paperDeep).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(TailorColor.line)) } }
        .padding(.top, 9)
        .padding(.bottom, 13)
        VStack(alignment: .leading, spacing: 6) { Text("Years only shape the timeline.").font(.callout.weight(.semibold)); Text("They do not have to be exact.").font(.footnote).foregroundStyle(TailorColor.secondaryInk) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.white.opacity(0.66)).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(TailorColor.line))
        Spacer(minLength: 80)
    }.safeAreaInset(edge: .bottom) { VStack(spacing: 8) { TailorPrimaryButton(title: "Choose reference photos", disabled: !valid, action: next); Button("Save for later", action: continueLater).font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) }.padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) } }
    private func speciesButton(_ title: String, species option: PetSpecies) -> some View { Button { species = option } label: { HStack(spacing: 3) { if species == option { Image(systemName: "checkmark").font(.caption.weight(.bold)) }; Text(title).font(.callout.weight(.semibold)) }.frame(maxWidth: .infinity, maxHeight: .infinity).foregroundStyle(species == option ? Color.white : TailorColor.ink).background(species == option ? TailorColor.ink : Color.clear).clipShape(RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain) }
}
