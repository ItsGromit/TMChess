// ============================================================================
// AUDIO MANAGER
// ============================================================================
// Manages loading and playing sound effects for chess events
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
Audio::Sample@ gameLossSound;
Audio::Sample@ gameWinSound;
Audio::Sample@ gameDrawSound;
Audio::Sample@ gameRematchSound;

// Settings
[Setting category="Audio" name="Enable Sound Effects"]
bool enableSounds = true;

[Setting category="Audio" name="Sound Volume" min=0.0 max=1.0]
float soundVolume;

// Loads a sound sample, returns null if file not found
Audio::Sample@ TryLoadSample(const string &in path) {
    try {
        return Audio::LoadSample(path);
    } catch {
        return null;
    }
}

void LoadSounds() {
    @moveSound = TryLoadSample("Sounds/move.wav");
    @moveOpponentSound = TryLoadSample("Sounds/move.wav");
    @captureSound = TryLoadSample("Sounds/capture.wav");
    @checkSound = TryLoadSample("Sounds/check.wav");
    @checkmateSound = TryLoadSample("Sounds/notification.wav");
    @castleSound = TryLoadSample("Sounds/castle.wav");
    @gameStartSound = TryLoadSample("Sounds/notification.wav");
    @gameLossSound = TryLoadSample("Sounds/defeat.wav");
    @gameWinSound = TryLoadSample("Sounds/victory.wav");
    @gameDrawSound = TryLoadSample("Sounds/draw.wav");
    @gameRematchSound = TryLoadSample("Sounds/rematch.wav");

    if (developerMode) {
        trace("[Audio] Loaded chess sounds");
        trace("[Audio] moveSound: " + (moveSound is null ? "null" : "loaded"));
        trace("[Audio] moveOpponentSound: " + (moveOpponentSound is null ? "null" : "loaded"));
        trace("[Audio] captureSound: " + (captureSound is null ? "null" : "loaded"));
        trace("[Audio] checkSound: " + (checkSound is null ? "null" : "loaded"));
        trace("[Audio] checkmateSound: " + (checkmateSound is null ? "null" : "loaded"));
        trace("[Audio] castleSound: " + (castleSound is null ? "null" : "loaded"));
        trace("[Audio] gameStartSound: " + (gameStartSound is null ? "null" : "loaded"));
        trace("[Audio] gameLossSound: " + (gameLossSound is null ? "null" : "loaded"));
        trace("[Audio] gameWinSound: " + (gameWinSound is null ? "null" : "loaded"));
        trace("[Audio] gameDrawSound: " + (gameDrawSound is null ? "null" : "loaded"));
        trace("[Audio] gameRematchSound: " + (gameRematchSound is null ? "null" : "loaded"));
    }
}

void PlayMoveSound() {
    if (!enableSounds || moveSound is null) return;
    Audio::Play(moveSound, soundVolume);
}

void PlayCaptureSound() {
    if (!enableSounds || captureSound is null) return;
    Audio::Play(captureSound, soundVolume);
}

void PlayCheckSound() {
    if (!enableSounds || checkSound is null) return;
    Audio::Play(checkSound, soundVolume);
}

void PlayCheckmateSound() {
    if (!enableSounds || checkmateSound is null) return;
    Audio::Play(checkmateSound, soundVolume);
}

void PlayCastleSound() {
    if (!enableSounds || castleSound is null) return;
    Audio::Play(castleSound, soundVolume);
}

void PlayGameStartSound() {
    if (!enableSounds || gameStartSound is null) return;
    Audio::Play(gameStartSound, soundVolume);
}

void PlayMoveOpponentSound() {
    if (!enableSounds || moveOpponentSound is null) return;
    Audio::Play(moveOpponentSound, soundVolume);
}

void PlayGameLossSound() {
    if (!enableSounds || gameLossSound is null) return;
    Audio::Play(gameLossSound, soundVolume);
}

void PlayGameWinSound() {
    if (!enableSounds || gameWinSound is null) return;
    Audio::Play(gameWinSound, soundVolume);
}

void PlayGameDrawSound() {
    if (!enableSounds || gameDrawSound is null) return;
    Audio::Play(gameDrawSound, soundVolume);
}

void PlayGameRematchSound() {
    if (!enableSounds || gameRematchSound is null) return;
    Audio::Play(gameRematchSound, soundVolume);
}

}

