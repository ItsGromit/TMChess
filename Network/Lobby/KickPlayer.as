void KickPlayer(const string &in playerName) {
    if (currentLobbyId.Length == 0 || !isHost) return;
    Json::Value j = Json::Object();
    j["type"] = "kick_player";
    j["lobbyId"] = currentLobbyId;
    j["playerName"] = playerName;
    SendJson(j);
}
