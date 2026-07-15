import SwiftUI

struct WelcomeFeatureView: View {
    let next: () -> Void
    @State private var showsPrivacy = false
    var body: some View { TailorScreen(eyebrow: "TAILOR", title: "Keep a life close.", back: nil) {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(TailorColor.mist)
                EditorialImage(name: "WelcomeHero")
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        }
        .frame(height: 286)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityHidden(true)
        Text("Gather real photographs into a private life archive. Nothing leaves your iPhone.").foregroundStyle(TailorColor.ink.opacity(0.76))
        Spacer(minLength: 120)
    }
    .overlay(alignment: .topTrailing) {
        Button { showsPrivacy = true } label: { Image(systemName: "ellipsis.circle").font(.title3) }
            .frame(width: 48, height: 48).foregroundStyle(TailorColor.clay).padding(.top, 6).padding(.trailing, 18)
    }
    .safeAreaInset(edge: .bottom) { VStack(spacing: 6) { TailorPrimaryButton(title: "Create a life archive", action: next); Button("How we protect your photos") { showsPrivacy = true }.font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) }.padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) }
    .sheet(isPresented: $showsPrivacy) {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your photos stay yours.").font(TailorFont.display(30))
            Text("Processed on this iPhone. Your photos are not uploaded. Only photos you confirm are used in your archive.").foregroundStyle(TailorColor.secondaryInk)
            Spacer()
            Button("Done") { showsPrivacy = false }.frame(maxWidth: .infinity, minHeight: 56).background(TailorColor.ink).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 16))
        }.padding(24).presentationDetents([.medium])
    }
    }
}

struct PrivacyFeatureView: View {
    @Binding var scope: PhotoAccessScope
    @ObservedObject var photoLibrary: PhotoLibraryAccess
    let next: () -> Void
    let back: () -> Void
    var body: some View { TailorScreen(eyebrow: "PRIVACY", title: "Your photos stay yours.", back: back) {
        Text("Tailor asks only for the access you choose.")
        TailorInfoCard(symbol: "iphone", title: "Processed on this device", message: "")
        TailorInfoCard(symbol: "arrow.down.to.line", title: "Never uploaded as an album", message: "")
        TailorInfoCard(symbol: "checkmark", title: "Only photos you approve are used", message: "")
        TailorInfoCard(symbol: "hand.raised", title: "Limited access is okay", message: "Results will only include the photos you select.")
        if scope == .denied || scope == .restricted { TailorInfoCard(symbol: "exclamationmark.triangle", title: "Photo access is off.", message: "Choose photos manually, or enable access in Settings.", tint: .red); Button("Open Settings") { photoLibrary.openSettings() }.foregroundStyle(TailorColor.clay) }
        Spacer(minLength: 36)
    }.safeAreaInset(edge: .bottom) { VStack(spacing: 6) { TailorPrimaryButton(title: scope == .limited ? "Continue with selected photos" : "Allow photo access") {
            Task {
                let updatedScope = await photoLibrary.requestAccess()
                scope = updatedScope
                if updatedScope == .full || updatedScope == .limited { next() }
            }
        }; Button("Choose photos manually instead") { scope = .limited; next() }.font(.footnote.weight(.bold)).foregroundStyle(TailorColor.clay) }.padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) } }
}

struct ProfileFeatureView: View {
    @Binding var name: String; @Binding var species: PetSpecies; @Binding var departureYear: String; let next: () -> Void; let back: () -> Void
    private var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && Int(departureYear) != nil }
    var body: some View { TailorScreen(eyebrow: "PROFILE", title: "Tell us about them.", back: back) {
        Picker("Species", selection: $species) { Text("Dog").tag(PetSpecies.dog); Text("Cat").tag(PetSpecies.cat) }.pickerStyle(.segmented)
        VStack(alignment: .leading) { Text("THEIR NAME").font(.caption.weight(.bold)); TextField("Their name", text: $name).textContentType(.name).textFieldStyle(.roundedBorder) }
        HStack { VStack(alignment: .leading) { Text("CAME HOME · OPTIONAL").font(.caption.weight(.bold)); Text("2017").padding(14).frame(maxWidth: .infinity, alignment: .leading).background(TailorColor.paperDeep).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(TailorColor.line)) }; VStack(alignment: .leading) { Text("LEFT US").font(.caption.weight(.bold)); TextField("Year", text: $departureYear).keyboardType(.numberPad).padding(14).background(TailorColor.paperDeep).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(TailorColor.line)) } }
        TailorInfoCard(symbol: "calendar", title: "Years shape the timeline", message: "They do not have to be exact.")
        Spacer(minLength: 80)
    }.safeAreaInset(edge: .bottom) { TailorPrimaryButton(title: "Choose reference photos", disabled: !valid, action: next).padding(.horizontal, 24).padding(.vertical, 12).background(TailorColor.paper) } }
}
