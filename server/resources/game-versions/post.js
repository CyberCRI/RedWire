filter = {
    gameId: this.gameId,
    // game version with highest version number
    $sort: {versionNumber: -1},
    $limit: 1
};

dpd.gameversions.get(filter, function(result, error) {
    if (error) {
        console.log(error);
        cancel(error, 500);
    } else if (result.length === 0) { // First version ever saved for this game
        this.versionNumber = 1;
    } else { // A version for this game already exists
        previousGameVersion = result[0];
        this.versionNumber = previousGameVersion.versionNumber + 1;
    }
});