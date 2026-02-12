// raceHandlers.js - Race challenge handlers

const { games, raceChallenges } = require('./state');
const { send, broadcastPlayers } = require('./utils');

// Handle race_result message
function handleRaceResult(socket, msg) {
  const challenge = raceChallenges.get(msg.gameId);
  if (!challenge) return console.log('[Chess] No race challenge found for game:', msg.gameId);

  const game = games.get(msg.gameId);
  if (!game) return;

  const time = msg.time;
  const isDefender = socket === challenge.defender;
  const isAttacker = socket === challenge.attacker;

  console.log(`[Chess] Race result received: ${time}ms from ${isDefender ? 'defender' : 'attacker'}`);

  // Check if player has already submitted a time
  if (isDefender && challenge.defenderTime !== null) {
    console.log('[Chess] Defender already submitted a time, ignoring duplicate');
    return;
  }
  if (isAttacker && challenge.attackerTime !== null) {
    console.log('[Chess] Attacker already submitted a time, ignoring duplicate');
    return;
  }

  // Store the time (first submission only)
  if (isDefender) {
    challenge.defenderTime = time;
    // Notify attacker that defender finished
    send(challenge.attacker, { type: 'race_defender_finished', time });
  } else if (isAttacker) {
    challenge.attackerTime = time;
    // Notify defender that attacker finished
    send(challenge.defender, { type: 'opponent_finished', time });
  }

  // If both have finished, determine winner
  if (challenge.defenderTime !== null && challenge.attackerTime !== null) {
    const captureSucceeded = challenge.attackerTime < challenge.defenderTime;
    console.log(`[Chess] Race complete - Attacker: ${challenge.attackerTime}ms, Defender: ${challenge.defenderTime}ms, Capture ${captureSucceeded ? 'succeeded' : 'failed'}`);

    if (captureSucceeded) {
      // Attacker won - check if promotion is needed
      if (challenge.isPromotion && challenge.promotion === null) {
        // Need to ask attacker for promotion piece
        console.log('[Chess] Promotion required - waiting for attacker to select piece');
        send(challenge.attacker, {
          type: 'promotion_required',
          gameId: msg.gameId,
          from: challenge.from,
          to: challenge.to
        });
        // Also tell defender that race succeeded but waiting for promotion
        send(challenge.defender, {
          type: 'race_result',
          captureSucceeded: true,
          waitingForPromotion: true,
          fen: game.chess.fen(),
          turn: game.chess.turn()
        });
        // Keep challenge alive for select_promotion handler
        return;
      }

      // Apply the capture (no promotion or promotion already set)
      const res = game.chess.move({
        from: challenge.from,
        to: challenge.to,
        promotion: challenge.promotion || 'q'
      });
      if (res) {
        const fen = game.chess.fen();
        const nextTurn = game.chess.turn();
        broadcastPlayers(game, {
          type: 'race_result',
          captureSucceeded: true,
          fen,
          turn: nextTurn
        });

        // Check if game is over after the move
        if (game.chess.isGameOver()) {
          let reason = 'draw', winner = null;
          if (game.chess.isCheckmate()) {
            reason = 'checkmate';
            winner = (nextTurn === 'w' ? 'black' : 'white');
          } else if (game.chess.isStalemate()) {
            reason = 'stalemate';
          } else if (game.chess.isThreefoldRepetition()) {
            reason = 'threefold';
          } else if (game.chess.isInsufficientMaterial()) {
            reason = 'insufficient';
          }
          broadcastPlayers(game, {
            type: 'game_over',
            gameId: msg.gameId,
            reason,
            winner
          });

          // Clean up game
          games.delete(msg.gameId);
        }
      }
    } else {
      // Defender won, capture fails - board stays the same
      const fen = game.chess.fen();
      const turn = game.chess.turn();
      broadcastPlayers(game, {
        type: 'race_result',
        captureSucceeded: false,
        fen,
        turn
      });
    }

    // Clean up challenge
    raceChallenges.delete(msg.gameId);
  }
}

