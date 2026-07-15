import SwiftUI
import UIKit

/// Loads editorial PNGs as ordinary bundle resources. The asset catalog remains the
/// canonical design source but is intentionally not compiled in this local Xcode setup.
struct EditorialImage: View {
    let name: String
    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Editorial"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image).resizable()
        } else {
            ZStack { TailorColor.mist; Image(systemName: "photo").font(.largeTitle).foregroundStyle(TailorColor.ink) }
        }
    }
}

struct TailorScreen<Content: View>: View {
    let eyebrow: String; let title: String; let back: (() -> Void)?; @ViewBuilder var content: Content
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                TailorColor.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: TailorSpacing.l) {
                        HStack { if let back { Button(action: back) { Image(systemName: "chevron.left") }.frame(width: TailorSpacing.touchTarget, height: TailorSpacing.touchTarget).accessibilityLabel("Back") }; Spacer(); Text(eyebrow).font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(TailorColor.clay) }
                        Text(title).font(TailorFont.display(36)).foregroundStyle(TailorColor.ink).fixedSize(horizontal: false, vertical: true)
                        content
                    }
                    .frame(width: max(0, proxy.size.width - (TailorSpacing.l * 2)), alignment: .leading)
                    .padding(.horizontal, TailorSpacing.l)
                    .padding(.top, TailorSpacing.s)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .tint(TailorColor.ink)
        }
    }
}

struct TailorPrimaryButton: View {
    let title: String; var disabled = false; let action: () -> Void
    var body: some View { Button(action: action) { HStack { Text(title); Spacer(); Image(systemName: "arrow.right") }.font(.callout.weight(.semibold)).padding(.horizontal, TailorSpacing.m).frame(minHeight: 56) }.buttonStyle(.plain).foregroundStyle(.white).background(disabled ? TailorColor.ink.opacity(0.35) : TailorColor.ink).clipShape(RoundedRectangle(cornerRadius: 16)).disabled(disabled).accessibilityLabel(title) }
}

struct TailorInfoCard: View {
    let symbol: String; let title: String; let message: String; var tint: Color = TailorColor.ink
        var body: some View { HStack(alignment: .top, spacing: TailorSpacing.s) { Image(systemName: symbol).foregroundStyle(tint).frame(width: 28); VStack(alignment: .leading, spacing: 4) { Text(title).font(.callout.weight(.semibold)); Text(message).font(.footnote).foregroundStyle(TailorColor.secondaryInk).fixedSize(horizontal: false, vertical: true) } }.padding(TailorSpacing.m).background(TailorColor.elevated).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(TailorColor.line, lineWidth: 1)) }
}

struct TailorProgressRing: View {
    let progress: Double; let label: String
    var body: some View { ZStack { Circle().stroke(TailorColor.mist, lineWidth: 14); Circle().trim(from: 0, to: max(0.03, progress)).stroke(TailorColor.clay, style: .init(lineWidth: 14, lineCap: .round)).rotationEffect(.degrees(-90)); VStack { Text("\(Int(progress * 100))%").font(.title.weight(.bold)); Text(label).font(.caption) } }.frame(width: 180, height: 180).accessibilityElement(children: .ignore).accessibilityLabel("Scan progress").accessibilityValue("\(Int(progress * 100)) percent") }
}
