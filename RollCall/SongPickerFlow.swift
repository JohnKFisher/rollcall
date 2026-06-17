import MediaPlayer
import MusicKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum SongPickerMode: String, Identifiable {
    case musicLibrary
    case appleMusic
    case files

    var id: String { rawValue }
}

struct SongPickerFlow: View {
    private struct DraftRoute: Identifiable, Hashable {
        let id = UUID()
        let cue: Cue
        let isImported: Bool

        static func == (lhs: DraftRoute, rhs: DraftRoute) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let mode: SongPickerMode
    let importedURL: URL?
    let onSave: (Cue) -> Void

    @State private var selectedDraft: DraftRoute?
    @State private var savedDraftID: UUID?
    @State private var showPermissionPrimer = false
    @State private var pickerError: String?

    var body: some View {
        NavigationStack {
            sourceView
                .navigationDestination(item: $selectedDraft) { draft in
                    SongClipEditorView(appModel: appModel, initialCue: draft.cue) { cue in
                        savedDraftID = draft.id
                        onSave(cue)
                        dismiss()
                    }
                }
        }
        .task {
            switch mode {
            case .musicLibrary, .appleMusic:
                if appModel.needsAppleMusicAccessPrompt {
                    showPermissionPrimer = true
                }
            case .files:
                guard let importedURL,
                      let cue = await appModel.makeImportedSongCueDraft(from: importedURL),
                      !Task.isCancelled else {
                    dismiss()
                    return
                }
                openEditor(for: cue, isImported: true)
            }
        }
        .onChange(of: selectedDraft) { oldValue, newValue in
            guard let oldValue,
                  oldValue.isImported,
                  newValue == nil,
                  savedDraftID != oldValue.id else {
                return
            }
            appModel.discardImportedSongCueDraft(oldValue.cue)
        }
        .onDisappear {
            guard let selectedDraft,
                  selectedDraft.isImported,
                  savedDraftID != selectedDraft.id else {
                return
            }
            appModel.discardImportedSongCueDraft(selectedDraft.cue)
        }
        .alert("Use Music?", isPresented: $showPermissionPrimer) {
            Button("Not Now", role: .cancel) { dismiss() }
            Button("Continue") {
                Task {
                    let status = await appModel.requestAppleMusicAccess()
                    if status != .authorized {
                        pickerError = "Music access is required. You can enable it in Settings or import an audio file instead."
                    }
                }
            }
        } message: {
            Text("Roll Call uses Music access so you can choose songs from this iPhone's music library. If you use Apple Music, you can also search Apple Music for songs that are not already in your library.")
        }
        .alert("Song Unavailable", isPresented: Binding(
            get: { pickerError != nil },
            set: { if !$0 { pickerError = nil } }
        )) {
            Button("OK") { }
        } message: {
            Text(pickerError ?? "")
        }
    }

    @ViewBuilder
    private var sourceView: some View {
        switch mode {
        case .musicLibrary:
            if MusicAuthorization.currentStatus == .authorized {
                NativeMusicLibraryPicker(
                    onPick: handleLibrarySelection,
                    onCancel: { dismiss() }
                )
                .ignoresSafeArea()
            } else {
                MusicPermissionWaitingView()
            }
        case .appleMusic:
            if MusicAuthorization.currentStatus == .authorized {
                AppleMusicCatalogPicker(appModel: appModel, onSelect: openEditor(for:))
            } else {
                MusicPermissionWaitingView()
            }
        case .files:
            ProgressView("Preparing audio...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Make Your Clip")
        }
    }

    private func handleLibrarySelection(_ item: MPMediaItem) {
        let title = item.title?.nonempty ?? "Untitled Song"
        let artistName = item.artist?.nonempty ?? "Unknown Artist"

        if let storeID = item.playbackStoreID.nonempty {
            openEditor(
                for: MusicSearchResult(
                    songID: storeID,
                    title: title,
                    artistName: artistName,
                    duration: item.playbackDuration,
                    previewURL: nil,
                    artworkURL: nil,
                    isCatalogBacked: true,
                    libraryPersistentID: item.persistentID
                )
            )
            return
        }

        guard let assetURL = item.assetURL else {
            pickerError = "This library song does not expose a playable file or Apple Music identifier to Roll Call."
            return
        }

        Task {
            guard let cue = await appModel.makeImportedSongCueDraft(from: assetURL) else { return }
            openEditor(for: cue, isImported: true)
        }
    }

