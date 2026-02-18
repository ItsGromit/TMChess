// ============================================================================
// UI MENU TABS
// ============================================================================
// Handles rendering of menu tabs (Home, Play, Settings)
// ============================================================================

/**
 * Renders the menu state UI with tabs
 */
void RenderMenuState() {
    float lockButtonWidth = 30.0f;
    float barHeight = 30.0f;
    vec2 contentAvail = UI::GetContentRegionAvail();
    vec2 barCursor = UI::GetCursorPos();

    // Lock button at right
    RenderLockButton("menu", barHeight);

    // Reset cursor and add tab buttons as left-aligned elements
    UI::SetCursorPos(barCursor);

    // Home tab
    UI::PushStyleColor(UI::Col::Button, currentMenuTab == MenuTab::Home ? themeActiveTabColor : themeInactiveTabColor);
    UI::PushStyleColor(UI::Col::ButtonHovered, themeActiveTabColor);
    UI::PushStyleColor(UI::Col::ButtonActive, themeActiveTabColor);
    if (UI::Button("Home", vec2(80.0f, barHeight))) {
        currentMenuTab = MenuTab::Home;
    }
    UI::PopStyleColor(3);

    UI::SameLine();

    // Play tab
    UI::PushStyleColor(UI::Col::Button, currentMenuTab == MenuTab::Play ? themeActiveTabColor : themeInactiveTabColor);
    UI::PushStyleColor(UI::Col::ButtonHovered, themeActiveTabColor);
    UI::PushStyleColor(UI::Col::ButtonActive, themeActiveTabColor);
    if (UI::Button("Play", vec2(80.0f, barHeight)) && Permissions::PlayLocalMap()) {
        currentMenuTab = MenuTab::Play;
    }
    UI::PopStyleColor(3);

    UI::SameLine();

    // Settings tab
    UI::PushStyleColor(UI::Col::Button, currentMenuTab == MenuTab::Settings ? themeActiveTabColor : themeInactiveTabColor);
    UI::PushStyleColor(UI::Col::ButtonHovered, themeActiveTabColor);
    UI::PushStyleColor(UI::Col::ButtonActive, themeActiveTabColor);
    if (UI::Button("Settings", vec2(80.0f, barHeight))) {
        currentMenuTab = MenuTab::Settings;
    }
    UI::PopStyleColor(3);

    // Tab content
    if (currentMenuTab == MenuTab::Home) {
        RenderHomeTab();
    } else if (currentMenuTab == MenuTab::Play) {
        RenderPlayTab();
    } else if (currentMenuTab == MenuTab::Settings) {
        RenderSettingsTab();
    }
}

/**
 * Renders the Home tab content
 */
