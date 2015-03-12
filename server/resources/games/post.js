dpd.users.get({ id: this.ownerId }, function(userResult, error) {
    if (error) {
        console.log(error);
        return cancel(error, 500);
    } 

    dpd.games.get({ id: this.parentId }, function(parentResult, error) {
        console.log("parentResult", parentResult);
        if (error) {
            console.log(error);
            return cancel(error, 500);
        } 
    
        // Fill in default values
        this.ownerName = userResult.username;
        this.parentName = parentResult.name;
        this.playCount = 0;
        this.forkCount = 0;
        this.versionCount = 0;
        this.lastUpdatedTime = new Date().toUTCString();
    });
});