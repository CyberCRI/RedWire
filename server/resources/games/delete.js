var message = "Game deletion is not allowed by non-admin users";
cancelUnless(me, message, 401);
cancelUnless(me.isAdmin, message, 403);