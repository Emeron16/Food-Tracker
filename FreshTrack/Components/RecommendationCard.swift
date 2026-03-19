//
//  RecommendationCard.swift
//  FreshTrack
//

import SwiftUI
import SwiftData

struct RecommendationCard: View {
    let recommendation: RecipeRecommendation
    let onLike: () -> Void
    let onDislike: () -> Void

    @State private var showingExplanation = false
    @Query private var interactions: [RecipeInteraction]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Recipe image
            let imageURL = recommendation.image.isEmpty ? nil : URL(string: recommendation.image)
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .empty:
                        Rectangle()
                            .fill(.quaternary)
                            .overlay { ProgressView().scaleEffect(0.7) }
                    default:
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "fork.knife")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(height: 130)
                .clipped()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 130)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                // Why recommended
                Button {
                    showingExplanation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text(recommendation.reason)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)

                if let minutes = recommendation.readyInMinutes {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(minutes) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Feedback buttons
                HStack(spacing: 8) {
                    Spacer()

                    Button {
                        onDislike()
                    } label: {
                        Image(systemName: "hand.thumbsdown")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(.quaternary, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onLike()
                    } label: {
                        Image(systemName: "hand.thumbsup")
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .padding(6)
                            .background(.tint.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        )
        .sheet(isPresented: $showingExplanation) {
            explanationSheet
        }
    }

    private var explanationSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Why this recipe?")
                    .font(.title3)
                    .fontWeight(.bold)

                let lines = RecipeRecommendationService.shared
                    .fullExplanation(for: recommendation, interactions: interactions)
                    .components(separatedBy: "\n")

                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                            .font(.subheadline)
                        Text(line)
                            .font(.subheadline)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle(recommendation.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingExplanation = false }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium])
#endif
    }
}
