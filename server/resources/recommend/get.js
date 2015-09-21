// Recommend for the current user 

if(!me) cancel("You need to be logged in to get recommendations");

recommendFor(me.id, 10, function(results) { 
    setResult(results);
});
