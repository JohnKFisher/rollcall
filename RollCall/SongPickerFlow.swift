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
    let onSave: (Cue) -> Void

    @State private var selectedDraft: DraftRoute?
    @State private var importPresented = false
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
                importPresented = true
            }
        }
        .fileImporter(
            isPresented: $importPresented,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    dismiss()
                    return
                }
                Task {
                    guard let cue = await appModel.makeImportedSongCueDraft(from: url) else { return }
                    selectedDraft = DraftRoute(cue: cue, isImported: true)
                }
            case .failure(let error):
                pickerError = error.localizedDescription
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
            Color.clear
                .navigationTitle("Import Audio")
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
                    isCatalogBacked: true
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
            selectedDraft = DraftRoute(cue: cue, isImported: true)
        }
    }

    private func openEditor(for result: MusicSearchResult) {
        selectedDraft = DraftRoute(
            cue: appModel.chooseSuggestedHook(for: appModel.makeAppleMusicCueDraft(result)),
            isImported: false
        )
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
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchTerm, prompt: "Songs, artists, and albums")
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
            results = try await appModel.musicCatalogService.search(term: term, mode: .previewFallback)
        } catch {
            results = []
            searchError = error.localizedDescription
        }
        isSearching = false
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
    @ObservedObject var appModel: AppModel
    let onSave: (Cue) -> Void

    @State private var cue: Cue
    @State private var showAdvanced = false

    private let lengthOptions: [TimeInterval] = [8, 10, 12, 15, 20]

    init(appModel: AppModel, initialCue: Cue, onSave: @escaping (Cue) -> Void) {
        self.appModel = appModel
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
                    timelineDuration: timelineDuration
                )
                .frame(height: 54)

                HStack {
                    Text(timeText(cue.startTime))
                    Spacer()
                    Text("\(timeText(cue.startTime + cue.duration)) of \(timeText(timelineDuration))")
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
                HStack {
                    ForEach(lengthOptions, id: \.self) { option in
                        Button("\(Int(option))s") {
                            setDuration(option)
                        }
                        .buttonStyle(.bordered)
                        .tint(abs(cue.duration - option) < 0.01 ? .accentColor : .secondary)
                    }
                }
            }

            Section {
                DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Start: \(timeText(cue.startTime))")
                        if maximumStartTime > 0 {
                            Slider(
                                value: $cue.startTime,
                                in: 0...maximumStartTime,
                                step: 0.25
                            )
                        } else {
                            Text("This clip uses the full available song window, so its start is fixed.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Text("Fade out: \(cue.fadeOutDuration, specifier: "%.1f") seconds")
                        Slider(
                            value: $cue.fadeOutDuration,
                            in: 0...min(4, cue.duration),
                            step: 0.25
                        )
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Make Your Clip")
        .navigationBarTitleDisplayMode(.inline)
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

    private var maximumStartTime: TimeInterval {
        max(0, timelineDuration - cue.duration)
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
        cue.duration = min(duration, timelineDuration)
        cue.startTime = min(cue.startTime, maximumStartTime)
    }

    private func timeText(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(value.rounded()))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

struct SongShapeRailView: View {
    @Binding var startTime: TimeInterval
    let duration: TimeInterval
    let timelineDuration: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let selectedWidth = max(24, width * duration / max(duration, timelineDuration))
            let maxOffset = max(0, width - selectedWidth)
            let offset = maxOffset == 0
                ? 0
                : maxOffset * startTime / max(0.01, timelineDuration - duration)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.16))

                HStack(spacing: 3) {
                    ForEach(0..<24, id: \.self) { index in
                        Capsule()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(height: CGFloat(12 + (index * 11) % 28))
                    }
                }
                .padding(.horizontal, 8)

                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.accentColor.opacity(0.26))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.accentColor, lineWidth: 2)
                    }
                    .frame(width: selectedWidth)
                    .offset(x: offset)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let centeredOffset = value.location.x - selectedWidth / 2
                                let clampedOffset = min(max(0, centeredOffset), maxOffset)
                                let availableTime = max(0, timelineDuration - duration)
                                startTime = maxOffset == 0 ? 0 : availableTime * clampedOffset / maxOffset
                            }
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Selected song window")
        .accessibilityValue("Starts at \(Int(startTime.rounded())) seconds and lasts \(Int(duration.rounded())) seconds")
        .accessibilityAdjustableAction { direction in
            let delta: TimeInterval = direction == .increment ? 1 : -1
            startTime = min(max(0, startTime + delta), max(0, timelineDuration - duration))
        }
    }
}

private extension String {
    var nonempty: String? {
        isEmpty ? nil : self
    }
}
