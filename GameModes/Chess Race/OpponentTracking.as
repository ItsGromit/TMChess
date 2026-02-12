// ============================================================================
// SQUARE RACE MODE - OPPONENT TRACKING
// ============================================================================

namespace RaceMode {

namespace OpponentTracking {

// Current opponent checkpoint data
RaceMode::OpponentCheckpointData opponentData;

void ResetOpponentData() {
    opponentData.Reset();
}

void ReceiveOpponentCheckpoint(int checkpointIndex, int time) {
    // Ensure array is large enough
    while (opponentData.checkpointTimes.Length <= uint(checkpointIndex)) {
        opponentData.checkpointTimes.InsertLast(-1);
    }

    opponentData.checkpointTimes[checkpointIndex] = time;
    opponentData.currentCheckpoint = checkpointIndex;
}

}

}