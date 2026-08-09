import Foundation

actor SongClipGenerationQueue {
    enum PauseReason: Hashable {
        case lowPowerMode
    }

    private var pending: [SongClipPreparationRequest] = []
    private var active: SongClipPreparationRequest?
    private var cancelledActiveRequestIDs: Set<UUID> = []
    private var pauseReasons: Set<PauseReason> = []

    func enqueue(_ request: SongClipPreparationRequest) {
        pending.removeAll {
            $0.teamID == request.teamID
                && $0.target == request.target
                && $0.clipID == request.clipID
        }
        pending.append(request)
    }

    func next() -> SongClipPreparationRequest? {
        guard active == nil, !pending.isEmpty else { return nil }
        let requestIndex: Int
        if pauseReasons.isEmpty {
            requestIndex = pending.startIndex
        } else if pauseReasons == [.lowPowerMode],
                  let explicitIndex = pending.firstIndex(where: \.isExplicit) {
            requestIndex = explicitIndex
        } else {
            return nil
        }
        let request = pending.remove(at: requestIndex)
        active = request
        return request
    }

    func complete(_ request: SongClipPreparationRequest) {
        guard active?.id == request.id else { return }
        active = nil
        cancelledActiveRequestIDs.remove(request.id)
    }

    @discardableResult
    func cancel(teamID: UUID, target: SongClipPreparationRequest.Target? = nil) -> Bool {
        pending.removeAll { request in
            request.teamID == teamID && (target == nil || request.target == target)
        }
        guard let active,
              active.teamID == teamID,
              target == nil || active.target == target else {
            return false
        }
        cancelledActiveRequestIDs.insert(active.id)
        return true
    }

    func isCancelled(_ request: SongClipPreparationRequest) -> Bool {
        cancelledActiveRequestIDs.contains(request.id)
    }

    func hasRunnableWork() -> Bool {
        guard !pending.isEmpty else { return false }
        if pauseReasons.isEmpty {
            return true
        }
        return pauseReasons == [.lowPowerMode] && pending.contains(where: \.isExplicit)
    }

    func setPaused(_ paused: Bool, reason: PauseReason) {
        if paused {
            pauseReasons.insert(reason)
        } else {
            pauseReasons.remove(reason)
        }
    }

    func pendingCount() -> Int {
        pending.count + (active == nil ? 0 : 1)
    }
}

@MainActor
/// Owns the serialized preparation runner and its cancellation lifecycle.
/// AppModel supplies domain lookup, live-use throttling, and outcome application.
final class SongClipPreparationCoordinator {
    private let queue = SongClipGenerationQueue()
    private let prepare: @Sendable (SongClip) async -> SongClipPreparationOutcome
    private let audioAssetService: AudioAssetService
    private var runnerTask: Task<Void, Never>?
    private var activePreparationTask: Task<SongClipPreparationOutcome, Never>?

    init(
        generationService: SongClipGenerationService,
        audioAssetService: AudioAssetService
    ) {
        self.prepare = { clip in await generationService.prepare(clip) }
        self.audioAssetService = audioAssetService
    }

    init(
        audioAssetService: AudioAssetService,
        prepare: @escaping @Sendable (SongClip) async -> SongClipPreparationOutcome
    ) {
        self.prepare = prepare
        self.audioAssetService = audioAssetService
    }

    func enqueue(_ request: SongClipPreparationRequest) async {
        await queue.enqueue(request)
    }

    func pendingCount() async -> Int {
        await queue.pendingCount()
    }

    func setPaused(_ paused: Bool, reason: SongClipGenerationQueue.PauseReason) async {
        await queue.setPaused(paused, reason: reason)
    }

    func cancel(
        teamID: UUID,
        target: SongClipPreparationRequest.Target? = nil
    ) async {
        if await queue.cancel(teamID: teamID, target: target) {
            runnerTask?.cancel()
            activePreparationTask?.cancel()
        }
    }

    func runIfNeeded(
        clipFor: @escaping @MainActor (SongClipPreparationRequest) -> SongClip?,
        waitForSlot: @escaping @MainActor () async -> Bool,
        applyOutcome: @escaping @MainActor (SongClipPreparationOutcome, SongClipPreparationRequest) -> Void
    ) async {
        while true {
            if let existingRunnerTask = runnerTask {
                await existingRunnerTask.value
            } else {
                runnerTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    defer { self.runnerTask = nil }

                    while !Task.isCancelled, let request = await self.queue.next() {
                        let slotAvailable = await waitForSlot()
                        guard slotAvailable,
                              !Task.isCancelled,
                              !(await self.queue.isCancelled(request)) else {
                            await self.queue.complete(request)
                            continue
                        }
                        guard let clip = clipFor(request) else {
                            await self.queue.complete(request)
                            continue
                        }

                        let prepare = self.prepare
                        let preparationTask = Task.detached(priority: .utility) {
                            await prepare(clip)
                        }
                        self.activePreparationTask = preparationTask
                        let outcome = await preparationTask.value
                        self.activePreparationTask = nil

                        guard !preparationTask.isCancelled,
                              !(await self.queue.isCancelled(request)) else {
                            if case .generated(let asset) = outcome {
                                self.audioAssetService.removeAsset(relativePath: asset.relativePath)
                            }
                            await self.queue.complete(request)
                            continue
                        }

                        applyOutcome(outcome, request)
                        await self.queue.complete(request)
                    }
                }

                await runnerTask?.value
            }

            guard await queue.hasRunnableWork() else { return }
        }
    }
}
