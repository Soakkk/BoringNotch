import Foundation

@main struct AdaptiveLayoutTests {
    static func main() {
        func check(_ value: Bool, _ message: String) {
            guard value else { fputs("FAIL: \(message)\n", stderr); exit(1) }
            print("PASS: \(message)")
        }
        let playing = PersonalPanelLayout.resolve(isPlaying: true, hasItems: true, loading: false, denied: false)
        let paused = PersonalPanelLayout.resolve(isPlaying: false, hasItems: true, loading: false, denied: false)
        let empty = PersonalPanelLayout.resolve(isPlaying: true, hasItems: false, loading: false, denied: false)
        check(empty.musicWidth > playing.musicWidth, "empty agenda gives music more room")
        check(paused.musicWidth < playing.musicWidth && paused.musicWidth >= 210, "paused player remains useful and gives agenda space")
        check(PersonalPanelLayout.resolve(isPlaying: false, hasItems: false, loading: false, denied: false) == empty, "empty day does not oscillate width when pausing")
        for playingState in [true, false] {
            for restricted in [(true, false), (false, true)] {
                let result = PersonalPanelLayout.resolve(isPlaying: playingState, hasItems: false, loading: restricted.0, denied: restricted.1)
                check(result.musicWidth <= playing.musicWidth, "loading and permissions are not mistaken for an empty day")
            }
        }
        for result in [playing, paused, empty] {
            check(result.musicWidth + result.agendaMinimumWidth + 33 <= 578, "both columns fit the fixed640pt panel")
        }
        print("Adaptive layout checks passed")
    }
}
