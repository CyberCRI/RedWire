// Get the games liked by the current user

if(!me) cancel("You need to be logged in to get likes");

likedBy(me.id, function(results) { 
    setResult(results);
});