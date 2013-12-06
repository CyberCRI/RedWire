if (!me) {
    cancel("You should be logged in to save a game", 401);
} else {
    this.ownerId = me.id;
}