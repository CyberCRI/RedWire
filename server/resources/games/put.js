protect("ownerId");
protect("parentId");
protect("createdTime");

if(!internal) {
    if (!me || me.id != this.ownerId) {
        cancel('Only owner can edit game');
    }
    
    protect("playCount");
    protect("forkCount");
    protect("versionCount");
    protect("lastVersionId");
    protect("mixedFromGameIds");
    protect("mixedToGameIds");
    
    this.lastUpdatedTime = new Date().toISOString();
}