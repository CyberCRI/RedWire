// Fill in default values
this.playCount = 0;
this.forkCount = 0;
this.versionCount = 0;
this.createdTime = new Date().toUTCString();
this.lastUpdatedTime = new Date().toUTCString();
this.mixedFromGameIds = [];
this.mixedToGameIds = [];

var that = this;

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
    
        // Fill in extra values
        console.log("Updating game with", that);
        that.ownerName = userResult.username;
        that.parentName = parentResult.name;
        
        // Increment fork count of parent    
        dpd.games.put({ id: this.parentId }, { forkCount: { $inc: 1 } });
    });
});
