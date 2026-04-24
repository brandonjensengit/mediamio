//
//  CastCrewSection.swift
//  MediaMio
//
//  Renders `MediaItem.people` (already decoded on the model) as a horizontally
//  scrolling row of person cards on the detail screen. Cast (Actors) are
//  surfaced first, then crew (Director/Writer/Producer/etc.).
//

import SwiftUI

struct CastCrewSection: View {
    let people: [PersonInfo]
    let baseURL: String

    private var orderedPeople: [PersonInfo] {
        let cast = people.filter { $0.type?.lowercased() == "actor" }
        let crew = people.filter { $0.type?.lowercased() != "actor" }
        return Array((cast + crew).prefix(24))
    }

    var body: some View {
        if orderedPeople.isEmpty {
            EmptyView()
        } else {
            DetailSectionView(title: "Cast & Crew") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 30) {
                        ForEach(orderedPeople, id: \.self) { person in
                            PersonCard(person: person, baseURL: baseURL)
                        }
                    }
                    .padding(.horizontal, Constants.UI.defaultPadding)
                }
            }
        }
    }
}

// MARK: - Person Card

private struct PersonCard: View {
    let person: PersonInfo
    let baseURL: String

    @Environment(\.isFocused) private var isFocused
    @FocusState private var hasFocus: Bool

    private var headshotURL: String? {
        person.primaryImageURL(baseURL: baseURL, maxWidth: 320)
    }

    private var subtitle: String? {
        if let role = person.role, !role.isEmpty { return role }
        if let type = person.type, !type.isEmpty { return type }
        return nil
    }

    var body: some View {
        // tvOS needs a focusable surface for the card to receive focus; wrap
        // in a Button with no action and the plain style so the visual is
        // fully ours but the focus engine treats it as a focusable stop.
        Button(action: {}) {
            VStack(spacing: 14) {
                headshot
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(
                            hasFocus ? Constants.Colors.accent : Constants.Colors.surface3,
                            lineWidth: hasFocus ? 4 : 2
                        )
                    )

                VStack(spacing: 4) {
                    Text(person.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(width: 220)
            }
            .scaleEffect(hasFocus ? 1.04 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: hasFocus)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($hasFocus)
    }

    @ViewBuilder
    private var headshot: some View {
        if let url = headshotURL {
            AsyncImageView(
                url: url,
                placeholder: Image(systemName: "person.crop.circle.fill"),
                contentMode: .fill
            )
        } else {
            ZStack {
                Circle().fill(Constants.Colors.surface2)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - PersonInfo image URL

extension PersonInfo {
    /// Jellyfin person headshot URL. Returns nil when the server has no
    /// primary image tag — callers should render a silhouette placeholder
    /// in that case.
    func primaryImageURL(baseURL: String, maxWidth: Int = 280, quality: Int = 90) -> String? {
        guard let id = id, let tag = primaryImageTag, !tag.isEmpty else { return nil }
        return "\(baseURL)/Items/\(id)/Images/Primary?maxWidth=\(maxWidth)&quality=\(quality)&tag=\(tag)"
    }
}
