// ============================================================================
// LOBBY UI
// ============================================================================
// Handles rendering of lobby creation, browsing, and management
// ============================================================================

namespace Lobby {

string JoinStrings(const array<string> &in arr, const string &in separator) {
    if (arr.Length == 0) return "";
    if (arr.Length == 1) return arr[0];

    string result = arr[0];
    for (uint i = 1; i < arr.Length; i++) {
        result += separator + arr[i];
    }
    return result;
}

// Lobby creation state
bool isCreatingLobby = false;
string newLobbyTitle = "";
string newLobbyPassword = "";

// Password prompt state
bool showPasswordPrompt = false;
string passwordPromptLobbyId = "";
string passwordPromptInput = "";
bool showIncorrectPassword = false;

void RenderLobbyList() {
    UI::Text("\\$f80Available Lobbies:");
    UI::SameLine();

    // Add some spacing before the refresh button
    float availWidth = UI::GetContentRegionAvail().x;
    UI::SetCursorPos(UI::GetCursorPos() + vec2(availWidth - 100.0f, 0));

    if (StyledButton(Icons::Refresh + " Refresh", vec2(100.0f, 0))) {
        ListLobbies();
    }

    UI::Separator();

    if (lobbies.Length == 0) {
        UI::TextDisabled("No lobbies available. Create one to get started!");
        return;
    }

    // Display lobbies
    for (uint i = 0; i < lobbies.Length; i++) {
        Lobby@ lobby = lobbies[i];

        UI::PushID("lobby_" + i);

        // Lobby title and info
        string lobbyTitle = lobby.title != "" ? lobby.title : "Untitled Lobby";
        string playerCount = lobby.players + "/2";
        string lockIcon = lobby.hasPassword ? Icons::Lock + " " : "";
        string modeIcon = lobby.raceMode == "square" ? "🏁 " : "♟️ ";

        UI::Text(modeIcon + lockIcon + lobbyTitle + " (" + playerCount + ")");

        // Player names
        if (lobby.playerNames.Length > 0) {
            UI::SameLine();
            UI::TextDisabled("- " + JoinStrings(lobby.playerNames, ", "));
        }

        UI::SameLine();

        // Join button
        if (lobby.open && lobby.players < 2) {
            if (StyledButton("Join", vec2(60.0f, 0))) {
                if (lobby.hasPassword) {
                    showPasswordPrompt = true;
                    passwordPromptLobbyId = lobby.id;
                    passwordPromptInput = "";
                } else {
                    JoinLobby(lobby.id, "");
                }
            }
        } else {
            UI::BeginDisabled();
            UI::Button("Full", vec2(60.0f, 0));
            UI::EndDisabled();
        }

        UI::PopID();
    }

    // Password prompt inline
    if (showPasswordPrompt) {
        UI::Separator();
        if (showIncorrectPassword) {
            UI::Text(themeWarningTextColor + "Incorrect password");
        } else {
            UI::Text("Enter password:");
        }
        UI::SetNextItemWidth(UI::GetContentRegionAvail().x);
        passwordPromptInput = UI::InputText("##joinpassword", passwordPromptInput, UI::InputTextFlags::Password);

        UI::NewLine();

        if (StyledButton("Join", vec2(100.0f, 25.0f))) {
            showIncorrectPassword = false;
            JoinLobby(passwordPromptLobbyId, passwordPromptInput);
        }

        UI::SameLine();

        if (StyledButton("Cancel", vec2(100.0f, 25.0f))) {
            showPasswordPrompt = false;
            showIncorrectPassword = false;
            passwordPromptLobbyId = "";
            passwordPromptInput = "";
        }
    }
}

void RenderCreateLobby() {
    if (StyledButton("+ Create Lobby", vec2(150.0f, 30.0f))) {
        isCreatingLobby = true;
        newLobbyTitle = GetLocalPlayerName() + "'s Chess Lobby";
        newLobbyPassword = "";
    }
}

void RenderCreateLobbyPage() {
    UI::Text("\\$f80Create New Lobby");
    UI::Separator();

    UI::Text("Lobby Title:");
    UI::SetNextItemWidth(300);
    newLobbyTitle = UI::InputText("##lobbytitle", newLobbyTitle);

    UI::NewLine();

    UI::Text("Mappack:");
    UI::SetNextItemWidth(100);
    string mappackIdStr = "" + squareRaceMappackId;
    mappackIdStr = UI::InputText("##mappackid", mappackIdStr, UI::InputTextFlags::CharsDecimal);
    int parsedId = Text::ParseInt(mappackIdStr);
    if (parsedId > 0) squareRaceMappackId = parsedId;
    if (squareRaceMappackId < 1) squareRaceMappackId = 1;
    if (UI::IsItemHovered()) {
        UI::BeginTooltip();
        UI::PushTextWrapPos(250.0f);
        UI::Text("TMX Mappack ID (default: 7237 for Chess Race). Find mappack IDs at trackmania.exchange");
        UI::PopTextWrapPos();
        UI::EndTooltip();
    }

    UI::NewLine();

    UI::Text("Password (optional):");
    UI::SetNextItemWidth(200);
    newLobbyPassword = UI::InputText("##lobbypassword", newLobbyPassword, UI::InputTextFlags::Password);
    if (UI::IsItemHovered()) {
        UI::BeginTooltip();
        UI::Text("Leave blank for no password");
        UI::EndTooltip();
    }

    UI::NewLine();

    if (StyledButton("Create", vec2(100.0f, 30.0f))) {
        // Password is only set if the field is not blank
        string password = (newLobbyPassword.Length > 0) ? newLobbyPassword : "";
        CreateLobby(newLobbyTitle, password);
        isCreatingLobby = false;
    }

    UI::SameLine();

    if (StyledButton("Cancel", vec2(100.0f, 30.0f))) {
        isCreatingLobby = false;
    }
}

void RenderCurrentLobby() {
    // Show players in lobby
    UI::Text("Players (" + currentLobbyPlayerNames.Length + "/2):");
    if (currentLobbyPlayerNames.Length > 0) {
        for (uint i = 0; i < currentLobbyPlayerNames.Length; i++) {
            string playerName = currentLobbyPlayerNames[i];
            // Mark the host (index 0)
            if (i == 0) {
                UI::Text("  \\$0f0" + playerName + " (Host)");
            } else {
                // Non-host players - show kick button for host
                if (isHost) {
                    UI::PushID("kick_" + i);
                    if (StyledButton("  " + playerName + " " + Icons::Times, vec2(0, 20))) {
                        KickPlayer(playerName);
                    }
                    if (UI::IsItemHovered()) {
                        UI::BeginTooltip();
                        UI::Text("Click to kick " + playerName);
                        UI::EndTooltip();
                    }
                    UI::PopID();
                } else {
                    UI::Text("  " + playerName);
                }
            }
        }
    } else {
        UI::TextDisabled("  No players");
    }

    UI::NewLine();

    // Host controls
    if (isHost) {
        UI::Text("\\$0f0You are the host");

        bool canStart = currentLobbyPlayerNames.Length >= 2;
        if (!canStart) {
            UI::BeginDisabled();
        }
        if (StyledButton("Start Game", vec2(150.0f, 30.0f))) {
            StartGame();
        }
        if (!canStart) {
            UI::EndDisabled();
            if (UI::IsItemHovered(UI::HoveredFlags::AllowWhenDisabled)) {
                UI::BeginTooltip();
                UI::Text("2 players needed to start");
                UI::EndTooltip();
            }
        }
    } else {
        UI::TextDisabled("Waiting for host to start...");
    }

    UI::NewLine();

    if (StyledButton("Leave Lobby", vec2(150.0f, 30.0f))) {
        LeaveLobby();
        GameManager::currentState = GameState::Menu;
    }
}

}
