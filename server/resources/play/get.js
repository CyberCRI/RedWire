// Expecting a URL like /play/{gameId} 
// Get the play count for a game
var gameId = parts[0];
if (!gameId) cancel("You must provide a game ID");

dpd.games.get({ id: gameId }, function(gameResult, err) {
  if (err) cancel(err);
  
  setResult({ playCount: gameResult.playCount });
});