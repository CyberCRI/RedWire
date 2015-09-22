// Adds lastVersionId, versionCount, # forks, username, etc.
// Meant to be run in the MongoDB shell (like "mongo redwire client/tools/upgradeDbForGameStats.js")

var gameCursor = db.games.find();
while(gameCursor.hasNext()) {
    var game = gameCursor.next();
    print("Treating game", game._id, game.name);

    // Check if the game has already been upgraded
    if(game.lastVersionId) {
        print(" Already upgraded. Skipping.")
        continue;
    }

    var lastGameVersionCursor = db["game-versions"].find({ gameId: game._id }).sort({ versionNumber: -1 });
    if(!lastGameVersionCursor.hasNext()) {
        print("  ERROR: no game version. Deleting.");
        db.games.remove({ _id: game._id }, { justOne: true });
        continue;
    }

    game.lastVersionId = lastGameVersionCursor.next()._id;
    print("  lastVersionId", game.lastVersionId);

    // Get forks
    game.forkCount = db.games.find({ parentId: game._id }).count();
    print("  forkCount", game.forkCount, "forks");

    // Get owner name
    game.ownerName = db.users.findOne({ _id: game.ownerId }).username;
    print("  ownerName", game.ownerName);

    // Get parent name
    if(!game.parentName && game.parentId) {
        game.parentName = db.games.findOne({ _id: game.parentId }).name;
        print("  parentName", game.parentName);
    }

    // Get version count
    var gameVersionCursor = db["game-versions"].find({ gameId: game._id });
    game.versionCount = gameVersionCursor.count();
    print("  versionCount", game.versionCount);
    
    // Update game name in versions
    while(gameVersionCursor.hasNext()) {
        var gameVersion = gameVersionCursor.next();

        if(!gameVersion.name) {
            print("  Updating game version name for", gameVersion._id, "to", game.name);
            gameVersion.gameName = game.name;
            db["game-versions"].save(gameVersion);
        }
    }

    // Update game
    print ("  Saving game:");
    printjson(game);
    db.games.save(game);
}

