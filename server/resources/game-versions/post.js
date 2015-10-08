this.createdTime = new Date().toISOString();
this.playCount = 0;

dpd.games.get({ id: this.gameId }, function(gameResult, error) {
    if(error) {
        console.log(error);
        return cancel(error, 500);
    }
    
    this.gameName = gameResult.name;
    this.versionNumber = gameResult.versionCount + 1;
    
    // Update game
    dpd.games.put({ id: this.gameId }, { 
        lastVersionId: this.id,
        versionCount: this.versionNumber,
        lastUpdatedTime: this.createdTime
    });
});

