if (!me || me.id != this.ownerId) {
    cancel('Only owner can edit game');
}

protect("ownerId");
protect("parentId");
if(!internal) {
    protect("playCount");
    protect("forkCount");
    protect("versionCount");
}

this.lastUpdateTime = new Date().toUTCString();
