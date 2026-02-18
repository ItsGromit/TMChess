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

// Give Up detection via MLFeed SpawnStatus transitions
MLFeed::SpawnStatus lastSpawnStatus = MLFeed::SpawnStatus::Spawning;
bool giveUpDetectorRunning = false;
bool lastFinishState = false;

// Checkpoint tracking
int lastCheckpointCount = 0;
array<int> playerCheckpointTimes;  // Store player's checkpoint times for display


void ResetGiveUpDetection() {
    lastSpawnStatus = MLFeed::SpawnStatus::Spawning;
    giveUpDetectorRunning = false;
    lastFinishState = false;
}

// Resets checkpoint tracking
void ResetCheckpointTracking() {
    lastCheckpointCount = 0;
    playerCheckpointTimes.RemoveRange(0, playerCheckpointTimes.Length);
}

// Checks for new checkpoints then sends to server
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


bool CheckGiveUp() {
    auto raceData = MLFeed::GetRaceData_V4();
    if (raceData is null) return false;

    auto playerData = raceData.GetPlayer_V4(MLFeed::LocalPlayersName);
    if (playerData is null) return false;

    // Start tracking once the player begins racing
    if (!giveUpDetectorRunning && playerData.CurrentRaceTime < 0
        && playerData.SpawnStatus == MLFeed::SpawnStatus::Spawning) {
        giveUpDetectorRunning = true;
        return false;
    }

    // Detect SpawnStatus transitions while running
    if (giveUpDetectorRunning && playerData.SpawnStatus != lastSpawnStatus) {
        lastSpawnStatus = playerData.SpawnStatus;

        // If status changed back to Spawning without finishing, it's a give-up
        if (!lastFinishState && playerData.SpawnStatus == MLFeed::SpawnStatus::Spawning) {
            auto app = cast<CTrackMania>(GetApp());
            print("[GiveUp] Player gave up! SpawnStatus transitioned back to Spawning");

            playerDNF = true;
            playerFinishedRace = true;

            Json::Value j = Json::Object();
            j["type"] = "dnf";
            j["gameId"] = gameId;
            SendJson(j);
            print("[GiveUp] Sent DNF to server");

            GameManager::currentState = GameState::Playing;
            app.BackToMainMenu();
            raceStartedAt = 0;

            return true;
        }
    }

    // Track finish state to avoid false positives on post-finish respawns
    if (playerData.IsFinished) {
        lastFinishState = true;
    } else if (playerData.SpawnStatus == MLFeed::SpawnStatus::Spawned) {
        lastFinishState = false;
    }

    return false;
}

void Update() {
    // Handle race state management
    if (GameManager::currentState == GameState::RaceChallenge && !playerFinishedRace) {
        auto app = cast<CTrackMania>(GetApp());
        auto playground = cast<CSmArenaClient>(app.CurrentPlayground);
        auto playgroundScript = cast<CGamePlaygroundScript>(app.PlaygroundScript);

        // Check for race finish if we have valid playground
        if (playgroundScript !is null && playground !is null && playground.GameTerminals.Length > 0) {
            CGameTerminal@ terminal = playground.GameTerminals[0];
            auto seq = terminal.UISequence_Current;

            if (seq != lastSeq) {
                trace("[RaceDetection] UISequence changed to: " + tostring(seq));
                lastSeq = seq;
            }

            if (seq == SGamePlaygroundUIConfig::EUISequence::Finish) {
                trace("[RaceDetection] Player in Finish state, attempting to retrieve ghost");

                CSmPlayer@ player = cast<CSmPlayer>(terminal.ControlledPlayer);
                if (player !is null && player.ScriptAPI !is null) {
                    CSmScriptPlayer@ playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);

                    // Retrieve ghost data (TrackmaniaBingo method)
                    auto ghost = cast<CSmArenaRulesMode>(playgroundScript).Ghost_RetrieveFromPlayer(playerScriptAPI);
                    trace("[RaceDetection] Ghost retrieved: " + (ghost !is null ? "yes" : "null"));

                    if (ghost !is null && ghost.Result !is null) {
                        int finalTime = ghost.Result.Time;
                        trace("[RaceDetection] Ghost result time: " + finalTime);

                        // Release ghost (TrackmaniaBingo does this)
                        playgroundScript.DataFileMgr.Ghost_Release(ghost.Id);

                        // Validate time (TrackmaniaBingo check: > 0 and < uint max)
                        if (finalTime > 0 && finalTime < 4294967295) {
                            trace("[RaceDetection] Player finished race with time: " + finalTime + "ms (UISequence::Finish)");

                            playerFinishedRace = true;
                            playerRaceTime = finalTime;

                            // Send race result to server
                            Json::Value j = Json::Object();
                            j["type"] = "race_result";
                            j["gameId"] = gameId;
                            j["time"] = playerRaceTime;
                            SendJson(j);
                            trace("[RaceDetection] Sent race_result to server: " + playerRaceTime + "ms");

                            // Send player back to main menu but keep race window open
                            auto app2 = cast<CTrackMania>(GetApp());
                            app2.BackToMainMenu();

                            // Reset race tracking variables
                            raceStartedAt = 0;

                            return;
                        } else {
                            error("[RaceDetection] finalTime validation failed: " + finalTime + " (must be > 0 and < 4294967295)");
                        }
                    } else {
                        if (ghost !is null) {
                            playgroundScript.DataFileMgr.Ghost_Release(ghost.Id);
                        }
                        trace("[RaceDetection] Ghost or Result is null");
                    }
                } else {
                    trace("[RaceDetection] Player or ScriptAPI is null");
                }
            }
        }

        // Check for give up via MLFeed spawn status (runs independently of IsPlayerReady)
        if (raceStartedAt > 0) {
            if (CheckGiveUp()) {
                return;
            }
        }

        if (IsPlayerReady()) {
            if (raceStartedAt == 0) {
                // Player is now ready and in the race
                raceStartedAt = 1;
                print("[RaceDetection] Player is ready, race started");

                // Reset give-up detection for this new race
                ResetGiveUpDetection();

                // Reset local checkpoint tracking for this new race
                ResetCheckpointTracking();

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

                            print("[RaceDetection] Player finished! Race Time: " + finalTime + "ms");

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

}
