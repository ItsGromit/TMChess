// ============================================================================
// CHESS RACE MODE
// ============================================================================
namespace RaceMode {

// Current race state
int selectedSquareRow = -1;
int selectedSquareCol = -1;
bool isRacingSquareMode = false;

// ============================================================================
// INITIALIZATION
// ============================================================================

void InitializeChessRace() {
    print("[ChessRace] Initializing Chess Race mode...");

    MapAssignment::InitializeBoardMaps();
    OpponentTracking::ResetOpponentData();
    isRacingSquareMode = false;

    print("[ChessRace] Initialization complete");
}

void ApplyServerBoardMapsSync(const Json::Value &in boardMapsJson) {
    InitializeChessRace();

    print("[ChessRace] Applying server-assigned board maps...");
    MapAssignment::ApplyServerBoardMaps(boardMapsJson);

    // Preload thumbnails if enabled (async)
    if (showThumbnails) {
        startnew(ThumbnailRendering::PreloadAllThumbnails);
    }
}

}
