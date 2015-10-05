if(!me || !me.isAdmin && this.ownerId != me.id) {
    cancel("You are not the owner of the game, or admin, or logged in", 401);
}


dpd.gameversions.get({gameId: this.id},function(result, error){
    result.forEach(function(gameVersion){
        dpd.gameversions.del({id: gameVersion.id });
    });
});