// ============================================================================
// LOGO ASSET LOADER
// ============================================================================
// Handles loading the TMChess logo from bundled assets

// Logo texture
UI::Texture@ logoTexture = null;

// Loading tracking
bool isLoadingLogo = false;

/**
 * Loads the TMChess logo
 */
void LoadLogo() {
    isLoadingLogo = true;
    @logoTexture = UI::LoadTexture("Images/TMChess.png");
    if (logoTexture !is null) {
        print("[Logo] TMChess logo loaded successfully");
    }
    isLoadingLogo = false;
}

/**
 * Returns the logo texture (null if not loaded)
 */
UI::Texture@ GetLogoTexture() {
    return logoTexture;
}

/**
 * Renders the logo centered with specified width
 * Height is calculated to maintain aspect ratio
 */
void RenderLogoCentered(float maxWidth) {
    if (logoTexture is null) return;

    vec2 availRegion = UI::GetContentRegionAvail();

    // Calculate dimensions maintaining aspect ratio
    vec2 texSize = logoTexture.GetSize();
    float aspectRatio = texSize.y / texSize.x;

    float logoWidth = Math::Min(maxWidth, availRegion.x);
    float logoHeight = logoWidth * aspectRatio;

    // Center horizontally
    float offsetX = (availRegion.x - logoWidth) * 0.5f;
    offsetX = Math::Max(offsetX, 0.0f);

    vec2 currentPos = UI::GetCursorPos();
    UI::SetCursorPos(vec2(currentPos.x + offsetX, currentPos.y));

    // Render the logo
    UI::Image(logoTexture, vec2(logoWidth, logoHeight));
}
