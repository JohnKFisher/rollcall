import SwiftUI

struct MusicRenderProbeView: View {
    @ObservedObject var appModel: AppModel

    private var assignedSampleCount: Int {
        appModel.musicRenderProbeSamples.filter { $0.selection != nil }.count
    }

    var body: some View {
        List {
            Section("Probe Context") {
                LabeledContent("Music Access", value: appModel.musicRenderProbeAuthorizationStatusText)
                LabeledContent("Playback Capability", value: appModel.musicRenderProbePlaybackCapabilityText)

                Button("Refresh Apple Music Capability") {
                    Task { await appModel.refreshAppleMusicPlaybackCapability() }
                }

                Button("Load Device Library Songs") {
                    Task { await appModel.loadMusicRenderProbeLibraryCandidates() }
                }

                if appModel.isMusicRenderProbeLoadingLibrary {
                    ProgressView("Loading device library…")
                } else if !appModel.musicRenderProbeLibraryCandidates.isEmpty {
                    Text("Loaded \(appModel.musicRenderProbeLibraryCandidates.count) device-library songs for manual sample selection.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if assignedSampleCount > 1 {
                    Button("Run All Assigned Probes") {
                        Task { await appModel.runAllAssignedMusicRenderProbes() }
                    }
                }
            }

            ForEach(appModel.musicRenderProbeSamples) { sample in
                Section(sample.scenario.title) {
                    Text(sample.scenario.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        MusicRenderProbePickerHostView(appModel: appModel, scenario: sample.scenario)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(sample.selection == nil ? "Choose Sample" : sample.selection!.displayTitle)
                                .font(.body.weight(.semibold))
                            Text(sample.selection?.displaySubtitle ?? pickerPrompt(for: sample.scenario))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if sample.selection != nil {
                        Button("Run Probe") {
                            Task { await appModel.runMusicRenderProbe(for: sample.scenario) }
                        }

                        Button("Clear Sample", role: .destructive) {
                            appModel.clearMusicRenderProbeSample(for: sample.scenario)
                        }
                    }

                    if let result = sample.result {
                        MusicRenderProbeResultView(result: result)
                    } else if sample.selection != nil {
                        Text("No probe result yet for this sample.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let summary = appModel.musicRenderProbeSummary {
                Section("Redacted Summary") {
                    LabeledContent("Assigned Samples", value: "\(summary.sampleCount)")
                    LabeledContent("Completed Probes", value: "\(summary.completedProbeCount)")

                    ForEach(summary.scenarioSummaries) { scenarioSummary in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scenarioSummary.scenario.title)
                                .font(.subheadline.weight(.semibold))
                            Text(summaryLine(for: scenarioSummary))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }

                    Button("Export Redacted Summary") {
                        appModel.exportMusicRenderProbeSummary()
                    }

                    if let url = appModel.musicRenderProbeSummaryURL {
                        ShareLink(item: url) {
                            Label("Share Latest Redacted Summary", systemImage: "square.and.arrow.up")
                        }
                    }

                    Text("This summary excludes song titles, artists, IDs, and audio files. It is meant for findings notes and diagnostics only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Music Render Probe")
    }

    private func pickerPrompt(for scenario: MusicRenderProbeScenario) -> String {
        switch scenario.sourceFamily {
        case .library:
            return "Select a device Music Library item for this category."
        case .catalog:
            return "Search Apple Music and assign a catalog or preview result."
        case .appLocal:
            return "Pick a Roll Call imported local audio file."
        }
    }

    private func summaryLine(for summary: MusicRenderProbeRedactedScenarioSummary) -> String {
        guard summary.sampleAssigned else {
            return "No sample assigned yet."
        }

        guard let verdict = summary.verdict else {
            return "Sample assigned. Probe not run yet."
        }

        switch verdict {
        case .fullSourceRenderable:
            return "Full-source rendering succeeded."
        case .previewOnlyRenderable:
            return "Only preview/proxy rendering succeeded."
        case .failed:
            return "No renderable path succeeded."
        }
    }
}

private struct MusicRenderProbePickerHostView: View {
    @ObservedObject var appModel: AppModel
    let scenario: MusicRenderProbeScenario

    var body: some View {
        switch scenario.sourceFamily {
        case .library:
            MusicRenderProbeLibraryPickerView(appModel: appModel, scenario: scenario)
        case .catalog:
            MusicRenderProbeCatalogPickerView(appModel: appModel, scenario: scenario)
        case .appLocal:
            MusicRenderProbeLocalPickerView(appModel: appModel, scenario: scenario)
        }
    }
}

private struct MusicRenderProbeLibraryPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var appModel: AppModel
    let scenario: MusicRenderProbeScenario

    @State private var searchText = ""

    private var filteredCandidates: [MusicRenderProbeLibraryCandidate] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return appModel.musicRenderProbeLibraryCandidates
        }

        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return appModel.musicRenderProbeLibraryCandidates.filter {
            $0.title.localizedCaseInsensitiveContains(needle)
                || $0.artistName.localizedCaseInsensitiveContains(needle)
                || ($0.albumTitle?.localizedCaseInsensitiveContains(needle) ?? false)
        }
    }

    var body: some View {
        List {
            if appModel.musicRenderProbeLibraryCandidates.isEmpty {
                Section {
                    Text("Load device-library songs from the main probe screen, or tap the button below to request music access and load them now.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Load Device Library Songs") {
                        Task { await appModel.loadMusicRenderProbeLibraryCandidates() }
                    }
                }
            } else {
                ForEach(filteredCandidates) { candidate in
                    Button {
                        appModel.assignMusicRenderProbeLibraryCandidate(candidate, to: scenario)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(candidate.title)
                                .foregroundStyle(.primary)
                            Text(candidate.artistName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(libraryMetadataLine(for: candidate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(scenario.title)
        .searchable(text: $searchText, prompt: "Search Library")
    }

    private func libraryMetadataLine(for candidate: MusicRenderProbeLibraryCandidate) -> String {
        var pieces: [String] = []
        pieces.append(candidate.hasLocalAssetURL ? "Local asset URL exposed" : "No local asset URL")
        if candidate.isCloudItem {
            pieces.append("Cloud item")
        }
        if candidate.playbackStoreID != nil {
            pieces.append("Store ID present")
        }
        return pieces.joined(separator: " • ")
    }
}

private struct MusicRenderProbeCatalogPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var appModel: AppModel
    let scenario: MusicRenderProbeScenario

    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                Text("Search Apple Music explicitly for this probe case. Full-song viability still depends on subscription state and what public APIs expose after selection.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if appModel.isMusicRenderProbeSearchingCatalog {
                    ProgressView("Searching Apple Music…")
                }
            }

            ForEach(appModel.musicRenderProbeCatalogCandidates) { candidate in
                Button {
                    appModel.assignMusicRenderProbeCatalogCandidate(candidate, to: scenario)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(candidate.title)
                            .foregroundStyle(.primary)
                        Text(candidate.artistName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(candidate.isCatalogBacked ? "Catalog-backed result" : "Preview/proxy-only result")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(scenario.title)
        .searchable(text: $searchText, prompt: "Search Apple Music")
        .onSubmit(of: .search) {
            let term = searchText
            Task { await appModel.searchMusicRenderProbeCatalog(term: term) }
        }
    }
}

private struct MusicRenderProbeLocalPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var appModel: AppModel
    let scenario: MusicRenderProbeScenario

    var body: some View {
        List {
            if appModel.musicRenderProbeLocalCandidates.isEmpty {
                ContentUnavailableView(
                    "No Local Imports Found",
                    systemImage: "waveform.badge.exclamationmark",
                    description: Text("Import a local file into a player first, then return here to use it as the control sample.")
                )
            } else {
                ForEach(appModel.musicRenderProbeLocalCandidates) { candidate in
                    Button {
                        appModel.assignMusicRenderProbeLocalCandidate(candidate, to: scenario)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(candidate.source.displayName)
                                .foregroundStyle(.primary)
                            Text("\(candidate.teamName) • \(candidate.playerName)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(scenario.title)
    }
}

private struct MusicRenderProbeResultView: View {
    let result: MusicRenderProbeResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.headline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(verdictColor)

            MusicRenderProbeAttemptLine(title: "Full Source", attempt: result.fullSourceAttempt)
            MusicRenderProbeAttemptLine(title: "Preview / Proxy", attempt: result.previewProxyAttempt)
        }
        .padding(.vertical, 4)
    }

    private var verdictColor: Color {
        switch result.verdict {
        case .fullSourceRenderable:
            return .green
        case .previewOnlyRenderable:
            return .orange
        case .failed:
            return .red
        }
    }
}

private struct MusicRenderProbeAttemptLine: View {
    let title: String
    let attempt: MusicRenderProbeAttempt

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(title): \(statusText)")
                .font(.footnote.weight(.semibold))
            if let detail = attempt.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        switch attempt.status {
        case .succeeded:
            return "Succeeded"
        case .failed:
            return attempt.failureCategory?.title ?? "Failed"
        case .notAttempted:
            return "Not Attempted"
        }
    }
}
