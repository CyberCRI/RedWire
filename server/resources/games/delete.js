if(!me || !me.isAdmin || this.ownerId == me.id) {
    cancel("You are not the owner of the game, or admin, or logged in", 401);
}
dpd["game-versions"].get({gameId: this.id},function(result, error){
    result.forEach(function(gameVersion){
        dpd["game-versions"].del(gameVersion.id);
    });
});