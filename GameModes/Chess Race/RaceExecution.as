// ============================================================================
// Chess Race Mode - Race Execution
// ============================================================================

namespace RaceMode {

namespace RaceExecution {

// Global variables to pass capture square coordinates to the coroutine
int pendingCaptureRow = -1;
int pendingCaptureCol = -1;

void FetchSquareRaceMapWrapper() {
    if (pendingCaptureRow >= 0 && pendingCaptureCol >= 0) {
        FetchSquareRaceMap(pendingCaptureRow, pendingCaptureCol);
        pendingCaptureRow = -1;
        pendingCaptureCol = -1;
    }
}

void FetchSquareRaceMap(int row, int col) {
    print("[ChessRace::RaceExecution] FetchSquareRaceMap for square [" + row + ", " + col + "]");

    SquareMapData@ mapData = MapAssignment::GetSquareMap(row, col);
    if (mapData is null || mapData.tmxId == -1) {
        error("[ChessRace::RaceExecution] Error: No map assigned to square [" + row + ", " + col + "]");
        UI::ShowNotification("Chess", "Error: No map assigned to this square", vec4(1,0.4,0.4,1), 4000);
        return;
    }

    // Use the assigned map for this square
    trace("[ChessRace::RaceExecution] Loading assigned map: " + mapData.mapName + " (TMX ID: " + mapData.tmxId + ")");

    // Set the race map details (these are used by the race UI)
    raceMapTmxId = mapData.tmxId;
    raceMapName = mapData.mapName;

    // Reset race state
    playerFinishedRace = false;
    playerRaceTime = -1;
    playerDNF = false;
    raceStartedAt = 0;

    // Set game state to RaceChallenge (this triggers the race UI)
    GameManager::currentState = GameState::RaceChallenge;

    // Download and load the map
    DownloadAndLoadMapFromTMX(mapData.tmxId, mapData.mapName);
}

void UpdateRaceState() {
    if (!isRacingSquareMode) return;
}

}

}
