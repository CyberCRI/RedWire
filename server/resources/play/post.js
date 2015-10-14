// Expecting a URL like /play/{gameId} 
// Update the play count for the game
var gameId = parts[0];
if (!gameId) cancel("You must provide a game ID");

dpd.games.put({ id: gameId }, { playCount: { $inc: 1 }}, function(gameResult, err) {
  if (err) cancel(err);
  
  setResult({ playCount: gameResult.playCount });
});
