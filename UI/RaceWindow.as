// ============================================================================
// RACE WINDOW UI
// ============================================================================
// Displays race information when a race challenge is active
// ============================================================================

/**
 * Renders the race window when in RaceChallenge state
 */
void RenderRaceWindow() {
    UI::SetNextWindowSize(400, 300, UI::Cond::FirstUseEver);
    UI::SetNextWindowPos(100, 100, UI::Cond::FirstUseEver);

    int windowFlags = UI::WindowFlags::NoCollapse;

    // Make title bar have same opacity as window background
    vec4 bgColor = UI::GetStyleColor(UI::Col::WindowBg);
    UI::PushStyleColor(UI::Col::TitleBg, bgColor);
    UI::PushStyleColor(UI::Col::TitleBgActive, bgColor);
    UI::PushStyleColor(UI::Col::TitleBgCollapsed, bgColor);

    if (UI::Begin("Race Challenge", windowFlags)) {
        UI::Text(themeSectionLabelColor + "\\$f80Race Information");
        UI::Separator();

        // Map information
        UI::Text("Map: \\$fff" + raceMapName);
        if (raceMapTmxId > 0) {
            UI::Text("TMX ID: \\$fff" + raceMapTmxId);
        }

        UI::Separator();

        // Role information
        UI::Text("Your Role: \\$fff" + (isDefender ? "Defender" : "Attacker"));
        if (isDefender) {
            UI::TextWrapped(themeWarningTextColor + "You are defending!");
        } else {
            UI::TextWrapped(themeWarningTextColor + "You are attacking!");
        }

        UI::Separator();

        // Show opponent's status and time
        UI::Text(themeSectionLabelColor + "\\$f80Opponent");

        // Show opponent's live time if they're currently racing
        int opponentLiveTime = GetOpponentRaceTime();
        if (opponentIsRacing && opponentLiveTime >= 0) {
            // Opponent is currently racing - show live time (calculated locally)
            int oppSeconds = opponentLiveTime / 1000;
            int oppMilliseconds = opponentLiveTime % 1000;
            UI::Text(themeSuccessTextColor + "Racing: \\$fff" + oppSeconds + "." + Text::Format("%03d", oppMilliseconds) + "s");
        }
        // Show defender's finished time if available (for attackers)
        else if (!isDefender && defenderTime > 0) {
            // Attacker view: show defender's finished time
            int defSeconds = defenderTime / 1000;
            int defMilliseconds = defenderTime % 1000;
            UI::Text("Time to Beat: \\$fff" + defSeconds + "." + Text::Format("%03d", defMilliseconds) + "s");
        }
        // Defender view: show if opponent has started
        else if (isDefender && opponentIsRacing) {
            UI::Text(themeSuccessTextColor + "Opponent is racing...");
        }
        // Default: opponent not racing
        else {
            UI::TextDisabled("Not racing");
        }

        UI::Separator();

        // Race status
        if (raceStartedAt > 0) {
            UI::Text(themeSectionLabelColor + "\\$f80Your Race");
            UI::Text(themeSuccessTextColor + "Active");

            // Show the actual in-game race time
            int elapsedMs = GetCurrentRaceTime();
            int seconds = elapsedMs / 1000;
            int milliseconds = elapsedMs % 1000;
            UI::Text("Time: \\$fff" + seconds + "." + Text::Format("%03d", milliseconds) + "s");

            // Checkpoint times section
            RenderCheckpointComparison();
        } else {
            UI::Text(themeSectionLabelColor + "\\$f80Your Race");
            UI::TextDisabled("Not started");
            UI::TextDisabled("Load into the map to begin");
        }

        UI::NewLine();

        // Results
        if (playerFinishedRace) {
            UI::Separator();
            UI::Text(themeSectionLabelColor + "\\$f80Race Complete");

            if (playerDNF) {
                UI::Text(themeWarningTextColor + "DNF (Did Not Finish)");
            } else if (playerRaceTime > 0) {
                int seconds = playerRaceTime / 1000;
                int milliseconds = playerRaceTime % 1000;
                UI::Text("Your Time: \\$fff" + seconds + "." + Text::Format("%03d", milliseconds) + "s");
            }

            UI::NewLine();

            // Wait for opponent to finish
            UI::Text("\\$888Waiting for opponent to finish...");
        }
    }
    UI::End();

    // Pop the title bar style colors
    UI::PopStyleColor(3);
}

