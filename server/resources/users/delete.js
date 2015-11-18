cancelUnless(me, "You must be logged in");

cancelUnless(isMe(this.id) || me.isAdmin, "Only users or admins can modify users"):