    private func openEditor(for result: MusicSearchResult) {
        let cue = appModel.chooseSuggestedHook(for: appModel.makeAppleMusicCueDraft(result))
        openEditor(for: cue, isImported: false)
    }

    private func openEditor(for cue: Cue, isImported: Bool) {
        if let url = SongWaveformSourceResolver.url(for: cue) {
            Task {
                await SongWaveformRepository.shared.prefetch(from: url, sampleCount: 64)
            }
        }
        selectedDraft = DraftRoute(cue: cue, isImported: isImported)
    }
}

private struct MusicPermissionWaitingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Waiting for Music access...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NativeMusicLibraryPicker: UIViewControllerRepresentable {
    let onPick: (MPMediaItem) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.delegate = context.coordinator
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems = true
        picker.showsItemsWithProtectedAssets = true
        picker.prompt = "Choose a song for this walk-up clip."
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {
    }

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let onPick: (MPMediaItem) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (MPMediaItem) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func mediaPicker(
            _ mediaPicker: MPMediaPickerController,
            didPickMediaItems mediaItemCollection: MPMediaItemCollection
        ) {
            guard let item = mediaItemCollection.items.first else {
                onCancel()
                return
            }
            onPick(item)
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            onCancel()
        }
    }
}

private struct AppleMusicCatalogPicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let onSelect: (MusicSearchResult) -> Void

    @State private var searchTerm = ""
    @State private var results: [MusicSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?

    var body: some View {
        List {
            if searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Recent Songs") {
                    if appModel.recentAppleMusicSelections.isEmpty {
                        ContentUnavailableView(
                            "Search Apple Music",
                            systemImage: "music.note",
                            description: Text("Find a song, artist, or album in the Apple Music catalog.")
                        )
                    } else {
                        ForEach(appModel.recentAppleMusicSelections) { recent in
                            catalogRow(
                                MusicSearchResult(
                                    songID: recent.songID,
                                    title: recent.title,
                                    artistName: recent.artistName,
                                    duration: recent.duration,
                                    previewURL: recent.previewURL,
                                    isCatalogBacked: recent.isCatalogBacked ?? true
                                )
                            )
                        }
                    }
                }
            } else {
                Section {
                    if isSearching {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Searching Apple Music...")
                                .foregroundStyle(.secondary)
                        }
                    } else if let searchError {
                        ContentUnavailableView(
                            "Search Unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text(searchError)
                        )
                    } else if results.isEmpty {
                        ContentUnavailableView.search(text: searchTerm)
                    } else {
                        ForEach(results) { result in
                            catalogRow(result)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Apple Music")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchTerm,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search Apple Music"
        )
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .task(id: searchTerm) {
            await search()
        }
    }

    private func catalogRow(_ result: MusicSearchResult) -> some View {
        Button {
            onSelect(result)
        } label: {
            HStack(spacing: 12) {
                CatalogArtwork(url: result.artworkURL)
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(result.artistName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func search() async {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            results = []
            searchError = nil
            isSearching = false
            return
        }

        isSearching = true
        searchError = nil
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        do {
            let newResults = try await appModel.musicCatalogService.search(
                term: term,
                mode: .previewFallback
            )
            guard !Task.isCancelled, currentSearchTerm == term else { return }
            results = newResults
            searchError = nil
        } catch {
            guard !MusicCatalogService.isCancellation(error),
                  !Task.isCancelled,
                  currentSearchTerm == term else {
                return
            }
            results = []
            searchError = error.localizedDescription
        }
        if currentSearchTerm == term {
            isSearching = false
        }
    }

    private var currentSearchTerm: String {
        searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct CatalogArtwork: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Color.secondary.opacity(0.14)
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct SongClipEditorView: View {
    private enum WaveformState: Equatable {
        case loading
        case ready([Float])
        case unavailable
    }

    private enum TimeMetricAlignment {
        case leading
        case center
        case trailing

        var horizontal: HorizontalAlignment {
            switch self {
            case .leading: return .leading
            case .center: return .center
            case .trailing: return .trailing
            }
        }

        var frame: Alignment {
            switch self {
            case .leading: return .leading
            case .center: return .center
            case .trailing: return .trailing
            }
        }
    }

    @ObservedObject var appModel: AppModel
    @ObservedObject private var playbackEngine: CuePlaybackEngine
    let onSave: (Cue) -> Void

    @State private var cue: Cue
    @State private var showAdvanced = false
    @State private var waveformState: WaveformState = .loading

    private let lengthOptions: [TimeInterval] = [8, 10, 12, 15, 20]

    init(appModel: AppModel, initialCue: Cue, onSave: @escaping (Cue) -> Void) {
        self.appModel = appModel
        self.playbackEngine = appModel.playbackEngine
        self.onSave = onSave
        _cue = State(initialValue: initialCue)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(songTitle)
                        .font(.headline)
                    if let artistName {
                        Text(artistName)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Selected Window") {
                SongShapeRailView(
                    startTime: $cue.startTime,
                    duration: cue.duration,
                    timelineDuration: timelineDuration,
                    waveformSamples: waveformSamples,
                    isLoadingWaveform: waveformState == .loading,
                    previewProgress: previewProgress,
                    onMove: stopPreviewIfNeeded
                )
                .frame(height: 54)

                if waveformState == .unavailable {
                    Label("Waveform unavailable for this song", systemImage: "waveform.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    timeMetric("Start", value: timeText(cue.startTime), alignment: .leading)
                    Spacer()
                    timeMetric("Current", value: currentTimeText, alignment: .center)
                    Spacer()
                    timeMetric("End", value: "\(timeText(cue.startTime + cue.duration)) of \(timeText(timelineDuration))", alignment: .trailing)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

                Button {
                    Task { await appModel.previewCue(cue) }
                } label: {
                    Label("Preview Clip", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Section("Length") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ForEach(lengthOptions, id: \.self) { option in
                            Button("\(Int(option))s") {
                                setDuration(option)
                            }
                            .buttonStyle(.bordered)
                            .tint(abs(cue.duration - option) < 0.01 ? .accentColor : .secondary)
                        }
                    }

                    Text("We recommend 10-12 seconds for best game pace")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: 18) {
                        PrecisionTimeControl(
                            title: "Start",
                            valueText: preciseTimeText(cue.startTime),
                            canDecrease: cue.startTime > 0,
                            canIncrease: cue.startTime < maximumStartTime,
                            onAdjust: adjustStart
                        )

                        PrecisionTimeControl(
                            title: "Length",
                            valueText: secondsText(cue.duration),
                            canDecrease: cue.duration > minimumClipDuration,
                            canIncrease: cue.duration < maximumClipDuration,
                            onAdjust: adjustLength
                        )

                        PrecisionTimeControl(
                            title: "Fade Out",
                            valueText: secondsText(cue.fadeOutDuration),
                            canDecrease: cue.fadeOutDuration > 0,
                            canIncrease: cue.fadeOutDuration < maximumFadeDuration,
                            onAdjust: adjustFade
                        )
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Make Your Clip")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: waveformSourceKey) {
            await loadWaveform()
        }
        .onDisappear {
            if playbackEngine.activeCueID == cue.id {
                appModel.stopPlayback()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    appModel.rememberPreferredLength(cue.duration)
                    onSave(cue)
                }
                .fontWeight(.semibold)
            }
        }
    }

    private var timelineDuration: TimeInterval {
        max(cue.duration, appModel.cueTimelineLength(for: cue))
    }

    private var waveformSamples: [Float]? {
        guard case .ready(let samples) = waveformState else { return nil }
        return samples
    }

    private var waveformSourceKey: String {
        switch cue.source {
        case .appleMusic(let source):
            return "appleMusic|\(source.songID)"
        case .localAudio(let source):
            return "localAudio|\(source.id.uuidString)|\(source.relativePath)"
        case .builtInClip(let source):
            return "builtIn|\(source.id)"
        }
    }

    private var maximumStartTime: TimeInterval {
        max(0, timelineDuration - cue.duration)
    }

    private var minimumClipDuration: TimeInterval {
        min(1, timelineDuration)
    }

    private var maximumClipDuration: TimeInterval {
        min(20, timelineDuration)
    }

    private var maximumFadeDuration: TimeInterval {
        min(4, cue.duration)
    }

    private var previewProgress: Double? {
        guard playbackEngine.activeCueID == cue.id else { return nil }
        return playbackEngine.activeCueProgress
    }

    private var currentTimeText: String {
        guard let previewProgress else { return timeText(cue.startTime) }
        let boundedProgress = min(max(0, previewProgress), 1)
        return timeText(cue.startTime + cue.duration * boundedProgress)
    }

    private var songTitle: String {
        switch cue.source {
        case .appleMusic(let source): return source.title
        case .localAudio(let source): return source.displayName
        case .builtInClip(let source): return source.displayName
        }
    }

    private var artistName: String? {
        guard case .appleMusic(let source) = cue.source else { return nil }
        return source.artistName
    }

    private func setDuration(_ duration: TimeInterval) {
        adjustLength(by: duration - cue.duration)
    }

    private func adjustStart(by delta: TimeInterval) {
        applyTiming(
            SongClipTimingAdjustment.adjustingStart(
                startTime: cue.startTime,
                duration: cue.duration,
                fadeOutDuration: cue.fadeOutDuration,
                delta: delta,
                timelineDuration: timelineDuration
            )
        )
    }

    private func adjustLength(by delta: TimeInterval) {
        applyTiming(
            SongClipTimingAdjustment.adjustingDuration(
                startTime: cue.startTime,
                duration: cue.duration,
                fadeOutDuration: cue.fadeOutDuration,
                delta: delta,
                timelineDuration: timelineDuration
            )
        )
    }

    private func adjustFade(by delta: TimeInterval) {
        applyTiming(
            SongClipTimingAdjustment.adjustingFade(
                startTime: cue.startTime,
                duration: cue.duration,
                fadeOutDuration: cue.fadeOutDuration,
                delta: delta,
                timelineDuration: timelineDuration
            )
        )
    }

    private func applyTiming(_ timing: SongClipTimingAdjustment) {
        stopPreviewIfNeeded()
        cue.startTime = timing.startTime
        cue.duration = timing.duration
        cue.fadeOutDuration = timing.fadeOutDuration
    }

    private func stopPreviewIfNeeded() {
        guard playbackEngine.activeCueID == cue.id else { return }
        appModel.stopPlayback()
    }

    private func loadWaveform() async {
        waveformState = .loading
        guard let url = SongWaveformSourceResolver.url(for: cue) else {
            waveformState = .unavailable
            return
        }

        do {
            let samples = try await SongWaveformRepository.shared.samples(
                from: url,
                sampleCount: 64
            )
            guard !Task.isCancelled else { return }
            waveformState = .ready(samples)
        } catch {
            guard !Task.isCancelled else { return }
            waveformState = .unavailable
        }
    }

    private func timeText(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(value.rounded()))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    private func timeMetric(_ title: String, value: String, alignment: TimeMetricAlignment) -> some View {
        VStack(alignment: alignment.horizontal, spacing: 2) {
            Text(title)
                .font(.caption2)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            Text(value)
        }
        .frame(minWidth: 58, alignment: alignment.frame)
    }

    private func preciseTimeText(_ value: TimeInterval) -> String {
        let bounded = max(0, value)
        let minutes = Int(bounded) / 60
        let seconds = bounded - Double(minutes * 60)
        return "\(minutes):\(String(format: "%05.2f", seconds))"
    }

    private func secondsText(_ value: TimeInterval) -> String {
        String(format: "%.2fs", value)
    }
}

private struct PrecisionTimeControl: View {
    let title: String
    let valueText: String
    let canDecrease: Bool
    let canIncrease: Bool
    let onAdjust: (TimeInterval) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueText)
                    .font(.body.monospacedDigit())
            }

            HStack(spacing: 8) {
                adjustmentButton("-1", delta: -1, isEnabled: canDecrease)
                adjustmentButton("-0.25", delta: -0.25, isEnabled: canDecrease)
                adjustmentButton("+0.25", delta: 0.25, isEnabled: canIncrease)
                adjustmentButton("+1", delta: 1, isEnabled: canIncrease)
            }
        }
    }

    private func adjustmentButton(
        _ label: String,
        delta: TimeInterval,
        isEnabled: Bool
    ) -> some View {
        Button(label) {
            onAdjust(delta)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .frame(maxWidth: .infinity)
        .disabled(!isEnabled)
        .accessibilityLabel("\(title) \(delta < 0 ? "minus" : "plus") \(abs(delta)) seconds")
    }
}

struct SongShapeRailView: View {
    @Binding var startTime: TimeInterval
    let duration: TimeInterval
    let timelineDuration: TimeInterval
    let waveformSamples: [Float]?
    let isLoadingWaveform: Bool
    let previewProgress: Double?
    let onMove: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let geometry = SongShapeRailGeometry(
                width: width,
                startTime: startTime,
                duration: duration,
                timelineDuration: timelineDuration
            )

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.16))

                if let waveformSamples {
                    HStack(spacing: 1.5) {
                        ForEach(Array(waveformSamples.enumerated()), id: \.offset) { _, sample in
                            Capsule()
                                .fill(Color.secondary.opacity(0.48))
                                .frame(maxWidth: .infinity)
                                .frame(height: max(2, CGFloat(sample) * 38))
                        }
                    }
                    .padding(.horizontal, 8)
                } else {
                    HStack(spacing: 5) {
                        ForEach(0..<21, id: \.self) { index in
                            if index.isMultiple(of: 3) {
                                Circle()
                                    .fill(Color.secondary.opacity(0.42))
                                    .frame(width: 4, height: 4)
                            } else {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: index.isMultiple(of: 2) ? 8 : 4)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }

                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.accentColor.opacity(0.26))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.accentColor, lineWidth: 2)
                    }
                    .frame(width: geometry.selectedWidth)
                    .offset(x: geometry.offset)

                if let previewProgress {
                    let progress = min(max(0, previewProgress), 1)
                    let playheadOffset = geometry.offset + geometry.selectedWidth * progress
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: 3, height: 46)
                        .shadow(color: Color.black.opacity(0.28), radius: 1, y: 1)
                        .offset(x: min(width - 3, max(0, playheadOffset - 1.5)))
                        .allowsHitTesting(false)
                }

                if isLoadingWaveform {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onMove()
                        startTime = geometry.startTime(
                            centeredAt: value.location.x
                        )
                    }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Selected song window")
        .accessibilityValue("Starts at \(Int(startTime.rounded())) seconds and lasts \(Int(duration.rounded())) seconds")
        .accessibilityAdjustableAction { direction in
            let delta: TimeInterval = direction == .increment ? 1 : -1
            onMove()
            startTime = min(max(0, startTime + delta), max(0, timelineDuration - duration))
        }
    }
}

