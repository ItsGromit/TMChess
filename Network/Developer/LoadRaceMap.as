void LoadRaceMap(const string &in mapUid) {
    if (mapUid.Length == 0) {
        print("[Chess] Cannot load map - empty UID");
        return;
    }
    print("[Chess] Loading race map with UID: " + mapUid);
    // Try to load the map directly by UID
    print("[Chess] Attempting to load map by UID: " + mapUid);
    tempMapUrl = mapUid;
    startnew(LoadMapNow);
}