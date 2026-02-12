    void HandleMsg(Json::Value &msg) {
        if (msg.GetType() != Json::Type::Object) {
            print("Network::HandleMsg - Invalid message type: " + msg.GetType());
            return;
        }

        string t = msg["type"];

        if (t == "hello") {
            playerId = string(msg["id"]);
            handshakeComplete = true;
            print("[Chess] Handshake complete - playerId: " + playerId);
        }
        else if (t == "version_mismatch") {
            string requiredVersion = msg.HasKey("requiredVersion") ? string(msg["requiredVersion"]) : "unknown";
            string currentVersion = msg.HasKey("clientVersion") ? string(msg["clientVersion"]) : PLUGIN_VERSION;
            print("[Chess] VERSION MISMATCH - Server requires version " + requiredVersion + ", you have " + currentVersion);
            UI::ShowNotification("Chess Race - Version Mismatch", "Please update your plugin to version " + requiredVersion + ". You have " + currentVersion + ".", vec4(1,0.2,0.2,1), 10000);
            // Disconnect from server
            Disconnect();
        }
        else if (t == "lobby_list") {
            lobbies.Resize(0);
            auto arr = msg["lobbies"];
            for (uint i = 0; i < arr.Length; i++) {
                Lobby l;
                auto e = arr[i];
                l.id          = string(e["id"]);
                l.title       = e.HasKey("title") ? string(e["title"]) : "";
                l.hostId      = string(e["hostId"]);
                l.players     = int(e["players"]);
                l.open        = bool(e["open"]);
                l.hasPassword = bool(e["hasPassword"]);
                l.password    = l.hasPassword ? "*" : "";
                l.raceMode    = e.HasKey("raceMode") ? string(e["raceMode"]) : "square";
                l.playerNames.Resize(0);
                if (e["playerNames"].GetType() != Json::Type::Null) {
                    for (uint j = 0; j < e["playerNames"].Length; j++) {
                        l.playerNames.InsertLast(string(e["playerNames"][j]));
                    }
                }
                lobbies.InsertLast(l);
            }
        }
        else if (t == "lobby_created") {
            currentLobbyId = string(msg["lobbyId"]);
            isHost = true;
            // Store the lobby's race mode
            if (msg.HasKey("raceMode")) {
                currentLobbyRaceMode = string(msg["raceMode"]);
                // Update the global currentRaceMode enum
                currentRaceMode = RaceMode::SquareRace;
            }
            // Initialize player names array (creator is the only player initially)
            currentLobbyPlayerNames.Resize(0);
            currentLobbyPlayerNames.InsertLast(GetLocalPlayerName());
            print("[Chess] Lobby successfully created - LobbyId: " + currentLobbyId);
            GameManager::currentState = GameState::InLobby;
        }
        else if (t == "lobby_update") {
            string id = string(msg["lobbyId"]);
            if (id == currentLobbyId || currentLobbyId.Length == 0) {
                currentLobbyId = id;
                string host = string(msg["hostId"]);
                isHost = (host == playerId);
                // Store the lobby's race mode
                if (msg.HasKey("raceMode")) {
                    currentLobbyRaceMode = string(msg["raceMode"]);
                    // Update the global currentRaceMode enum
                    currentRaceMode = RaceMode::SquareRace;
                }
                // Store player names
                currentLobbyPlayerNames.Resize(0);
                if (msg.HasKey("playerNames") && msg["playerNames"].GetType() != Json::Type::Null) {
                    for (uint j = 0; j < msg["playerNames"].Length; j++) {
                        currentLobbyPlayerNames.InsertLast(string(msg["playerNames"][j]));
                    }
                }
                // Transition to InLobby state when joining (from InQueue or Menu state)
                if (currentLobbyId.Length > 0 &&
                    (GameManager::currentState == GameState::InQueue || GameManager::currentState == GameState::Menu)) {
                    GameManager::currentState = GameState::InLobby;
                    GetMapFilters(currentLobbyId);
                }
            }
        }
        else if (t == "lobby_closed") {
            string closedLobbyId = string(msg["lobbyId"]);
            string message = msg.HasKey("message") ? string(msg["message"]) : "Lobby was closed";
            print("[Chess] Lobby closed - " + message);

            // Only process if this was our current lobby
            if (closedLobbyId == currentLobbyId) {
                // Show notification to the player
                UI::ShowNotification("Chess", "Lobby closed: " + message, vec4(1,0.4,0.4,1), 5000);

                // Reset lobby state (similar to LeaveLobby)
                currentLobbyId = "";
                currentLobbyPassword = "";
                currentLobbyRaceMode = "square";
                currentLobbyPlayerNames.Resize(0);
                isHost = false;

                // Return to menu
                GameManager::currentState = GameState::Menu;
            }
        }
        else if (t == "kicked") {
            string kickedLobbyId = string(msg["lobbyId"]);
            string message = msg.HasKey("message") ? string(msg["message"]) : "You were kicked from the lobby";
            print("[Chess] Kicked from lobby - " + message);

            // Only process if this was our current lobby
            if (kickedLobbyId == currentLobbyId) {
                // Show notification to the player
                UI::ShowNotification("Chess", message, vec4(1,0.4,0.4,1), 5000);

                // Reset lobby state
                currentLobbyId = "";
                currentLobbyPassword = "";
                currentLobbyRaceMode = "square";
                currentLobbyPlayerNames.Resize(0);
                isHost = false;

                // Return to menu
                GameManager::currentState = GameState::Menu;
            }
        }
        else if (t == "game_start") {
            gameId  = string(msg["gameId"]);
            isWhite = bool(msg["isWhite"]);
            string fen  = string(msg["fen"]);
            string turn = string(msg["turn"]); // "w"/"b"

            // Receive race mode from server
            if (msg.HasKey("raceMode")) {
                string raceModeStr = string(msg["raceMode"]);
                currentRaceMode = RaceMode::SquareRace;

                // Receive mappack ID for Chess Race mode
                if (msg.HasKey("mappackId")) {
                    activeMappackId = int(msg["mappackId"]);
                    print("[Chess] Game starting - gameId: " + gameId + ", isWhite: " + isWhite + ", turn: " + turn + ", mode: " + raceModeStr + ", mappack: " + activeMappackId);
                } else {
                    print("[Chess] Game starting - gameId: " + gameId + ", isWhite: " + isWhite + ", turn: " + turn + ", mode: " + raceModeStr);
                }
            } else {
                print("[Chess] Game starting - gameId: " + gameId + ", isWhite: " + isWhite + ", turn: " + turn);
            }

            // Reset game state variables
            gameOver = false;
            gameResult = "";
            moveHistory.Resize(0); // Clear move history for new game
            rematchRequestReceived = false;
            rematchRequestSent = false;
            showRaceResults = false; // Hide race results from previous game

            ApplyFEN(fen, turn);
            GameManager::currentState = GameState::Playing;

            // Play game start sound
            ChessAudio::PlayGameStartSound();

            // Initialize Chess Race mode
            if (currentRaceMode == RaceMode::SquareRace) {
                // Check if server sent board map assignments
                if (msg.HasKey("boardMaps")) {
                    Json::Type boardMapsType = msg["boardMaps"].GetType();
                    print("[Chess] boardMaps field present - type: " + tostring(boardMapsType));

                    if (boardMapsType == Json::Type::Array) {
                        uint mapCount = msg["boardMaps"].Length;
                        print("[Chess] Receiving " + mapCount + " board map assignments from server...");

                        // Log first few maps for debugging
                        if (mapCount > 0) {
                            print("[Chess] Sample server maps - pos 0: " + string(msg["boardMaps"][0]["mapName"]) + ", pos 1: " + string(msg["boardMaps"][1]["mapName"]));
                        }

                        // Apply server maps directly (can't pass Json::Value to startnew)
                        RaceMode::ApplyServerBoardMapsSync(msg["boardMaps"]);
                    } else if (boardMapsType == Json::Type::Null) {
                        warn("[Chess] boardMaps is null - server should provide board maps");
                    } else {
                        warn("[Chess] boardMaps has unexpected type: " + tostring(boardMapsType));
                    }
                } else {
                    warn("[Chess] No boardMaps field - server should provide board maps");
                }
            }

            print("[Chess] Game state updated to Playing");
        } else if (t == "moved") {
            string fen  = string(msg["fen"]);
            string turn = string(msg["turn"]);

            // Parse move information and add to history
            string san = "";
            if (msg.HasKey("from") && msg.HasKey("to")) {
                string fromAlg = string(msg["from"]);
                string toAlg = string(msg["to"]);

                // Convert algebraic notation to row/col
                int fromRow, fromCol, toRow, toCol;
                if (AlgToRowCol(fromAlg, fromRow, fromCol) && AlgToRowCol(toAlg, toRow, toCol)) {
                    Move@ m = Move(fromRow, fromCol, toRow, toCol);

                    // Store SAN notation if provided by server
                    if (msg.HasKey("san")) {
                        m.san = string(msg["san"]);
                        san = m.san;
                    }

                    moveHistory.InsertLast(m);
                }
            }

            ApplyFEN(fen, turn);

            // Determine if this was opponent's move or our move
            // turn indicates whose turn is NEXT, so if turn matches our color, opponent just moved
            bool wasOpponentMove = (isWhite && turn == "w") || (!isWhite && turn == "b");

            // Play sound effects based on the move
            if (san.Length > 0) {
                if (san.Contains("O-O")) {
                    // Castling move
                    ChessAudio::PlayCastleSound();
                } else if (san.Contains("+")) {
                    // Check (includes moves ending with + but not #)
                    if (!san.Contains("#")) {
                        ChessAudio::PlayCheckSound();
                    }
                } else if (san.Contains("x")) {
                    // Capture
                    ChessAudio::PlayCaptureSound();
                } else {
                    // Normal move - different sound for player vs opponent
                    if (wasOpponentMove) {
                        ChessAudio::PlayMoveOpponentSound();
                    } else {
                        ChessAudio::PlayMoveSound();
                    }
                }
            }
        } else if (t == "game_over") {
            string reason = string(msg["reason"]);
            string winner = msg.HasKey("winner") ? string(msg["winner"]) : "none";
            print("[Chess] Game over - reason: " + reason + ", winner: " + winner + ", gameId: " + gameId);

            // Play checkmate sound
            if (reason == "checkmate") {
                ChessAudio::PlayCheckmateSound();
            }

            GameManager::currentState = GameState::GameOver;
            gameOver = true;
            gameResult = (winner.Length > 0 ? winner : "none") + " — " + reason;
            print("[Chess] gameId preserved for rematch: " + gameId);
        } else if (t == "race_challenge") {
            raceMapTmxId = int(msg["tmxId"]);
            raceMapName = msg.HasKey("mapName") ? string(msg["mapName"]) : RaceMode::MapAssignment::GetMapNameByTmxId(raceMapTmxId);
            isDefender = bool(msg["isDefender"]);
            captureFrom = string(msg["from"]);
            captureTo = string(msg["to"]);
            defenderTime = -1;

            print("[Chess] Race challenge started - Map: " + raceMapName + " (TMX ID: " + raceMapTmxId + "), You are: " + (isDefender ? "Defender" : "Attacker"));

            // Reset race state - timer will start when map loads
            raceStartedAt = 0;
            playerFinishedRace = false;
            playerRaceTime = -1;
            playerDNF = false;

            // Reset opponent race state
            opponentIsRacing = false;
            opponentRaceStartedAt = 0;
            opponentFinalTime = -1;

            // Reset opponent checkpoint data for the new race
            RaceMode::OpponentTracking::ResetOpponentData();

            // Download and load the race map from TMX
            GameManager::currentState = GameState::RaceChallenge;
            DownloadAndLoadMapFromTMX(raceMapTmxId, raceMapName);
        } else if (t == "race_defender_finished") {
            // Defender finished their race - we are the attacker
            defenderTime = int(msg["time"]);
            // Store opponent's (defender's) final time and stop their timer
            opponentFinalTime = defenderTime;
            opponentIsRacing = false;
            print("[Chess] Defender finished race in " + defenderTime + "ms");
        } else if (t == "opponent_race_started") {
            // Opponent started racing - record timestamp for local time calculation
            opponentIsRacing = true;
            opponentRaceStartedAt = Time::Now;
            print("[Chess] Opponent started racing");
        } else if (t == "opponent_checkpoint") {
            // Opponent passed a checkpoint
            int cpIndex = int(msg["cpIndex"]);
            int cpTime = int(msg["time"]);
            RaceMode::OpponentTracking::ReceiveOpponentCheckpoint(cpIndex, cpTime);
            print("[Chess] Opponent passed CP " + (cpIndex + 1) + ": " + cpTime + "ms");
        } else if (t == "opponent_finished") {
            // Opponent (attacker) finished their race - we are the defender
            int time = int(msg["time"]);
            // Store opponent's final time and stop their timer
            opponentFinalTime = time;
            opponentIsRacing = false;
            print("[Chess] Opponent (attacker) finished race in " + time + "ms");
        } else if (t == "opponent_retired") {
            // Opponent retired/respawned
            opponentIsRacing = false;
            opponentRaceStartedAt = 0;
            opponentFinalTime = -1;
            print("[Chess] Opponent retired/respawned");
        } else if (t == "promotion_required") {
            // Attacker won race on a promotion capture - need to select promotion piece
            pendingPromotionFrom = string(msg["from"]);
            pendingPromotionTo = string(msg["to"]);
            isPendingPromotion = true;
            print("[Chess] Promotion required - won race, select promotion piece");

            // Save race results to show in results window
            showRaceResults = true;
            lastRaceCaptureSucceeded = true;
            lastRacePlayerTime = playerRaceTime;
            lastRaceOpponentTime = GetOpponentRaceTime();
            lastRacePlayerWasDefender = false; // Attacker always

            // Return to playing state so promotion dialog shows
            GameManager::currentState = GameState::Playing;

            // Reset race state
            raceMapTmxId = -1;
            raceMapName = "";
            isDefender = false;
            defenderTime = -1;
            captureFrom = "";
            captureTo = "";
            opponentIsRacing = false;
            opponentRaceStartedAt = 0;
            opponentFinalTime = -1;
        } else if (t == "race_result") {
            // Race completed, apply the result
            bool captureSucceeded = bool(msg["captureSucceeded"]);
            string fen = string(msg["fen"]);
            string turn = string(msg["turn"]);
            bool waitingForPromotion = msg.HasKey("waitingForPromotion") && bool(msg["waitingForPromotion"]);

            print("[Chess] Race result - Capture " + (captureSucceeded ? "succeeded" : "failed") + (waitingForPromotion ? " (waiting for promotion)" : ""));

            // Save race results to show in results window (unless waiting for promotion on defender side)
            if (!waitingForPromotion) {
                showRaceResults = true;
                lastRaceCaptureSucceeded = captureSucceeded;
                lastRacePlayerTime = playerRaceTime;
                lastRaceOpponentTime = GetOpponentRaceTime();
                lastRacePlayerWasDefender = isDefender;
            }

            // Apply the board state (if not waiting for promotion)
            if (!waitingForPromotion) {
                ApplyFEN(fen, turn);
            }
            GameManager::currentState = GameState::Playing;

            // Reset race state
            raceMapTmxId = -1;
            raceMapName = "";
            isDefender = false;
            defenderTime = -1;
            captureFrom = "";
            captureTo = "";
            opponentIsRacing = false;
            opponentRaceStartedAt = 0;
            opponentFinalTime = -1;
        } else if (t == "rematch_request") {
            print("[Chess] Received rematch request from opponent");
            rematchRequestReceived = true;
            rematchRequestSent = false;
            UI::ShowNotification("Chess", "Your opponent wants a rematch!", vec4(0.2,0.8,0.2,1), 5000);
        } else if (t == "rematch_sent") {
            print("[Chess] Rematch request sent to opponent");
            rematchRequestSent = true;
            rematchRequestReceived = false;
            UI::ShowNotification("Chess", "Rematch request sent. Waiting for opponent...", vec4(0.8,0.8,0.2,1), 4000);
        } else if (t == "rematch_declined") {
            print("[Chess] Rematch declined");
            rematchRequestReceived = false;
            rematchRequestSent = false;
            UI::ShowNotification("Chess", "Rematch declined", vec4(1,0.4,0.4,1), 4000);
        } else if (t == "reroll_request") {
            print("[Chess] Received re-roll request from opponent");
            rerollRequestReceived = true;
            rerollRequestSent = false;
            UI::ShowNotification("Chess", "Your opponent wants to re-roll the map!", vec4(0.2,0.8,0.2,1), 5000);
        } else if (t == "reroll_sent") {
            print("[Chess] Re-roll request sent to opponent");
            rerollRequestSent = true;
            rerollRequestReceived = false;
            UI::ShowNotification("Chess", "Re-roll request sent. Waiting for opponent...", vec4(0.8,0.8,0.2,1), 4000);
        } else if (t == "reroll_declined") {
            print("[Chess] Re-roll declined");
            rerollRequestReceived = false;
            rerollRequestSent = false;
            UI::ShowNotification("Chess", "Re-roll declined", vec4(1,0.4,0.4,1), 4000);
        } else if (t == "reroll_approved") {
            print("[Chess] Re-roll approved - loading new map");
            rerollRequestReceived = false;
            rerollRequestSent = false;

            // Update map info and load new map
            raceMapTmxId = int(msg["tmxId"]);
            raceMapName = msg.HasKey("mapName") ? string(msg["mapName"]) : RaceMode::MapAssignment::GetMapNameByTmxId(raceMapTmxId);

            print("[Chess] New map: " + raceMapName + " (TMX ID: " + raceMapTmxId + ")");
            UI::ShowNotification("Chess", "Loading new map: " + raceMapName, vec4(0.2,0.8,0.2,1), 5000);

            DownloadAndLoadMapFromTMX(raceMapTmxId, raceMapName);
        } else if (t == "map_filters_updated") {
            print("[Chess] Map filters updated for lobby");
            // Update local filter values from server
            if (msg.HasKey("filters")) {
                auto filters = msg["filters"];
                if (filters.HasKey("authortimemax")) {
                    mapFilterAuthorTimeMax = int(filters["authortimemax"]);
                }
                if (filters.HasKey("authortimemin")) {
                    mapFilterAuthorTimeMin = int(filters["authortimemin"]);
                }
                if (filters.HasKey("tags")) {
                    mapFilterSelectedTags.Resize(0);
                    auto tagsArray = filters["tags"];
                    for (uint i = 0; i < tagsArray.Length; i++) {
                        mapFilterSelectedTags.InsertLast(string(tagsArray[i]));
                    }
                }
                if (filters.HasKey("excludeTags")) {
                    mapFilterBlacklistedTags.Resize(0);
                    auto excludeTagsArray = filters["excludeTags"];
                    for (uint i = 0; i < excludeTagsArray.Length; i++) {
                        mapFilterBlacklistedTags.InsertLast(string(excludeTagsArray[i]));
                    }
                }
            }
        } else if (t == "map_filters") {
            print("[Chess] Received current map filters");
            // Update local filter values from server
            if (msg.HasKey("filters")) {
                auto filters = msg["filters"];
                if (filters.HasKey("authortimemax")) {
                    mapFilterAuthorTimeMax = int(filters["authortimemax"]);
                }
                if (filters.HasKey("authortimemin")) {
                    mapFilterAuthorTimeMin = int(filters["authortimemin"]);
                }
                if (filters.HasKey("tags")) {
                    mapFilterSelectedTags.Resize(0);
                    auto tagsArray = filters["tags"];
                    for (uint i = 0; i < tagsArray.Length; i++) {
                        mapFilterSelectedTags.InsertLast(string(tagsArray[i]));
                    }
                }
                if (filters.HasKey("excludeTags")) {
                    mapFilterBlacklistedTags.Resize(0);
                    auto excludeTagsArray = filters["excludeTags"];
                    for (uint i = 0; i < excludeTagsArray.Length; i++) {
                        mapFilterBlacklistedTags.InsertLast(string(excludeTagsArray[i]));
                    }
                }
            }
        } else if (t == "error") {
            string errorCode = string(msg["code"]);
            if (errorCode == "REMATCH_ALREADY_SENT") {
                UI::ShowNotification("Chess", "You have already sent a rematch request", vec4(1,0.4,0.4,1), 4000);
            } else if (errorCode == "INCORRECT_PASSWORD" || errorCode == "WRONG_PASSWORD") {
                Lobby::showPasswordPrompt = true;
                Lobby::showIncorrectPassword = true;
                Lobby::passwordPromptInput = "";
            } else if (errorCode == "INVALID_PLAYER_COUNT") {
                UI::ShowNotification("Chess", "Need exactly 2 players to start the game", vec4(1,0.4,0.4,1), 4000);
            } else {
                UI::ShowNotification("Chess", "Error: " + errorCode, vec4(1,0.4,0.4,1), 4000);
            }
        }
    }