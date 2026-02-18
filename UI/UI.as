// ============================================================================
// MAIN UI
// ============================================================================
// Main UI entry point that coordinates all UI components
// ============================================================================
void MainMenu() {
    int windowFlags = windowResizeable ? 0 : UI::WindowFlags::NoResize;

    UI::PushStyleColor(UI::Col::WindowBg, themeWindowBgColor);
    UI::PushStyleColor(UI::Col::TitleBg, themeWindowBgColor);
    UI::PushStyleColor(UI::Col::TitleBgActive, themeWindowBgColor);
    UI::PushStyleColor(UI::Col::TitleBgCollapsed, themeWindowBgColor);

    if (collapseMainWindow) {
        UI::SetNextWindowCollapsed(true);
        collapseMainWindow = false;
    }

    if (UI::Begin("Chess Race", showWindow, windowFlags)) {

        switch (GameManager::currentState) {
            case GameState::Menu:
                RenderMenuState();
                break;

            case GameState::Connecting:
                RenderConnectingState();
                break;

            case GameState::InQueue:
                RenderInQueueState();
                break;

            case GameState::InLobby:
                RenderInLobbyState();
                break;

            case GameState::Playing:
            case GameState::GameOver:
                if (showRaceResults) {
                    RenderRaceResultsInline();
                }
                RenderPlayingState();
                break;

            case GameState::RaceChallenge:
                break;
        }
    }
    UI::End();

    if (!showWindow) {
        showWindow != showWindow;
    }

    UI::PopStyleColor(4);

    // Render color customization window (independent of main window)
    ColorCustomization::RenderWindow();
}