struct SongShapeRailGeometry {
    let width: CGFloat
    let startTime: TimeInterval
    let duration: TimeInterval
    let timelineDuration: TimeInterval

    private var boundedTimelineDuration: TimeInterval {
        max(0.01, timelineDuration)
    }

    var selectedWidth: CGFloat {
        max(2, width * duration / boundedTimelineDuration)
    }

    var offset: CGFloat {
        width * startTime / boundedTimelineDuration
    }

    func startTime(centeredAt location: CGFloat) -> TimeInterval {
        let proposedOffset = location - selectedWidth / 2
        let maximumStart = max(0, timelineDuration - duration)
        let proposedStart = boundedTimelineDuration * proposedOffset / width
        return min(max(0, proposedStart), maximumStart)
    }
}

struct SongClipTimingAdjustment: Equatable {
    let startTime: TimeInterval
    let duration: TimeInterval
    let fadeOutDuration: TimeInterval

    static func adjustingStart(
        startTime: TimeInterval,
        duration: TimeInterval,
        fadeOutDuration: TimeInterval,
        delta: TimeInterval,
        timelineDuration: TimeInterval
    ) -> Self {
        let boundedDuration = boundedDuration(duration, timelineDuration: timelineDuration)
        return Self(
            startTime: min(
                max(0, startTime + delta),
                max(0, timelineDuration - boundedDuration)
            ),
            duration: boundedDuration,
            fadeOutDuration: min(max(0, fadeOutDuration), min(4, boundedDuration))
        )
    }

