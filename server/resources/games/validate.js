if (me)
    this.ownerId = me.id;
else
    cancel("You should be logged in to save a game", 401);

if (this.fileVersion)
    this.fileVersion += 1;
else
    this.fileVersion = 1;