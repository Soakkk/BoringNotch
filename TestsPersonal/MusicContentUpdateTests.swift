import AppKit
import SwiftUI

// Only slow/external effects are intercepted. The runner compiles the actual
// production update method against the real PlaybackState model below.
func AppIconAsNSImage(for identifier: String?) -> NSImage? { nil }
struct ProbeController { var supportsVolumeControl = true }
@MainActor class MusicUpdateProbe {
    var songTitle = "", artistName = "", album = ""
    var isPlaying = false, usingAppIconForArtwork = false
    var elapsedTime = 0.0, songDuration = 0.0, playbackRate = 1.0, volume = 0.5
    var isShuffled = false, isFavoriteTrack = false, volumeControlSupported = true
    var repeatMode: RepeatMode = .off
    var bundleIdentifier: String?
    var timestampDate = Date.distantPast
    var activeController: ProbeController? = ProbeController()
    var lastArtworkTitle = "", lastArtworkArtist = "", lastArtworkAlbum = ""
    var lastArtworkBundleIdentifier: String?
    var artworkData: Data?
    var flips = 0, artDecodes = 0
    var lyricRequests = [String]()
    func triggerFlipAnimation() { flips += 1 }
    func updateArtwork(_ data: Data) { artDecodes += 1 }
    func updateAlbumArt(newAlbumArt: NSImage) {}
    func updateSneakPeek() {}
    func updateIdleState(state: Bool) {}
    func fetchLyricsIfAvailable(bundleIdentifier: String?, title: String, artist: String) { lyricRequests.append(title + " · " + artist) }
}

@main struct MusicContentUpdateTests {
    @MainActor static func main() {
        var failures = 0
        func check(_ value: Bool, _ description: String) {
            print("\(value ? "PASS" : "FAIL"): \(description)")
            if !value { failures += 1 }
        }
        let manager = MusicUpdateProbe()
        var state = PlaybackState(bundleIdentifier: "com.spotify.client", title: "Track A", artist: "Artist", album: "Album", duration: 180, artwork: Data([1,2,3]))
        manager.updateFromPlaybackState(state)
        check(manager.flips == 1 && manager.artDecodes == 1 && manager.lyricRequests.count == 1, "first track prepares artwork and lyrics once")
        state.title = "Track B"
        manager.updateFromPlaybackState(state)
        for second in 1...20 {
            state.currentTime = Double(second)
            state.lastUpdated = Date(timeIntervalSince1970: Double(second))
            manager.updateFromPlaybackState(state)
        }
        check(manager.songTitle == "Track B" && manager.elapsedTime == 20, "same-album track and position stay current")
        check(manager.flips == 2 && manager.artDecodes == 1 && manager.lyricRequests == ["Track A · Artist", "Track B · Artist"], "same-album updates do not repeat animation, artwork decoding or lyrics requests")
        state.isPlaying = true; state.playbackRate = 1.25; state.volume = 0.3
        state.isShuffled = true; state.repeatMode = .one; state.isFavorite = true
        manager.updateFromPlaybackState(state)
        check(manager.isPlaying && manager.playbackRate == 1.25 && manager.volume == 0.3 && manager.isShuffled && manager.repeatMode == .one && manager.isFavoriteTrack, "playback controls still propagate immediately")

        let lateArt = MusicUpdateProbe()
        state.title = "Track C"; state.isPlaying = false; state.artwork = nil
        lateArt.updateFromPlaybackState(state)
        state.artwork = Data([4,5,6])
        lateArt.updateFromPlaybackState(state)
        check(lateArt.artDecodes == 1 && lateArt.artworkData == Data([4,5,6]), "late artwork is still decoded and applied")
        check(lateArt.lyricRequests == ["Track C · Artist"], "late artwork does not repeat the lyrics request")
        state.artist = "Another artist"; lateArt.updateFromPlaybackState(state)
        check(lateArt.artistName == "Another artist" && lateArt.lyricRequests.last == "Track C · Another artist", "actual metadata change refreshes lyrics")
        state.bundleIdentifier = "com.apple.Music"; lateArt.updateFromPlaybackState(state)
        check(lateArt.bundleIdentifier == "com.apple.Music" && lateArt.lyricRequests.count == 3, "changing provider refreshes native lyrics source")
        guard failures == 0 else { exit(1) }
        print("Music update regressions passed (8 checks)")
    }
}
