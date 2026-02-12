// ============================================================================
// SQUARE RACE MODE - MAP ASSIGNMENT SYSTEM
// ============================================================================

namespace RaceMode {

namespace MapAssignment {

// 8x8 grid of map assignments (indexed as [row][col])
array<array<SquareMapData@>> boardMaps(8);

void InitializeBoardMaps() {
    // Initialize 8x8 grid
    for (int row = 0; row < 8; row++) {
        boardMaps[row].Resize(8);
        for (int col = 0; col < 8; col++) {
            @boardMaps[row][col] = SquareMapData();
        }
    }
}

void ApplyServerBoardMaps(const Json::Value &in boardMapsJson) {
    if (boardMapsJson.GetType() != Json::Type::Array) {
        warn("[MapAssignment] Invalid boardMaps format from server - expected Array, got " + tostring(boardMapsJson.GetType()));
        return;
    }

    // Ensure tag definitions are loaded for resolving tag IDs
    if (!ThumbnailRendering::tagDefinitionsLoaded) {
        ThumbnailRendering::LoadHardcodedTagDefinitions();
    }

    uint arrayLength = boardMapsJson.Length;
    print("[MapAssignment] Applying " + arrayLength + " server-assigned maps...");

    if (arrayLength == 0) {
        warn("[MapAssignment] Server sent empty boardMaps array!");
        return;
    }

    int mapsApplied = 0;
    for (uint i = 0; i < arrayLength && i < 64; i++) {
        int row = i / 8;
        int col = i % 8;

        Json::Value mapObj = boardMapsJson[i];
        Json::Type objType = mapObj.GetType();

        if (objType != Json::Type::Object) {
            warn("[MapAssignment] Position " + i + " is not an object (type: " + tostring(objType) + "), skipping");
            continue;
        }

        // Check if required fields exist
        if (!mapObj.HasKey("tmxId") || !mapObj.HasKey("mapName")) {
            warn("[MapAssignment] Position " + i + " missing required fields (tmxId or mapName)");
            continue;
        }

        // Ensure square data exists
        if (boardMaps[row][col] is null) {
            @boardMaps[row][col] = RaceMode::SquareMapData();
        }

        // Apply server-assigned data
        int tmxId = int(mapObj["tmxId"]);
        string mapName = string(mapObj["mapName"]);

        boardMaps[row][col].tmxId = tmxId;
        boardMaps[row][col].mapName = mapName;
        boardMaps[row][col].thumbnailUrl = "https://trackmania.exchange/mapthumb/" + tmxId;

        // Parse tag IDs and resolve to names/colors using hardcoded definitions
        boardMaps[row][col].tags.RemoveRange(0, boardMaps[row][col].tags.Length);
        if (mapObj.HasKey("tagIds") && mapObj["tagIds"].GetType() == Json::Type::String) {
            string tagIdsStr = string(mapObj["tagIds"]);
            if (tagIdsStr.Length > 0) {
                array<string> tagIdParts = tagIdsStr.Split(",");
                for (uint t = 0; t < tagIdParts.Length; t++) {
                    string trimmed = tagIdParts[t].Trim();
                    if (trimmed.Length == 0) continue;
                    int tagId = Text::ParseInt(trimmed);
                    if (tagId > 0) {
                        RaceMode::MapTag@ tag = ThumbnailRendering::LookupTag(tagId);
                        if (tag !is null) {
                            boardMaps[row][col].tags.InsertLast(tag);
                        }
                    }
                }
            }
        }

        // Log first few assignments and last one for debugging
        if (i < 3 || i == 63) {
            print("[MapAssignment] Position " + i + " (row " + row + ", col " + col + "): " + mapName + " (TMX " + tmxId + "), tags: " + boardMaps[row][col].tags.Length);
        }

        mapsApplied++;
    }

    print("[MapAssignment] Successfully applied " + mapsApplied + "/" + arrayLength + " server-assigned maps to board");

    // Verify a few random squares to ensure data persisted
    if (mapsApplied > 0) {
        print("[MapAssignment] Verification - Square [0,0]: " + (boardMaps[0][0] !is null ? boardMaps[0][0].mapName : "NULL"));
        print("[MapAssignment] Verification - Square [3,4]: " + (boardMaps[3][4] !is null ? boardMaps[3][4].mapName : "NULL"));
        print("[MapAssignment] Verification - Square [7,7]: " + (boardMaps[7][7] !is null ? boardMaps[7][7].mapName : "NULL"));
    }
}

RaceMode::SquareMapData@ GetSquareMap(int row, int col) {
    if (row < 0 || row >= 8 || col < 0 || col >= 8) {
        return null;
    }
    return boardMaps[row][col];
}

string GetMapNameByTmxId(int tmxId, const string &in fallback = "Unknown Map") {
    for (int r = 0; r < 8; r++) {
        if (uint(r) >= boardMaps.Length) break;
        if (boardMaps[r].Length == 0) continue;
        for (int c = 0; c < 8; c++) {
            if (uint(c) >= boardMaps[r].Length) break;
            SquareMapData@ data = boardMaps[r][c];
            if (data !is null && data.tmxId == tmxId && data.mapName.Length > 0) {
                return data.mapName;
            }
        }
    }
    return fallback;
}

}

}
