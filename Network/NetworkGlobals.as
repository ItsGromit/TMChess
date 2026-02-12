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
string currentLobbyRaceMode = "square"; // Track the current lobby's race mode
array<string> currentLobbyPlayerNames; // Track players in current lobby
string gameId;
bool isWhite = false;
bool isHost = false;

// ================
// Map Filter variables
// ================
int mapFilterAuthorTimeMax = 300; // No real limit by default (5 minutes max)
int mapFilterAuthorTimeMin = 0;
array<string> mapFilterSelectedTags;
array<string> mapFilterBlacklistedTags = {"Kacky", "LOL"}; // Default blacklist
bool mapFiltersChanged = false;
bool useTagWhitelist = false; // Default to blacklist mode with Kacky and LOL excluded

// ==============
// Race variables
// ==============
int raceMapTmxId = -1;
string raceMapName = "";
bool isDefender = false;
int defenderTime = -1;
string captureFrom = "";
string captureTo = "";
int activeMappackId = 7237; // Mappack ID received from server for current game

// Live race tracking
bool opponentIsRacing = false;       // Whether opponent is currently racing
uint64 opponentRaceStartedAt = 0;    // Timestamp when opponent started racing (for local time calculation)
int opponentFinalTime = -1;          // Opponent's final race time when they finish (-1 if not finished)

/**
 * Gets the opponent's current race time calculated locally.
 * Returns the final time if opponent finished, calculates live time if racing, or -1 if not racing.
 */
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
bool showRaceResults = false;        // Whether to show race results window
bool lastRaceCaptureSucceeded = false; // Whether the last race capture succeeded
int lastRacePlayerTime = -1;         // Player's final time in last race
int lastRaceOpponentTime = -1;       // Opponent's final time in last race
bool lastRacePlayerWasDefender = false; // Whether player was defender in last race

const array<string> FILES = {"a", "b", "c", "d", "e", "f", "g", "h"};

array<Lobby> lobbies;

string _buf;

string tempMapUrl = "";