    static func adjustingDuration(
        startTime: TimeInterval,
        duration: TimeInterval,
        fadeOutDuration: TimeInterval,
        delta: TimeInterval,
        timelineDuration: TimeInterval
    ) -> Self {
        let newDuration = boundedDuration(duration + delta, timelineDuration: timelineDuration)
        return Self(
            startTime: min(max(0, startTime), max(0, timelineDuration - newDuration)),
            duration: newDuration,
            fadeOutDuration: min(max(0, fadeOutDuration), min(4, newDuration))
        )
    }

    static func adjustingFade(
        startTime: TimeInterval,
        duration: TimeInterval,
        fadeOutDuration: TimeInterval,
        delta: TimeInterval,
        timelineDuration: TimeInterval
    ) -> Self {
        let boundedDuration = boundedDuration(duration, timelineDuration: timelineDuration)
        return Self(
            startTime: min(max(0, startTime), max(0, timelineDuration - boundedDuration)),
            duration: boundedDuration,
            fadeOutDuration: min(max(0, fadeOutDuration + delta), min(4, boundedDuration))
        )
    }

    private static func boundedDuration(
        _ duration: TimeInterval,
        timelineDuration: TimeInterval
    ) -> TimeInterval {
        let maximum = min(20, max(0, timelineDuration))
        let minimum = min(1, maximum)
        return min(max(minimum, duration), maximum)
    }
}

private extension String {
    var nonempty: String? {
        isEmpty ? nil : self
    }
}
