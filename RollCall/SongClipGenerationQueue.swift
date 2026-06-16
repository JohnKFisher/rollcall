import Foundation

actor SongClipGenerationQueue {
    enum PauseReason: Hashable {
        case lowPowerMode
    }

    private var pending: [SongClipPreparationRequest] = []
    private var active: SongClipPreparationRequest?
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
    }

    func cancel(teamID: UUID, playerID: UUID) {
        pending.removeAll { $0.teamID == teamID && $0.target == .player(playerID) }
    }

    func cancel(teamID: UUID, teamClipID: UUID) {
        pending.removeAll { $0.teamID == teamID && $0.target == .teamClip(teamClipID) }
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
