this.createdTime = new Date().toUTCString();

dpd.games.get({ id: this.gameId }, function(gameResult, error) {
    if(error) {
        console.log(error);
        return cancel(error, 500);
    }
    
    this.gameName = gameResult.name;
    this.versionNumber = gameResult.versionCount + 1;
    
    // Update game
    dpd.games.put({ id: this.gameId }, { 
        versionCount: this.versionNumber,
        lastUpdatedTime: this.createdTime
    });
});

