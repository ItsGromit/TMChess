void DownloadAndLoadMapFromTMX(int tmxId, const string &in mapName = "") {
    print("[Chess] Loading map from TMX ID: " + tmxId + (mapName.Length > 0 ? " (" + mapName + ")" : ""));
    auto app = cast<CTrackMania>(GetApp());
    if (app is null) {
        error("[Chess] Error: Could not get app instance for loading");
        return;
    }
    // Check if we're already in a map
    auto playground = cast<CSmArenaClient>(app.CurrentPlayground);
    if (playground !is null) {
        if (developerMode) trace("[Chess] Currently in a map, returning to menu first");
        app.BackToMainMenu();
        // Wait for menu transition
        for (int i = 0; i < 100; i++) {
            yield();
            auto check = cast<CSmArenaClient>(app.CurrentPlayground);
            if (check is null) {
                if (developerMode) trace("[Chess] Successfully returned to menu");
                break;
            }
        }
        sleep(1000);
    }
    auto maniaTitleAPI = app.ManiaTitleControlScriptAPI;
    if (maniaTitleAPI !is null && Permissions::PlayLocalMap()) {
        // Load map directly from TMX URL
        string mapUrl = "https://trackmania.exchange/maps/download/" + tmxId;
        trace("[Chess] Loading map from URL: " + mapUrl);
        maniaTitleAPI.PlayMap(mapUrl, "TrackMania/TM_PlayMap_Local", "");
        sleep(3000);
        auto result = cast<CSmArenaClient>(app.CurrentPlayground);
        if (result !is null) {
            if (developerMode) trace("[Chess] SUCCESS: Map loaded from TMX!");
        } else {
            if (developerMode) trace("[Chess] Map loading - please wait...");
        }
    }
}