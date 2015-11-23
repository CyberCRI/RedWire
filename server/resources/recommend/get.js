// Recommend for the current user 

if(!me) cancel("You need to be logged in to get recommendations");

if(query.count) 
{
    recommendFor(me.id, 3, function(gameIds) { 
        setResult({ count: gameIds.length });
    });
}
else 
{
    recommendFor(me.id, 3, function(gameIds) { 
        dpd.games.get({ id: { $in: gameIds }}, function(games) {
            setResult(games);
        });
    });
}

