Net::Socket@ sock;
bool isConnected = false;
bool handshakeComplete = false;
bool handshakeSent = false;
uint64 connectionStartTime = 0; // Timestamp when connection was initiated
bool lobbiesRequested = false; // Flag to prevent spamming list_lobbies
[Setting category="Network" name="Server host"] string serverHost = "yamanote.proxy.rlwy.net";
[Setting category="Network" name="Server port"] uint serverPort = 36621;

// Plugin version - must match server's required version
const string PLUGIN_VERSION = "1.0";

// =================
// Network variables
// =================

string playerId;
string currentLobbyId;
string currentLobbyPassword;
string currentLobbyRaceMode = "square";
array<string> currentLobbyPlayerNames;
string gameId;
bool isWhite = false;
bool isHost = false;

// ==============
// Race variables
// ==============
int raceMapTmxId = -1;
string raceMapName = "";
bool isDefender = false;
int defenderTime = -1;
string captureFrom = "";
string captureTo = "";
int activeMappackId = 7237; // Mappack ID received for current game

// Live race tracking
bool opponentIsRacing = false;
uint64 opponentRaceStartedAt = 0;
int opponentFinalTime = -1;

int GetOpponentRaceTime() {
    // If opponent finished, return their final time
    if (opponentFinalTime > 0) {
        return opponentFinalTime;
    }
    // If opponent is racing, calculate their live time
    if (opponentIsRacing && opponentRaceStartedAt > 0) {
        return int(Time::Now - opponentRaceStartedAt);
    }
    return -1;
}

// Race result tracking (to keep results window open after returning to board)
bool showRaceResults = false;
bool lastRaceCaptureSucceeded = false;
int lastRacePlayerTime = -1;
int lastRaceOpponentTime = -1;
bool lastRacePlayerWasDefender = false;

const array<string> FILES = {"a", "b", "c", "d", "e", "f", "g", "h"};

array<Lobby> lobbies;

string _buf;

string tempMapUrl = "";