// ============================================================================
// PAWN PROMOTION DIALOG
// ============================================================================
// Handles UI for selecting pawn promotion piece with piece images
// ============================================================================

/**
 * Renders the pawn promotion selection dialog at the promotion square
 * @return The selected piece type, or PieceType::Empty if no selection yet
 */
PieceType RenderPromotionDialog() {
    if (!isPendingPromotion) return PieceType::Empty;

    // Determine the color of the promoting pawn
    PieceColor pieceColor = PieceColor(currentTurn);

    // Calculate the position of the promotion square on screen
    int displayRow = promotionRow;
    int displayCol = promotionCol;
    if (boardFlipped) {
        displayRow = 7 - promotionRow;
        displayCol = 7 - promotionCol;
    }

    // Calculate screen position of the promotion square
    vec2 squareScreenPos = boardWindowPos + boardRenderPos + vec2(displayCol * boardSquareSize, displayRow * boardSquareSize);

    // Dialog size - 4 pieces in a vertical column
    float pieceButtonSize = boardSquareSize;
    float dialogWidth = pieceButtonSize + 8.0f;  // Small padding
    float dialogHeight = pieceButtonSize * 4 + 12.0f;  // 4 pieces + padding

    // Position dialog next to the promotion square
    // For white (promoting on row 0), show below the square
    // For black (promoting on row 7), show above the square
    vec2 dialogPos;
    if (promotionRow == 0) {
        // White promoting - dialog extends downward from the square
        dialogPos = vec2(squareScreenPos.x - 4.0f, squareScreenPos.y);
    } else {
        // Black promoting - dialog extends upward from the square
        dialogPos = vec2(squareScreenPos.x - 4.0f, squareScreenPos.y - dialogHeight + boardSquareSize);
    }

    UI::SetNextWindowSize(int(dialogWidth), int(dialogHeight), UI::Cond::Always);
    UI::SetNextWindowPos(int(dialogPos.x), int(dialogPos.y), UI::Cond::Always);

    PieceType selectedPiece = PieceType::Empty;

    int windowFlags = UI::WindowFlags::NoResize | UI::WindowFlags::NoCollapse |
                      UI::WindowFlags::NoMove | UI::WindowFlags::NoTitleBar |
                      UI::WindowFlags::NoScrollbar;

    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(4.0f, 4.0f));
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(0.0f, 1.0f));

    if (UI::Begin("##PromotionDialog", windowFlags)) {
        // Array of promotion pieces in order: Queen, Rook, Bishop, Knight
        array<PieceType> promotionPieces = {
            PieceType::Queen,
            PieceType::Rook,
            PieceType::Bishop,
            PieceType::Knight
        };

        for (uint i = 0; i < promotionPieces.Length; i++) {
            PieceType pieceType = promotionPieces[i];
            Piece piece = Piece(pieceType, pieceColor);
            UI::Texture@ tex = GetPieceTexture(piece);

            // Alternate button colors for visibility
            bool isLight = (i % 2 == 0);
            vec4 buttonColor = isLight ? boardLightSquareColor : boardDarkSquareColor;

            UI::PushStyleColor(UI::Col::Button, buttonColor);
            UI::PushStyleColor(UI::Col::ButtonHovered, buttonColor * 1.2f);
            UI::PushStyleColor(UI::Col::ButtonActive, buttonColor * 0.8f);

            string buttonId = "##promo_" + i;
            if (UI::Button(buttonId, vec2(pieceButtonSize, pieceButtonSize))) {
                selectedPiece = pieceType;
            }

            // Draw the piece image over the button
            DrawCenteredImageOverLastItem(tex, 4.0f);

            UI::PopStyleColor(3);
        }
    }
    UI::End();

    UI::PopStyleVar(2);

    return selectedPiece;
}
