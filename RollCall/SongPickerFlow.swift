import MediaPlayer
import MusicKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MusicLibrarySong: Identifiable, Equatable {
    let persistentID: UInt64
    let storeID: String?
    let title: String
    let artistName: String
    let albumTitle: String
    let duration: TimeInterval
    let dateAdded: Date?

    var id: UInt64 { persistentID }

    var searchResult: MusicSearchResult? {
        guard let storeID, !storeID.isEmpty else { return nil }
        return MusicSearchResult(
            songID: storeID,
            title: title,
            artistName: artistName,
            duration: duration,
            previewURL: nil,
            isCatalogBacked: true
        )
    }
}

struct DeviceMusicLibraryService {
    func songs() -> [MusicLibrarySong] {
        (MPMediaQuery.songs().items ?? []).map { item in
            MusicLibrarySong(
                persistentID: item.persistentID,
                storeID: item.playbackStoreID.nilIfEmpty,
                title: item.title?.nilIfEmpty ?? "Untitled Song",
                artistName: item.artist?.nilIfEmpty ?? "Unknown Artist",
                albumTitle: item.albumTitle?.nilIfEmpty ?? "Unknown Album",
                duration: item.playbackDuration,
                dateAdded: item.dateAdded
            )
        }
    }
}

struct SongPickerFlow: View {
    private struct DraftRoute: Identifiable, Hashable {
        let id = UUID()
        let cue: Cue
        let isImported: Bool

        static func == (lhs: DraftRoute, rhs: DraftRoute) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let onSave: (Cue) -> Void

    @State private var selectedDraft: DraftRoute?
    @State private var importPresented = false
    @State private var savedDraftID: UUID?

    var body: some View {
        NavigationStack {
            SongPickerView(
                appModel: appModel,
                onSelect: { result in
                    selectedDraft = DraftRoute(
                        cue: appModel.chooseSuggestedHook(
                            for: appModel.makeAppleMusicCueDraft(result)
                        ),
                        isImported: false
                    )
                },
                onImport: {
                    importPresented = true
                }
            )
            .navigationDestination(item: $selectedDraft) { draft in
                SongClipEditorView(
                    appModel: appModel,
                    initialCue: draft.cue
                ) { cue in
                    savedDraftID = draft.id
                    onSave(cue)
                    dismiss()
                }
            }
        }
        .fileImporter(
            isPresented: $importPresented,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task {
                guard let cue = await appModel.makeImportedSongCueDraft(from: url) else { return }
                selectedDraft = DraftRoute(cue: cue, isImported: true)
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
    }
}

private enum SongLibrarySection: String, CaseIterable, Identifiable {
    case recentlyAdded = "Recently Added"
    case artists = "Artists"
    case albums = "Albums"
    case songs = "Songs"
    case search = "Search"

    var id: String { rawValue }
}

private enum SongSearchScope: String, CaseIterable, Identifiable {
    case library = "Library"
    case appleMusic = "Apple Music"

    var id: String { rawValue }
}

struct SongPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let onSelect: (MusicSearchResult) -> Void
    let onImport: () -> Void

    @State private var selectedSection: SongLibrarySection = .recentlyAdded
    @State private var searchScope: SongSearchScope = .library
    @State private var searchTerm = ""
    @State private var librarySongs: [MusicLibrarySong] = []
    @State private var catalogResults: [MusicSearchResult] = []
    @State private var isCatalogSearching = false
    @State private var catalogSearchError: String?
    @State private var showPermissionPrimer = false

    private let libraryService = DeviceMusicLibraryService()

    var body: some View {
        Group {
            if selectedSection == .search {
                pickerList
                    .searchable(
                        text: $searchTerm,
                        prompt: searchScope == .library ? "Search Library" : "Search Apple Music"
                    )
            } else {
                pickerList
            }
        }
        .navigationTitle("Choose Song")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            if appModel.needsAppleMusicAccessPrompt {
                showPermissionPrimer = true
            } else {
                reloadLibrary()
            }
        }
        .task(id: catalogSearchKey) {
            await searchCatalogIfNeeded()
        }
        .onChange(of: selectedSection) { _, section in
            if section != .search {
                searchTerm = ""
            }
        }
        .alert("Use Music?", isPresented: $showPermissionPrimer) {
            Button("Not Now", role: .cancel) { }
            Button("Continue") {
                Task {
                    let status = await appModel.requestAppleMusicAccess()
                    if status == .authorized {
                        reloadLibrary()
                    }
                }
            }
        } message: {
            Text("Roll Call uses Music access so you can choose songs from this iPhone's music library. If you use Apple Music, you can also search Apple Music for songs that are not already in your library.")
        }
    }

