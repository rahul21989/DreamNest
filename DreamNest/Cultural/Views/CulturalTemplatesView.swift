import SwiftUI

struct CulturalTemplatesView: View {

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.04, blue: 0.15).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        // ── Header ────────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 6) {
                            Text("🪔 Cultural Stories")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Timeless Indian tales for little dreamers")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)

                        // ── Grid ──────────────────────────────────────────────
                        templateGrid
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Grid layout

    private var templateGrid: some View {
        let items = CulturalTemplate.all
        // Split: all but last pair go into 2-column rows;
        // if count is odd the last item gets a full-width row.
        let isOdd  = items.count % 2 != 0
        let paired = isOdd ? Array(items.dropLast()) : items
        let lone   = isOdd ? items.last : nil

        return VStack(spacing: 14) {
            // Two-column rows
            let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(paired) { template in
                    cardLink(template, height: 170)
                }
            }

            // Full-width final card (only when count is odd)
            if let lone {
                cardLink(lone, height: 160, fullWidth: true)
            }
        }
    }

    @ViewBuilder
    private func cardLink(_ template: CulturalTemplate,
                          height: CGFloat,
                          fullWidth: Bool = false) -> some View {
        NavigationLink(destination: CulturalStoryListView(template: template)) {
            TemplateCard(template: template, height: height, fullWidth: fullWidth)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template card

private struct TemplateCard: View {
    let template:  CulturalTemplate
    let height:    CGFloat
    var fullWidth: Bool = false

    var body: some View {
        // Color.clear is the layout anchor — its frame is always exactly height × column-width.
        // .background fills to match that frame (artwork never escapes the bounds).
        // .overlay is size-neutral — text never inflates the cell height.
        Color.clear
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background {
                template.artworkView(fallbackIcon: false)
            }
            .overlay {
                // Strong bottom scrim — readable against any image
                LinearGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(0.10),
                        Color.black.opacity(0.65),
                        Color.black.opacity(0.92),
                    ],
                    startPoint: .top,
                    endPoint:   .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(template.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)          // always 1 line → row heights stay equal
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    }
}
