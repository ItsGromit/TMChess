// ============================================================================
// AUDIO MANAGER
// ============================================================================
// Manages loading and playing sound effects for chess events
// Sound files should be placed in the Sounds/ folder within the plugin
// ============================================================================

namespace ChessAudio {

// Sound sample references
Audio::Sample@ moveSound;
Audio::Sample@ moveOpponentSound;
Audio::Sample@ captureSound;
Audio::Sample@ checkSound;
Audio::Sample@ checkmateSound;
Audio::Sample@ castleSound;
Audio::Sample@ gameStartSound;

// Settings
[Setting category="Audio" name="Enable Sound Effects"]
bool enableSounds = true;

[Setting category="Audio" name="Sound Volume" min=0.0 max=1.0]
float soundVolume = 0.5f;

/**
 * Safely loads a sound sample, returns null if file not found
 */
Audio::Sample@ TryLoadSample(const string &in path) {
    try {
        return Audio::LoadSample(path);
    } catch {
        return null;
    }
}

/**
 * Loads all sound effects from the Sounds folder within the plugin
 */
void LoadSounds() {
    // Load sounds from the plugin's Sounds folder using relative paths
    // TryLoadSample handles missing files gracefully
    @moveSound = TryLoadSample("Sounds/move.wav");
    @moveOpponentSound = TryLoadSample("Sounds/move-opponent.wav");
    @captureSound = TryLoadSample("Sounds/capture.wav");
    @checkSound = TryLoadSample("Sounds/check.wav");
    @checkmateSound = TryLoadSample("Sounds/checkmate.wav");
    @castleSound = TryLoadSample("Sounds/castle.wav");
    @gameStartSound = TryLoadSample("Sounds/game-start.wav");

    if (developerMode) {
        print("[Audio] Loaded chess sounds");
        print("[Audio] moveSound: " + (moveSound is null ? "null" : "loaded"));
        print("[Audio] moveOpponentSound: " + (moveOpponentSound is null ? "null" : "loaded"));
        print("[Audio] captureSound: " + (captureSound is null ? "null" : "loaded"));
        print("[Audio] checkSound: " + (checkSound is null ? "null" : "loaded"));
        print("[Audio] checkmateSound: " + (checkmateSound is null ? "null" : "loaded"));
        print("[Audio] castleSound: " + (castleSound is null ? "null" : "loaded"));
        print("[Audio] gameStartSound: " + (gameStartSound is null ? "null" : "loaded"));
    }
}

/**
 * Plays a move sound effect
 */
void PlayMoveSound() {
    if (!enableSounds || moveSound is null) return;
    Audio::Play(moveSound, soundVolume);
}

/**
 * Plays a capture sound effect
 */
void PlayCaptureSound() {
    if (!enableSounds || captureSound is null) return;
    Audio::Play(captureSound, soundVolume);
}

/**
 * Plays a check sound effect
 */
void PlayCheckSound() {
    if (!enableSounds || checkSound is null) return;
    Audio::Play(checkSound, soundVolume);
}

/**
 * Plays a checkmate sound effect
 */
void PlayCheckmateSound() {
    if (!enableSounds || checkmateSound is null) return;
    Audio::Play(checkmateSound, soundVolume);
}

/**
 * Plays a castle sound effect
 */
void PlayCastleSound() {
    if (!enableSounds || castleSound is null) return;
    Audio::Play(castleSound, soundVolume);
}

/**
 * Plays a game start sound effect
 */
void PlayGameStartSound() {
    if (!enableSounds || gameStartSound is null) return;
    Audio::Play(gameStartSound, soundVolume);
}

/**
 * Plays an opponent move sound effect
 */
void PlayMoveOpponentSound() {
    if (!enableSounds || moveOpponentSound is null) return;
    Audio::Play(moveOpponentSound, soundVolume);
}

} // namespace ChessAudio
