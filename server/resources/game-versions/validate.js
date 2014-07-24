this.versionNumber = 1;
if (!me) {
    cancel("You should be logged in to save a game", 401);
} else {
    if (!this.gameId) cancel('gameId is required', 403);
    dpd.games.get(this.gameId, function(game, error) {
        if (error) {
            console.log(error);
            cancel(error, 500);
        } else if (!game) {
            cancel("Game not found for id : " + this.gameId, 404);
        } else if (game.ownerId !== me.id) {
            cancel("You are not allowed to save a game which is not your own, please fork instead", 403);
        } else {
            // Make sure version passes validation
            this.versionNumber = 1;
        }
    });
}


