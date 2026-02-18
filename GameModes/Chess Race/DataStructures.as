// ============================================================================
// SQUARE RACE MODE - DATA STRUCTURES
// ============================================================================

namespace RaceMode {

// Represents a tag with name and color
class MapTag {
    string name;
    string color; // Hexcolor from TMX (e.g., "00ff00")

    MapTag() {}
    MapTag(const string &in n, const string &in c) {
        name = n;
        color = c;
    }
}

// Represents a map assigned to a chess board square
class SquareMapData {
    int tmxId = -1;
    string mapName = "";
    string mapUid = "";
    string thumbnailUrl = "";
    UI::Texture@ thumbnailTexture;
    bool thumbnailLoading = false;
    bool thumbnailFailed = false;
    int thumbnailRetryCount = 0;
    int authorTime = -1;
    int difficulty = 0;
    array<MapTag@> tags;

    SquareMapData() {}
}

// Stores opponent's checkpoint data during a race
class OpponentCheckpointData {
    array<int> checkpointTimes;
    int finalTime = -1;
    bool hasFinished = false;
    int currentCheckpoint = 0;

    void Reset() {
        checkpointTimes.RemoveRange(0, checkpointTimes.Length);
        finalTime = -1;
        hasFinished = false;
        currentCheckpoint = 0;
    }
}

}
