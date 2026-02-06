namespace ColorCustomization {
    void RenderWindow() {
        if (!showColorCustomizationWindow) return;

        UI::SetNextWindowSize(600, 500, UI::Cond::FirstUseEver);

        int windowFlags = UI::WindowFlags::NoCollapse;

        if (UI::Begin("Color Customization", showColorCustomizationWindow, windowFlags)) {
            UI::BeginTabBar("ColorTabs");

            // Theme Preset Tab
            if (UI::BeginTabItem("Theme Presets")) {
                UI::NewLine();
                UI::Text(themeSectionLabelColor + "Select a Theme:");
                UI::NewLine();

                UI::Text("Choose a preset theme or customize individual colors in other tabs.");
                UI::NewLine();

                array<string> themeNames = {"Default", "Light", "Dark"};
                UI::SetNextItemWidth(200);
                if (UI::BeginCombo("Plugin Theme", themeNames[int(currentTheme)])) {
                    for (uint i = 0; i < themeNames.Length; i++) {
                        bool isSelected = (int(currentTheme) == int(i));
                        if (UI::Selectable(themeNames[i], isSelected)) {
                            ApplyTheme(ThemePreset(i));
                        }
                        if (isSelected) UI::SetItemDefaultFocus();
                    }
                    UI::EndCombo();
                }

                UI::NewLine();
                switch (currentTheme) {
                    case ThemePreset::Default:
                        UI::TextWrapped("The original blue and brown theme with moderate opacity.");
                        break;
                    case ThemePreset::Light:
                        UI::TextWrapped("Bright flashbang. I don't use light mode for anything, so if people want updates to this give me suggestions for how to make it look better.");
                        break;
                    case ThemePreset::Dark:
                        UI::TextWrapped("Dark, muted colors for a subtle appearance.");
                        break;
                }

                UI::NewLine();
                UI::Separator();
                UI::NewLine();
                UI::TextWrapped("Note: You can select a theme and then customize individual colors in the other tabs. The theme setting will update to reflect your custom choices.");

                UI::EndTabItem();
            }

            // Button Colors Tab
            if (UI::BeginTabItem("Button Colors")) {
                UI::NewLine();
                UI::Text(themeSectionLabelColor + "Button Color Settings:");
                UI::NewLine();
                UI::SetNextItemWidth(200);

                themeActiveTabColor = UI::InputColor4("Active Button Color", themeActiveTabColor, UI::ColorEditFlags::NoInputs);
                

                UI::NewLine();
                UI::SetNextItemWidth(200);
                themeInactiveTabColor = UI::InputColor4("Inactive Button Color", themeInactiveTabColor, UI::ColorEditFlags::NoInputs);

                UI::NewLine();

                // Reset to default colors button
                if (StyledButton("Reset to Default", vec2(150.0f, 30.0f))) {
                    themeActiveTabColor = vec4(0.2f, 0.5f, 0.8f, 1.0f);
                    themeInactiveTabColor = vec4(0.26f, 0.26f, 0.26f, 1.0f);
                }

                UI::EndTabItem();
            }

            // Chess Board Colors Tab
            if (UI::BeginTabItem("Board Colors")) {
                UI::NewLine();
                UI::Text(themeSectionLabelColor + "Chess Board Color Settings:");
                UI::NewLine();

                // Start two-column layout: sliders on left, preview on right
                UI::BeginGroup();

                array<string> boardThemeNames = {"Classic", "Ocean", "Mossy", "Chocolate"};
                UI::SetNextItemWidth(200);
                if (UI::BeginCombo("Board Theme", boardThemeNames[int(currentBoardTheme)])) {
                    for (uint i = 0; i < boardThemeNames.Length; i++) {
                        bool isSelected = (int(currentBoardTheme) == int(i));
                        if (UI::Selectable(boardThemeNames[i], isSelected)) {
                            ApplyBoardTheme(BoardThemePreset(i));
                        }
                        if (isSelected) UI::SetItemDefaultFocus();
                    }
                    UI::EndCombo();
                }

                UI::NewLine();
                UI::SetNextItemWidth(200);
                boardLightSquareColor = UI::InputColor4("Light Square Color", boardLightSquareColor, UI::ColorEditFlags::NoInputs);

                UI::NewLine();
                UI::SetNextItemWidth(200);
                boardDarkSquareColor = UI::InputColor4("Dark Square Color", boardDarkSquareColor, UI::ColorEditFlags::NoInputs);

                UI::NewLine();
                UI::SetNextItemWidth(200);
                boardSelectedSquareColor = UI::InputColor4("Selected Square Color", boardSelectedSquareColor, UI::ColorEditFlags::NoInputs);

                UI::NewLine();
                UI::SetNextItemWidth(200);
                boardValidMoveColor = UI::InputColor4("Valid Move Color", boardValidMoveColor, UI::ColorEditFlags::NoInputs);

                UI::EndGroup();

                // Preview board on the right side
                UI::SameLine();
                UI::BeginGroup();
                UI::Text("Preview:");

                // Draw a small 4x4 preview board
                float previewSquareSize = 25.0f;
                vec2 previewStartPos = UI::GetCursorPos();

                for (int pr = 0; pr < 4; pr++) {
                    for (int pc = 0; pc < 4; pc++) {
                        UI::SetCursorPos(previewStartPos + vec2(pc * previewSquareSize, pr * previewSquareSize));

                        // Determine square color
                        bool isLightSquare = (pr + pc) % 2 == 0;
                        vec4 previewColor;

                        // Show different colors in the preview
                        if (pr == 1 && pc == 1) {
                            previewColor = boardSelectedSquareColor; // Selected square example
                        } else if (pr == 2 && pc == 1) {
                            previewColor = boardValidMoveColor; // Valid move example
                        } else {
                            previewColor = isLightSquare ? boardLightSquareColor : boardDarkSquareColor;
                        }

                        UI::PushStyleColor(UI::Col::Button, previewColor);
                        UI::PushStyleColor(UI::Col::ButtonHovered, previewColor);
                        UI::PushStyleColor(UI::Col::ButtonActive, previewColor);
                        UI::Button("##preview" + pr + "_" + pc, vec2(previewSquareSize, previewSquareSize));
                        UI::PopStyleColor(3);
                    }
                }

                // Reset cursor position after the preview board
                UI::SetCursorPos(previewStartPos + vec2(0, 4 * previewSquareSize + 5));
                UI::TextWrapped("Preview shows: normal squares, selected (center-left), and valid move (below selected)");

                UI::EndGroup();

                UI::NewLine();

                // Reset board colors button
                if (StyledButton("Reset to Default", vec2(150.0f, 30.0f))) {
                    boardLightSquareColor = vec4(0.9f, 0.9f, 0.8f, 1.0f);
                    boardDarkSquareColor = vec4(0.5f, 0.4f, 0.3f, 1.0f);
                    boardSelectedSquareColor = vec4(0.3f, 0.7f, 0.3f, 1.0f);
                    boardValidMoveColor = vec4(0.7f, 0.9f, 0.7f, 0.4f);
                }

                UI::EndTabItem();
            }

            UI::EndTabBar();
        }
        UI::End();
    }
}