    private var pickerList: some View {
        List {
            permissionRecoverySection

            Section {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    ForEach(SongLibrarySection.allCases) { section in
                        Button(section.rawValue) {
                            selectedSection = section
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedSection == section ? .accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 2)
            }

            content

            Section("More Options") {
                Button(action: onImport) {
                    Label("Import Audio or Video", systemImage: "square.and.arrow.down")
                }
                Text("Use a file when Music is not the right source or you want a portable copy.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .recentlyAdded:
            songSection(
                title: "Recently Added",
                songs: librarySongs
                    .sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
                    .prefix(40)
                    .map { $0 }
            )
        case .artists:
            groupedSongs(title: "Artists", key: \.artistName)
        case .albums:
            groupedSongs(title: "Albums", key: \.albumTitle)
        case .songs:
            songSection(
                title: "Songs",
                songs: librarySongs.sorted {
                    $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
            )
        case .search:
            searchContent
        }
    }

    @ViewBuilder
    private var permissionRecoverySection: some View {
        if MusicAuthorization.currentStatus == .denied || MusicAuthorization.currentStatus == .restricted {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Music Access Is Off", systemImage: "music.note.slash")
                        .font(.headline)
                    Text("Enable Music access to browse this iPhone's library. You can still import an audio or video file.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        Section {
            Picker("Search", selection: $searchScope) {
                ForEach(SongSearchScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
        }

        if searchScope == .library {
            let matches = librarySearchResults
            songSection(title: "Library Results", songs: matches)
            if !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               matches.isEmpty {
                Section {
                    Button("Search Apple Music for \"\(searchTerm)\"") {
                        searchScope = .appleMusic
                    }
                }
            }
        } else {
            Section("Apple Music Results") {
                if isCatalogSearching {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Searching Apple Music...")
                            .foregroundStyle(.secondary)
                    }
                } else if let catalogSearchError {
                    Text(catalogSearchError)
                        .foregroundStyle(.secondary)
                } else if catalogResults.isEmpty {
                    Text(searchTerm.isEmpty ? "Enter a song, artist, or album." : "No songs found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(catalogResults) { result in
                        catalogRow(result)
                    }
                }
            }
        }
    }

    private var librarySearchResults: [MusicLibrarySong] {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        return librarySongs.filter {
            $0.title.localizedCaseInsensitiveContains(term)
                || $0.artistName.localizedCaseInsensitiveContains(term)
                || $0.albumTitle.localizedCaseInsensitiveContains(term)
        }
    }

    private var catalogSearchKey: String {
        "\(searchScope.rawValue)|\(searchTerm)"
    }

    @ViewBuilder
    private func songSection(title: String, songs: [MusicLibrarySong]) -> some View {
        Section(title) {
            if songs.isEmpty {
                Text(emptyLibraryMessage)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(songs) { song in
                    libraryRow(song)
                }
            }
        }
    }

    @ViewBuilder
    private func groupedSongs(title: String, key: KeyPath<MusicLibrarySong, String>) -> some View {
        let groups = Dictionary(grouping: librarySongs, by: { $0[keyPath: key] })
        if groups.isEmpty {
            Section(title) {
                Text(emptyLibraryMessage)
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(groups.keys.sorted(), id: \.self) { group in
                Section(group) {
                    ForEach(groups[group, default: []]) { song in
                        libraryRow(song)
                    }
                }
            }
        }
    }

    private func libraryRow(_ song: MusicLibrarySong) -> some View {
        Button {
            guard let result = song.searchResult else { return }
            onSelect(result)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .foregroundStyle(.primary)
                    Text(song.artistName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if song.searchResult == nil {
                    Text("Unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(song.searchResult == nil)
    }

    private func catalogRow(_ result: MusicSearchResult) -> some View {
        Button {
            onSelect(result)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .foregroundStyle(.primary)
                Text(result.artistName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyLibraryMessage: String {
        switch MusicAuthorization.currentStatus {
        case .authorized:
            return "No matching songs were found in this iPhone's music library."
        case .denied, .restricted:
            return "Music access is off. Open Settings or import a file."
        default:
            return "Allow Music access to browse this iPhone's library."
        }
    }

    private func reloadLibrary() {
        librarySongs = libraryService.songs()
    }

    private func searchCatalogIfNeeded() async {
        guard selectedSection == .search, searchScope == .appleMusic else {
            catalogResults = []
            catalogSearchError = nil
            isCatalogSearching = false
            return
        }
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            catalogResults = []
            catalogSearchError = nil
            isCatalogSearching = false
            return
        }
        isCatalogSearching = true
        catalogSearchError = nil
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        do {
            catalogResults = try await appModel.musicCatalogService.search(term: term, mode: .previewFallback)
        } catch {
            catalogResults = []
            catalogSearchError = error.localizedDescription
        }
        isCatalogSearching = false
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
                        Slider(
                            value: $cue.startTime,
                            in: 0...max(0, timelineDuration - cue.duration),
                            step: 0.25
                        )
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
        cue.startTime = min(cue.startTime, max(0, timelineDuration - cue.duration))
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
            startTime = min(
                max(0, startTime + delta),
                max(0, timelineDuration - duration)
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