// Handle race_retire message
function handleRaceRetire(socket, msg) {
  const challenge = raceChallenges.get(msg.gameId);
  if (!challenge) return console.log('[Chess] No race challenge found for game:', msg.gameId);

  const game = games.get(msg.gameId);
  if (!game) return;

  const isDefender = socket === challenge.defender;
  const isAttacker = socket === challenge.attacker;

  console.log(`[Chess] Player retired from race: ${isDefender ? 'defender' : 'attacker'}`);

  // Notify opponent that player retired
  const opponent = isDefender ? challenge.attacker : challenge.defender;
  send(opponent, { type: 'opponent_retired' });

  // Check if player has already submitted a time or retired
  if (isDefender && challenge.defenderTime !== null) {
    console.log('[Chess] Defender already submitted a time/retired, ignoring');
    return;
  }
  if (isAttacker && challenge.attackerTime !== null) {
    console.log('[Chess] Attacker already submitted a time/retired, ignoring');
    return;
  }

  // Mark player as DNF with max time (essentially infinite)
  if (isDefender) {
    challenge.defenderTime = Number.MAX_SAFE_INTEGER;
  } else if (isAttacker) {
    challenge.attackerTime = Number.MAX_SAFE_INTEGER;
  }

  // Check if both players are done (either finished or retired)
  if (challenge.defenderTime !== null && challenge.attackerTime !== null) {
    // Determine winner: lower time wins (DNF = MAX_SAFE_INTEGER)
    const captureSucceeded = challenge.attackerTime < challenge.defenderTime;
    console.log(`[Chess] Race complete - Attacker: ${challenge.attackerTime === Number.MAX_SAFE_INTEGER ? 'DNF' : challenge.attackerTime + 'ms'}, Defender: ${challenge.defenderTime === Number.MAX_SAFE_INTEGER ? 'DNF' : challenge.defenderTime + 'ms'}, Capture ${captureSucceeded ? 'succeeded' : 'failed'}`);

    if (captureSucceeded) {
      // Attacker won - check if promotion is needed
      if (challenge.isPromotion && challenge.promotion === null) {
        // Need to ask attacker for promotion piece
        console.log('[Chess] Promotion required - waiting for attacker to select piece');
        send(challenge.attacker, {
          type: 'promotion_required',
          gameId: msg.gameId,
          from: challenge.from,
          to: challenge.to
        });
        // Also tell defender that race succeeded but waiting for promotion
        send(challenge.defender, {
          type: 'race_result',
          captureSucceeded: true,
          waitingForPromotion: true,
          fen: game.chess.fen(),
          turn: game.chess.turn()
        });
        // Keep challenge alive for select_promotion handler
        return;
      }

      // Apply the capture
      const res = game.chess.move({
        from: challenge.from,
        to: challenge.to,
        promotion: challenge.promotion || 'q'
      });
      if (res) {
        const fen = game.chess.fen();
        const nextTurn = game.chess.turn();
        broadcastPlayers(game, {
          type: 'race_result',
          captureSucceeded: true,
          fen,
          turn: nextTurn
        });

        // Check if game is over after the move
        if (game.chess.isGameOver()) {
          let reason = 'draw', winner = null;
          if (game.chess.isCheckmate()) {
            reason = 'checkmate';
            winner = (nextTurn === 'w' ? 'black' : 'white');
          } else if (game.chess.isStalemate()) {
            reason = 'stalemate';
          } else if (game.chess.isThreefoldRepetition()) {
            reason = 'threefold';
          } else if (game.chess.isInsufficientMaterial()) {
            reason = 'insufficient';
          }
          broadcastPlayers(game, {
            type: 'game_over',
            gameId: msg.gameId,
            reason,
            winner
          });

          // Clean up game
          games.delete(msg.gameId);
        }
      }
    } else {
      // Capture fails
      const fen = game.chess.fen();
      const turn = game.chess.turn();
      broadcastPlayers(game, {
        type: 'race_result',
        captureSucceeded: false,
        fen,
        turn
      });
    }

    // Clean up challenge
    raceChallenges.delete(msg.gameId);
  }
}

// Handle select_promotion message (attacker selects promotion piece after winning race)
function handleSelectPromotion(socket, msg) {
  const challenge = raceChallenges.get(msg.gameId);
  if (!challenge) return console.log('[Chess] No race challenge found for game:', msg.gameId);

  const game = games.get(msg.gameId);
  if (!game) return;

  // Only attacker can select promotion
  if (socket !== challenge.attacker) {
    console.log('[Chess] Non-attacker tried to select promotion');
    return;
  }

  const promotion = msg.promotion || 'q';
  console.log(`[Chess] Attacker selected promotion: ${promotion}`);

  // Apply the capture with selected promotion
  const res = game.chess.move({
    from: challenge.from,
    to: challenge.to,
    promotion
  });

  if (res) {
    const fen = game.chess.fen();
    const nextTurn = game.chess.turn();
    broadcastPlayers(game, {
      type: 'race_result',
      captureSucceeded: true,
      fen,
      turn: nextTurn
    });

    // Check if game is over after the move
    if (game.chess.isGameOver()) {
      let reason = 'draw', winner = null;
      if (game.chess.isCheckmate()) {
        reason = 'checkmate';
        winner = (nextTurn === 'w' ? 'black' : 'white');
      } else if (game.chess.isStalemate()) {
        reason = 'stalemate';
      } else if (game.chess.isThreefoldRepetition()) {
        reason = 'threefold';
      } else if (game.chess.isInsufficientMaterial()) {
        reason = 'insufficient';
      }
      broadcastPlayers(game, {
        type: 'game_over',
        gameId: msg.gameId,
        reason,
        winner
      });

      // Clean up game
      games.delete(msg.gameId);
    }
  }

  // Clean up challenge
  raceChallenges.delete(msg.gameId);
}

// Handle race_started message
function handleRaceStarted(socket, msg) {
  const challenge = raceChallenges.get(msg.gameId);
  if (!challenge) return console.log('[Chess] No race challenge found for game:', msg.gameId);

  const game = games.get(msg.gameId);
  if (!game) return;

  const isDefender = socket === challenge.defender;
  const isAttacker = socket === challenge.attacker;

  console.log(`[Chess] Player started racing: ${isDefender ? 'defender' : 'attacker'}`);

  // Notify opponent that player started racing
  const opponent = isDefender ? challenge.attacker : challenge.defender;
  send(opponent, { type: 'opponent_race_started' });
}

// Handle checkpoint message - relay checkpoint times to opponent
function handleCheckpoint(socket, msg) {
  const challenge = raceChallenges.get(msg.gameId);
  if (!challenge) return;

  const game = games.get(msg.gameId);
  if (!game) return;

  const isDefender = socket === challenge.defender;
  const cpIndex = msg.cpIndex;
  const time = msg.time;

  // Relay checkpoint to opponent
  const opponent = isDefender ? challenge.attacker : challenge.defender;
  send(opponent, {
    type: 'opponent_checkpoint',
    cpIndex: cpIndex,
    time: time
  });

  console.log(`[Race] Player ${isDefender ? 'defender' : 'attacker'} passed CP ${cpIndex + 1}: ${time}ms`);
}

module.exports = {
  handleRaceResult,
  handleRaceRetire,
  handleRaceStarted,
  handleCheckpoint,
  handleSelectPromotion
};
