const string MainWindowName = Icons::PuzzlePiece + " \\$zChess";
const string MainMenuItemName = "\\$862" + MainWindowName;

void Main() {
    Init();
    InitializeGlobals();
    ApplyTheme(currentTheme);
}

void Update(float dt) {
    Update();

    // Handle race state management
    RaceStateManager::Update();
}

bool assetsStarted = false;

void RenderMenu() {
    UI::SetNextWindowSize(int(defaultWidth), int(defaultHeight), UI::Cond::FirstUseEver);
    if (UI::MenuItem(MainMenuItemName)) {
        showWindow = !showWindow;
    }
    if (showWindow && !assetsStarted) {
        assetsStarted = true;
        startnew(LoadPieceAssets);
        startnew(LoadLogo);
        startnew(ChessAudio::LoadSounds);
    }
}

void Render() {
    // Render race window if in race state
    if (GameManager::currentState == GameState::RaceChallenge) {
        RenderRaceWindow();

        // Close main window during race, remember it was open
        if (showWindow) {
            collapseChessWindow = true;
            showWindow = false;
        }
    } else {
        // Reopen window after race if it was open before
        if (collapseChessWindow) {
            showWindow = true;
            collapseChessWindow = false;
        }

    }

    if (showWindow) {
        MainMenu();
    }
}