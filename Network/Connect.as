// ====================
// Connection Functions
// ====================
void Init() {
    @sock = Net::Socket();
}
// Connect function
bool Connect() {
    if (sock is null) Init();
    print("[Chess] Connecting to " + serverHost + ":" + serverPort + "...");
    bool ok = sock.Connect(serverHost, uint16(serverPort));
    isConnected = ok;
    handshakeSent = false;  // Reset - will send in Update() when socket is ready
    connectionStartTime = Time::Now;  // Record when we started connecting
    if (ok) {
        trace("[Chess] Connection initiated, waiting for socket to be ready...");
    } else {
        trace("[Chess] Socket connection failed!");
    }
    return ok;
}
// Disconnect function
void Disconnect() {
    if (sock !is null) sock.Close();
    isConnected = false;
    handshakeComplete = false;
    handshakeSent = false;
    lobbiesRequested = false;
    _buf = "";
    gameId = "";
    currentLobbyId = "";
    currentLobbyPassword = "";
    lobbies.Resize(0);
}
// Update function
void Update() {
    if (!isConnected || sock is null) return;

    // Send handshake once socket is ready (after TCP connection established)
    // Wait 200ms after connection to ensure TCP handshake is complete
    if (!handshakeSent && (Time::Now - connectionStartTime) > 200 && sock.IsReady()) {
        trace("[Chess] Socket ready, sending handshake...");
        Json::Value handshake = Json::Object();
        handshake["type"] = "handshake";
        handshake["version"] = PLUGIN_VERSION;
        SendJson(handshake);
        handshakeSent = true;
        trace("[Chess] Handshake sent, waiting for server response...");
    }

    string chunk = sock.ReadRaw(32768);
    if (chunk.Length == 0) return;
    if (developerMode) print("[Chess] Received data: " + chunk.Length + " bytes");
    _buf += chunk;
    int nl;
    while ((nl = _buf.IndexOf("\n")) >= 0) {
        string line = _buf.SubStr(0, nl).Trim();
        _buf = _buf.SubStr(nl + 1);
        if (line.Length == 0) continue;
        Json::Value msg;
        try {
            msg = Json::Parse(line);
            if (msg.GetType() == Json::Type::Object) {
                HandleMsg(msg);
            } else {
                trace("Network::Update - Parsed JSON is not an object: " + line);
            }
        } catch {
            error("Network::Update - JSON parse error: " + line);
        }
    }
}
// Send JSON function
void SendJson(Json::Value &in j) {
    if (!isConnected || sock is null) {
        error("[Chess] SendJson failed - not connected");
        return;
    }
    string data = Json::Write(j) + "\n";
    Json::Value logJ = j;
    if (logJ.HasKey("password")) {
        logJ["password"] = "***";
    }
    string logData = Json::Write(logJ);
    if (developerMode) trace("[Chess] Sending " + data.Length + " bytes: " + logData.SubStr(0, 80));
    sock.WriteRaw(data);
    if (developerMode) trace("[Chess] WriteRaw completed");
}