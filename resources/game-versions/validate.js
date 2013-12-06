if (!me) {
    cancel("You should be logged in to save a game", 401);
} else {
    dpd.games.get(this.gameId, function(error, game) {
        if (error) {
            console.log(error);
            cancel(error, 500);
        } else if (!game) {
            cancel("Game not found for id : " + this.gameId, 404);
        } else if (game.ownerId !== me.id) {
            cancel("You are not allowed to save a game which is not your own, please fork instead", 403);
        }
    });
}


