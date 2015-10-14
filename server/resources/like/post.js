// Record that the current user likes a game
// Expecting a URL like /like/{gameId} 

if(!me) cancel("You need to be logged in to rate a game");

var gameId = parts[0];
if (!gameId) cancel("You must provide a game ID");

liked(me.id, gameId, function() {});