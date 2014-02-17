if (!me || me.id != this.ownerId) {
    cancel('Only owner can edit game');
}

protect("ownerId");
protect("parentId");