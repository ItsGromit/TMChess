// Texture assets
class PieceAssets {
    // White pieces
    UI::Texture@ wK; UI::Texture@ wQ; UI::Texture@ wR; UI::Texture@ wB; UI::Texture@ wN; UI::Texture@ wP;
    // Black pieces
    UI::Texture@ bK; UI::Texture@ bQ; UI::Texture@ bR; UI::Texture@ bB; UI::Texture@ bN; UI::Texture@ bP;

    // Loading tracking
    bool isLoading = false;
    int piecesLoaded = 0;
    int totalPieces = 12;

    void Load() {
        isLoading = true;
        piecesLoaded = 0;

        // White
        @wK = UI::LoadTexture("Images/king_white.png"); piecesLoaded++;
        @wQ = UI::LoadTexture("Images/queen_white.png"); piecesLoaded++;
        @wR = UI::LoadTexture("Images/rook_white.png"); piecesLoaded++;
        @wB = UI::LoadTexture("Images/bishop_white.png"); piecesLoaded++;
        @wN = UI::LoadTexture("Images/knight_white.png"); piecesLoaded++;
        @wP = UI::LoadTexture("Images/pawn_white.png"); piecesLoaded++;
        // Black
        @bK = UI::LoadTexture("Images/king_black.png"); piecesLoaded++;
        @bQ = UI::LoadTexture("Images/queen_black.png"); piecesLoaded++;
        @bR = UI::LoadTexture("Images/rook_black.png"); piecesLoaded++;
        @bB = UI::LoadTexture("Images/bishop_black.png"); piecesLoaded++;
        @bN = UI::LoadTexture("Images/knight_black.png"); piecesLoaded++;
        @bP = UI::LoadTexture("Images/pawn_black.png"); piecesLoaded++;

        isLoading = false;
        print("[PieceAssets] All piece assets loaded successfully");
    }
    // Assign textures to pieces
    UI::Texture@ GetTexture(const Piece &in p) const {
        if (p.type == PieceType::Empty) return null;

        if (p.color == PieceColor::White) {
            switch (p.type) {
                case PieceType::King:   return wK;
                case PieceType::Queen:  return wQ;
                case PieceType::Rook:   return wR;
                case PieceType::Bishop: return wB;
                case PieceType::Knight: return wN;
                case PieceType::Pawn:   return wP;
            }
        } else { // Black
            switch (p.type) {
                case PieceType::King:   return bK;
                case PieceType::Queen:  return bQ;
                case PieceType::Rook:   return bR;
                case PieceType::Bishop: return bB;
                case PieceType::Knight: return bN;
                case PieceType::Pawn:   return bP;
            }
        }
        return null;
    }
}

PieceAssets gPieces;