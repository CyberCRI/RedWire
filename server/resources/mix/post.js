// Expecting a URL like /mix/from/{sourceGameId}/to/{destinationGameId} 
// Update the mix counts for the two games

if(!me) cancel("You need to be logged in to report mixes");
if(parts.length < 4) cancel("Expecting a URL like /mix/from/{sourceGameId}/to/{destinationGameId}");

var sourceGameId = parts[1];
var destGameId = parts[3];

if(sourceGameId == destGameId) cancel("You can't mix yourself with yourself");

// DPD doesn't support MongoDB set operations, so we have to do this manually
function addToSet(set, value) {
    if(!set) set = [];
    if(set.indexOf(value) == -1) set.push(value);
    return set;
}

dpd.games.get({ id: destGameId }, function(destGame) {
    if(me.id != destGame.ownerId) cancel("You must be the owner of the destination game");
    
    var set = addToSet(destGame.mixedFromGameIds, sourceGameId);
    dpd.games.put({ id: destGameId }, { mixedFromGameIds: set });    

    dpd.games.get({ id: sourceGameId }, function(sourceGame) {
        var set = addToSet(sourceGame.mixedToGameIds, destGameId);
        dpd.games.put({ id: sourceGameId }, { mixedToGameIds: set });
    });
});