/**
 * Renders race results inline at the top of the main chess window
 */
void RenderRaceResultsInline() {
    UI::Text(themeSectionLabelColor + "\\$f80Race Times");

    if (lastRacePlayerTime > 0) {
        int seconds = lastRacePlayerTime / 1000;
        int milliseconds = lastRacePlayerTime % 1000;
        UI::Text("Your Time: \\$fff" + seconds + "." + Text::Format("%03d", milliseconds) + "s");
    }

    if (lastRaceOpponentTime > 0) {
        int oppSeconds = lastRaceOpponentTime / 1000;
        int oppMilliseconds = lastRaceOpponentTime % 1000;
        UI::Text("Opponent's Time: \\$fff" + oppSeconds + "." + Text::Format("%03d", oppMilliseconds) + "s");
    }

    if (lastRacePlayerTime > 0 && lastRaceOpponentTime > 0) {
        int diff = lastRacePlayerTime - lastRaceOpponentTime;
        if (diff < 0) {
            int diffSeconds = (-diff) / 1000;
            int diffMilliseconds = (-diff) % 1000;
            UI::Text(themeSuccessTextColor + "Faster by: " + diffSeconds + "." + Text::Format("%03d", diffMilliseconds) + "s");
        } else if (diff > 0) {
            int diffSeconds = diff / 1000;
            int diffMilliseconds = diff % 1000;
            UI::Text(themeWarningTextColor + "Slower by: " + diffSeconds + "." + Text::Format("%03d", diffMilliseconds) + "s");
        } else {
            UI::Text("\\$fffExactly tied!");
        }
    }

    if (StyledButton("Dismiss", vec2(80.0f, 22.0f))) {
        showRaceResults = false;
    }

    UI::Separator();
}

/**
 * Formats a time in milliseconds to a readable string (e.g. "12.345")
 */
string FormatTime(int ms) {
    int seconds = ms / 1000;
    int milliseconds = ms % 1000;
    return seconds + "." + Text::Format("%03d", milliseconds);
}

/**
 * Renders checkpoint comparison between player and opponent
 * Only shows checkpoints that have actually been hit by at least one player
 */
void RenderCheckpointComparison() {
    auto@ playerCPs = RaceStateManager::playerCheckpointTimes;
    auto@ opponentCPs = RaceMode::OpponentTracking::opponentData.checkpointTimes;

    // Count actual checkpoints hit (with valid times > 0)
    uint playerActualCPs = 0;
    for (uint i = 0; i < playerCPs.Length; i++) {
        if (playerCPs[i] > 0) playerActualCPs = i + 1;
    }

    uint opponentActualCPs = 0;
    for (uint i = 0; i < opponentCPs.Length; i++) {
        if (opponentCPs[i] > 0) opponentActualCPs = i + 1;
    }

    // Only show if we have actual checkpoint data
    if (playerActualCPs == 0 && opponentActualCPs == 0) {
        return;
    }

    UI::NewLine();
    UI::Text(themeSectionLabelColor + "\\$f80Checkpoints");

    // Only show checkpoints that have been hit by at least one player
    uint maxCPs = Math::Max(playerActualCPs, opponentActualCPs);

    for (uint i = 0; i < maxCPs; i++) {
        int playerTime = (i < playerCPs.Length) ? playerCPs[i] : -1;
        int opponentTime = (i < opponentCPs.Length) ? opponentCPs[i] : -1;

        // Skip if neither player has hit this checkpoint
        if (playerTime <= 0 && opponentTime <= 0) {
            continue;
        }

        string cpLabel = "CP " + (i + 1) + ": ";

        // Format player time
        string playerStr = (playerTime > 0) ? FormatTime(playerTime) : "---";

        // Format opponent time
        string opponentStr = (opponentTime > 0) ? FormatTime(opponentTime) : "---";

        // Calculate delta if both have times
        string deltaStr = "";
        if (playerTime > 0 && opponentTime > 0) {
            int delta = playerTime - opponentTime;
            if (delta < 0) {
                deltaStr = themeSuccessTextColor + " (-" + FormatTime(-delta) + ")";
            } else if (delta > 0) {
                deltaStr = themeWarningTextColor + " (+" + FormatTime(delta) + ")";
            } else {
                deltaStr = " (=)";
            }
        }

        UI::Text(cpLabel + "\\$fff" + playerStr + " / " + opponentStr + deltaStr);
    }
}
