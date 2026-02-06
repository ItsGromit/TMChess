// ============================================================================
// RACE STATE MANAGER
// ============================================================================
// Handles race state detection, DNF logic, and live time updates
// ============================================================================

namespace RaceStateManager {

// Track last UISequence for debug logging
SGamePlaygroundUIConfig::EUISequence lastSeq = SGamePlaygroundUIConfig::EUISequence::None;

// Track race time stability for finish detection
int stableRaceTime = -1;
int stableRaceTimeFrames = 0;

// Give Up detection via MLFeed spawn status
bool spawnLatch = false;
bool resetProtection = false;
string curMap = "";
bool verboseMode = false;
uint lastSpawnIndex = 0;

// Checkpoint tracking
int lastCheckpointCount = 0;
array<int> playerCheckpointTimes;  // Store player's checkpoint times for display

/**
 * Resets the give-up detection state when starting a new race
 */
void ResetGiveUpDetection() {
    spawnLatch = false;
    resetProtection = true;
    lastSpawnIndex = 0;

    // Get current spawn index to establish baseline
    auto raceData = MLFeed::GetRaceData_V4();
    if (raceData !is null) {
        auto playerData = raceData.GetPlayer_V4(MLFeed::LocalPlayersName);
        if (playerData !is null) {
            lastSpawnIndex = playerData.SpawnIndex;
            if (verboseMode) print("[GiveUp] Reset detection, baseline SpawnIndex: " + lastSpawnIndex);
        }
    }
}

/**
 * Resets checkpoint tracking for a new race
 */
void ResetCheckpointTracking() {
    lastCheckpointCount = 0;
    playerCheckpointTimes.RemoveRange(0, playerCheckpointTimes.Length);
}

/**
 * Checks for new checkpoints and sends them to the server
 */
void CheckCheckpoints() {
    auto raceData = MLFeed::GetRaceData_V4();
    if (raceData is null) return;

    auto playerData = raceData.GetPlayer_V4(MLFeed::LocalPlayersName);
    if (playerData is null) return;

    // Get checkpoint times from MLFeed
    auto cpTimes = playerData.CpTimes;
    if (cpTimes is null) return;

    int currentCpCount = cpTimes.Length;

    // Check if we passed a new checkpoint
    if (currentCpCount > lastCheckpointCount) {
        // Process each new checkpoint using index-based storage (same as opponent tracking)
        for (int i = lastCheckpointCount; i < currentCpCount; i++) {
            int cpTime = cpTimes[i];

            // Ensure array is large enough for this index
            while (playerCheckpointTimes.Length <= uint(i)) {
                playerCheckpointTimes.InsertLast(-1);
            }

            if (cpTime > 0) {
                // Store locally at the correct index
                playerCheckpointTimes[i] = cpTime;

                // Send to server
                Json::Value j = Json::Object();
                j["type"] = "checkpoint";
                j["gameId"] = gameId;
                j["cpIndex"] = i;
                j["time"] = cpTime;
                SendJson(j);

                print("[Checkpoint] CP " + (i + 1) + ": " + cpTime + "ms");
            }
        }
        lastCheckpointCount = currentCpCount;
    }
}

/**
 * Check if player gave up using MLFeed spawn status tracking
 * Returns true if player gave up (DNF was triggered)
 */
bool CheckGiveUp() {
    // Get race data from MLFeed
    auto raceData = MLFeed::GetRaceData_V4();
    if (raceData is null) {
        return false;
    }

    // Get local player data
    auto playerData = raceData.GetPlayer_V4(MLFeed::LocalPlayersName);
    if (playerData is null) {
        return false;
    }

    // Check if SpawnIndex has increased (indicates respawn/give up)
    uint currentSpawnIndex = playerData.SpawnIndex;

    // Reset protection: skip the first check after race starts
    if (resetProtection) {
        lastSpawnIndex = currentSpawnIndex;
        resetProtection = false;
        if (verboseMode) print("[GiveUp] Protection reset, SpawnIndex: " + currentSpawnIndex);
        return false;
    }

    // If spawn index increased, player respawned (gave up)
    if (currentSpawnIndex > lastSpawnIndex) {
        print("[GiveUp] Player gave up! SpawnIndex changed from " + lastSpawnIndex + " to " + currentSpawnIndex);

        // Mark as DNF
        playerDNF = true;
        playerFinishedRace = true;

        // Send DNF to server
        Json::Value j = Json::Object();
        j["type"] = "dnf";
        j["gameId"] = gameId;
        SendJson(j);
        print("[GiveUp] Sent DNF to server");

        // Exit race challenge state and reopen chess window
        GameManager::currentState = GameState::Playing;
        raceStartedAt = 0;

        return true;
    }

    lastSpawnIndex = currentSpawnIndex;
    return false;
}

/**
 * Main update function for race state management
 * Call this every frame from the main Update loop
 */
void Update() {
    // Handle race state management
    if (GameManager::currentState == GameState::RaceChallenge && !playerFinishedRace) {
        // FIRST: Check if player finished the race (using TrackmaniaBingo's exact approach)
        // This must be checked BEFORE IsPlayerReady() because UISequence changes from Playing to Finish
        auto app = cast<CTrackMania>(GetApp());
        auto playground = cast<CSmArenaClient>(app.CurrentPlayground);
        auto playgroundScript = cast<CGamePlaygroundScript>(app.PlaygroundScript);

        // Check for race finish if we have valid playground
        if (playgroundScript !is null && playground !is null && playground.GameTerminals.Length > 0) {
            CGameTerminal@ terminal = playground.GameTerminals[0];
            auto seq = terminal.UISequence_Current;

            // Debug: Log UISequence changes
            if (seq != lastSeq) {
                print("[RaceDetection] UISequence changed to: " + tostring(seq));
                lastSeq = seq;
            }

            // Check UISequence FIRST before anything else (TrackmaniaBingo pattern)
            if (seq == SGamePlaygroundUIConfig::EUISequence::Finish) {
                print("[RaceDetection] Player in Finish state, attempting to retrieve ghost");

                CSmPlayer@ player = cast<CSmPlayer>(terminal.ControlledPlayer);
                if (player !is null && player.ScriptAPI !is null) {
                    CSmScriptPlayer@ playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);

                    // Retrieve ghost data (TrackmaniaBingo method)
                    auto ghost = cast<CSmArenaRulesMode>(playgroundScript).Ghost_RetrieveFromPlayer(playerScriptAPI);
                    print("[RaceDetection] Ghost retrieved: " + (ghost !is null ? "yes" : "null"));

                    if (ghost !is null && ghost.Result !is null) {
                        int finalTime = ghost.Result.Time;
                        print("[RaceDetection] Ghost result time: " + finalTime);

                        // Release ghost (TrackmaniaBingo does this)
                        playgroundScript.DataFileMgr.Ghost_Release(ghost.Id);

                        // Validate time (TrackmaniaBingo check: > 0 and < uint max)
                        if (finalTime > 0 && finalTime < 4294967295) {
                            print("[RaceDetection] Player finished race with time: " + finalTime + "ms (UISequence::Finish)");

                            playerFinishedRace = true;
                            playerRaceTime = finalTime;

                            // Send race result to server
                            Json::Value j = Json::Object();
                            j["type"] = "race_result";
                            j["gameId"] = gameId;
                            j["time"] = playerRaceTime;
                            SendJson(j);
                            print("[RaceDetection] Sent race_result to server: " + playerRaceTime + "ms");

                            // Send player back to main menu but keep race window open
                            auto app2 = cast<CTrackMania>(GetApp());
                            app2.BackToMainMenu();

                            // Reset race tracking variables
                            raceStartedAt = 0;

                            return;
                        } else {
                            print("[RaceDetection] finalTime validation failed: " + finalTime + " (must be > 0 and < 4294967295)");
                        }
                    } else {
                        if (ghost !is null) {
                            playgroundScript.DataFileMgr.Ghost_Release(ghost.Id);
                        }
                        print("[RaceDetection] Ghost or Result is null");
                    }
                } else {
                    print("[RaceDetection] Player or ScriptAPI is null");
                }
            }
        }

        // Check for give up via MLFeed spawn status (runs independently of IsPlayerReady)
        if (raceStartedAt > 0) {
            if (CheckGiveUp()) {
                return;  // Player gave up, DNF was triggered
            }
        }

        // SECOND: Check if player is ready to race (for ongoing race tracking)
        if (IsPlayerReady()) {
            if (raceStartedAt == 0) {
                // Player is now ready and in the race
                raceStartedAt = 1;
                print("[RaceDetection] Player is ready, race started");

                // Reset give-up detection for this new race
                ResetGiveUpDetection();

                // Reset local checkpoint tracking for this new race
                ResetCheckpointTracking();

                // Don't reset opponent data here - it was already reset when the
                // race_challenge message was received, and the opponent may have
                // started racing and sent checkpoints while we were still loading.

                // Send race_started message to server
                Json::Value j = Json::Object();
                j["type"] = "race_started";
                j["gameId"] = gameId;
                SendJson(j);
                print("[RaceDetection] Sent race_started to server");
            }

            // Check for new checkpoints
            CheckCheckpoints();
            
            // Fallback: Check player's Score for completed race times
            // When a player finishes, their time appears in BestRaceTimes or PrevRaceTimes
            if (playground !is null && playground.GameTerminals.Length > 0) {
                auto player = cast<CSmPlayer>(playground.GameTerminals[0].ControlledPlayer);
                if (player !is null && player.Score !is null) {
                    auto score = cast<CSmArenaScore>(player.Score);
                    if (score !is null) {
                        // Check if player has a recorded race time (indicates finish)
                        if (score.BestRaceTimes.Length > 0 && score.BestRaceTimes[0] > 0) {
                            int finalTime = int(score.BestRaceTimes[0]);

                            print("[RaceDetection] Player finished! BestRaceTime: " + finalTime + "ms");

                            playerFinishedRace = true;
                            playerRaceTime = finalTime;

                            // Send race result to server
                            Json::Value j = Json::Object();
                            j["type"] = "race_result";
                            j["gameId"] = gameId;
                            j["time"] = playerRaceTime;
                            SendJson(j);
                            print("[RaceDetection] Sent race_result to server: " + playerRaceTime + "ms");

                            // Send player back to main menu but keep race window open
                            auto app3 = cast<CTrackMania>(GetApp());
                            app3.BackToMainMenu();

                            // Reset race tracking variables
                            raceStartedAt = 0;
                            stableRaceTime = -1;
                            stableRaceTimeFrames = 0;

                            return;
                        }
                    }
                }
            }

        } else if (raceStartedAt > 0) {
            // Player was racing but is no longer ready (left playground entirely)
            if (!IsInPlayground()) {
                print("[RaceDetection] Player left playground - triggering DNF");

                // Mark as DNF
                playerDNF = true;
                playerFinishedRace = true;

                // Send DNF to server
                Json::Value j = Json::Object();
                j["type"] = "dnf";
                j["gameId"] = gameId;
                SendJson(j);

                // Exit race challenge state and reopen chess window
                GameManager::currentState = GameState::Playing;
                raceStartedAt = 0;
            }
        }
    }
}

} // namespace RaceStateManager
