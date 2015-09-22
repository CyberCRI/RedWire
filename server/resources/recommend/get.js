// Recommend for the current user 

if(!me) cancel("You need to be logged in to get recommendations");

recommendFor(me.id, 10, function(gameIds) { 
    dpd.games.get({ id: { $in: gameIds }}, function(games) {
        setResult(games);
    });
});
