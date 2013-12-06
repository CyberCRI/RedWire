dpd.game-versions.get("{$sort: {versionNumber: -1}, $limit: 1}", function(error, latestGameVersion) {
    if (error) {
        console.log(error);
        cancel(error, 500);
    } else if (!latestGameVersion) { // First version ever saved for this game
        this.versionNumber = 1;
    } else { // A version for this game already exists
        this.versionNumber = latestGameVersion.versionNumber + 1;
    }
});