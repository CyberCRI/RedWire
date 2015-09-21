// Get the number of likes for the given game
// Expecting a URL like /like/{gameId} 

var gameId = parts[0];
if (!gameId) cancel("You must provide a game ID");

likedCount(gameId, function(results) { 
    setResult({ likedCount: results });
});