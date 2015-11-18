// Record that the current user likes a game
// Expecting a URL like /like/{gameId} 

if(!me) cancel("You need to be logged in to rate a game");

var gameId = parts[0];
if (!gameId) cancel("You must provide a game ID");

// TODO: check if the user already liked the game

// Record it in Raccoon
liked(me.id, gameId, function() {});

// Record it in the game
dpd.games.put({ id: gameId }, { likeCount: { $inc: 1 } });

// Record it in the user
dpd.users.put({ id: me.id }, { likedGames: { $push: gameId } });