void RenderHomeTab() {
    // Render TMChess logo at the top
    RenderLogoCentered(350.0f);

    // Center the welcome text
    string welcomeText = "Welcome to Chess Race! This is where chess clashes with Trackmania";
    vec2 availRegion = UI::GetContentRegionAvail();

    // Set max width for text wrapping
    float maxWidth = Math::Min(600.0f, availRegion.x - 40.0f);

    // Center horizontally
    float offsetX = (availRegion.x - maxWidth) * 0.5f;
    offsetX = Math::Max(offsetX, 0.0f);

    vec2 currentPos = UI::GetCursorPos();
    UI::SetCursorPos(vec2(currentPos.x + offsetX, currentPos.y));

    UI::PushTextWrapPos(UI::GetCursorPos().x + maxWidth);
    UI::TextWrapped(welcomeText);
    UI::PopTextWrapPos();

    // Rules & How to Play Section - Centered
    vec2 rulesAvailRegion = UI::GetContentRegionAvail();
    float rulesMaxWidth = Math::Min(600.0f, rulesAvailRegion.x - 40.0f);
    float rulesOffsetX = (rulesAvailRegion.x - rulesMaxWidth) * 0.5f;
    rulesOffsetX = Math::Max(rulesOffsetX, 0.0f);

    // Add horizontal offset to center the content block
    UI::SetCursorPos(UI::GetCursorPos() + vec2(rulesOffsetX, 0.0f));

    // Use BeginGroup to maintain the offset for all child elements
    UI::BeginGroup();
    UI::PushTextWrapPos(UI::GetCursorPos().x + rulesMaxWidth);

    UI::Text("\\$f80Rules & How to Play:");
    UI::TextWrapped("- Play follows standard chess rules");
    UI::TextWrapped("- Click a piece to select it, then click a valid destination square to move");
    UI::TextWrapped("- Special moves like castling, en passant, and pawn promotion are supported");
    UI::Dummy(vec2(0, 5));
    UI::TextWrapped("Chess Race Mode:");
    UI::TextWrapped("- Each square on the board has a Trackmania map assigned to it");
    UI::TextWrapped("- When attempting a capture, both players race on the destination square's map");
    UI::TextWrapped("- The winner of the race gets the piece, even if defending");
    UI::TextWrapped("- Right-click any square to see its map name and tags");

    UI::PopTextWrapPos();
    UI::EndGroup();

    UI::Dummy(vec2(0, 5));

    UI::SetCursorPos(UI::GetCursorPos() + vec2(rulesOffsetX, 0.0f));

    UI::BeginGroup();
    UI::PushTextWrapPos(UI::GetCursorPos().x + rulesMaxWidth);
    UI::TextWrapped("This plugin has taken 200+ hours of programming, testing, and debugging so I appreciate any support given. To donate, use the KoFi link below, and to give suggestions or report bugs, create an issue on the github page.");
    UI::TextWrapped("PSA: the server is $5 US per month, every donation after the initial $5 for the server will be put back in to plugin development. Also, half will be given to Miss for all her work on Openplanet.");
    UI::NewLine();
    UI::PopTextWrapPos();

    UI::EndGroup();

    string thanksText = "Thanks for playing and supporting!";
    vec2 thanksSize = UI::MeasureString(thanksText);
    vec2 thanksAvailRegion = UI::GetContentRegionAvail();
    float thanksOffsetX = (thanksAvailRegion.x - thanksSize.x) * 0.5f;
    thanksOffsetX = Math::Max(thanksOffsetX, 0.0f);

    vec2 thanksCursorPos = UI::GetCursorPos();
    UI::SetCursorPos(vec2(thanksCursorPos.x + thanksOffsetX, thanksCursorPos.y));
    UI::Text(thanksText);

    // Footer Section - Push to bottom and center
    vec2 footerAvailRegion = UI::GetContentRegionAvail();

    // Add spacing to push footer to bottom
    float footerHeight = 55.0f;
    float spacerHeight = Math::Max(0.0f, footerAvailRegion.y - footerHeight - 20.0f);
    if (spacerHeight > 0) {
        UI::Dummy(vec2(0, spacerHeight));
    }

    UI::Separator();
    UI::NewLine();

    // Centered links
    vec2 linksAvailRegion = UI::GetContentRegionAvail();

    // Measure the total width of all links text
    string allLinksText = "Ko-fi/Donate | Source | Openplanet Page";
    vec2 linksSize = UI::MeasureString(allLinksText);
    float linksOffsetX = (linksAvailRegion.x - linksSize.x) * 0.5f;
    linksOffsetX = Math::Max(linksOffsetX, 0.0f);

    vec2 linksCursorStart = UI::GetCursorPos();
    UI::SetCursorPos(vec2(linksCursorStart.x + linksOffsetX, linksCursorStart.y));

    // Links as clickable text with tooltips
    UI::Text(themeSectionLabelColor + "");
    UI::SameLine();

    // Ko-fi link
    UI::Text("\\$66fKo-fi/Donate");
    if (UI::IsItemHovered()) {
        UI::BeginTooltip();
        UI::Text("https://ko-fi.com/itsgromit");
        UI::EndTooltip();
    }
    if (UI::IsItemClicked()) {
        OpenBrowserURL("https://ko-fi.com/itsgromit");
    }
    UI::SameLine();
    UI::Text("|");
    UI::SameLine();

    // Source Code link
    UI::Text("\\$66fSource");
    if (UI::IsItemHovered()) {
        UI::BeginTooltip();
        UI::Text("https://github.com/ItsGromit/TMChess");
        UI::EndTooltip();
    }
    if (UI::IsItemClicked()) {
        OpenBrowserURL("https://github.com/ItsGromit/TMChess");
    }
    UI::SameLine();
    UI::Text("|");
    UI::SameLine();

    // Openplanet Plugin link
    UI::Text("\\$66fOpenplanet Page");
    if (UI::IsItemHovered()) {
        UI::BeginTooltip();
        UI::Text("https://openplanet.dev/plugin/trackmania-chess");
        UI::EndTooltip();
    }
    if (UI::IsItemClicked()) {
        OpenBrowserURL("https://openplanet.dev/plugin/trackmania-chess");
    }
    UI::NewLine();
}

/**
 * Renders the Play tab content
 */
void RenderPlayTab() {
    // Auto-connect if not connected
    if (!isConnected) {
        // Ensure UI overrides are applied
        if (ui_serverHost != "") serverHost = ui_serverHost;
        if (ui_serverPort != "") {
            uint portParsed = Text::ParseUInt(ui_serverPort);
            if (portParsed > 0) serverPort = portParsed;
        }

        print("[Chess] Attempting to connect to server: " + serverHost + ":" + serverPort);
        if (Connect()) {
            print("[Chess] Successfully connected to server, waiting for handshake...");
        } else {
            error("[Chess] Failed to connect to server");
        }
    }

    // Wait for handshake to complete before showing lobby UI
    if (isConnected && !handshakeComplete) {
        UI::Text("Connecting to server...");
        return;
    }

    // Request lobby list once handshake completes (only once)
    if (handshakeComplete && !lobbiesRequested && currentLobbyId.Length == 0) {
        ListLobbies();
        lobbiesRequested = true;
    }

    // Show create lobby page or lobby list
    if (Lobby::isCreatingLobby) {
        Lobby::RenderCreateLobbyPage();
    } else {
        // Render create lobby UI
        Lobby::RenderCreateLobby();

        // Show lobby list
        Lobby::RenderLobbyList();
    }
}

/**
 * Renders the Settings tab content
 */
void RenderSettingsTab() {

    // Theme Settings Section
    UI::Text(themeSectionLabelColor + "Theme Settings:");
    UI::TextWrapped("Open the color customization window to change button and board colors, and thumbnail size and opacity.");
    if (StyledButton("Customize Theme", vec2(200.0f, 30.0f))) {
        showColorCustomizationWindow = true;
    }

    // Cache Management Section
    UI::NewLine();

    UI::Text(themeSectionLabelColor + "Cache Management:");
    UI::TextWrapped("Clears cached map thumbnails.");

    if (StyledButton("Clear Thumbnail Cache", vec2(200.0f, 30.0f))) {
        RaceMode::ThumbnailRendering::ClearThumbnailCache();
        print("[Settings] Thumbnail cache cleared");
        UI::ShowNotification("Chess", "Thumbnail cache cleared.", vec4(0.2, 0.6, 0.9, 1), 3000);
    }
}
