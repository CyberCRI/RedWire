// Get the number of likes for the given game
// Expecting a URL like /like/{gameId} 

var gameId = parts[0];
if (!gameId) cancel("You must provide a game ID");

likedCount(gameId, function(likedCountResults) { 
    if(me) {
        likedBy(me.id, function(likedByResults) {
            var likedGame = likedByResults.indexOf(gameId) > -1;
            setResult({ 
                likedCount: likedCountResults,
                likedGame: likedGame 
            });         
        });
    } else {
        // Not logged in, so can't like games
        setResult({ 
            likedCount: likedCountResults,
            likedGame: false
        });        
    }
});