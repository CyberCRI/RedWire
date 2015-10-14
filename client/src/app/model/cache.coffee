# Internal function to set in cache
saveToCache = (programId, data) -> 
  value = 
    time: Date.now()
    data: data
  return localforage.setItem(programId, JSON.stringify(value))

# Saves data offline
# localforage handles multiple backends (IndexedDB and LocalStorage)
angular.module("gamEvolve.model.cache", [])
.factory 'cache', ->
  # Saves in cache, or throws exception
  cache = {}
  cache.save = (programId, data) -> 
    # Keep trying to save in cache by removing last item until nothing else can be removed
    saveOrRemove = ->
      saveToCache(programId, data).catch ->
        cache.clearLast.then (wasRemoved) ->
          if wasRemoved then return saveAndRemove() 
          else throw new Error("Too big to save locally") 

    saveOrRemove()

  # Returns code from storage or null if it doesn't exist
  cache.load = (programId) -> 
    localforage.getItem(programId).then (item) -> 
      parsedItem = JSON.parse(item)
      return if parsedItem then parsedItem.data else null
    .catch (error) -> console.error("Error loading from storage", error)

  # Remove code in storage
  # Returns true if an item was removed, false otherwise
  cache.remove = (programId) -> 
    localforage.length().then (oldLength) ->
      localforage.removeItem(programId)
      .then -> localforage.length().then (newLength) ->
          return oldLength > newLength
    .catch (error) -> console.error("Error removing from storage", error)

  # Remove code in storage
  cache.clearAll = -> localforage.clear().catch (error) -> console.error("Error clearing storage", error)

  # Removes the code last used 
  # Returns true if an item was removed, false otherwise
  cache.clearLast = ->
    # Will hold IDs and times
    meta = []

    iterator = (value, key) -> meta.push
      id: key
      time: JSON.parse(value).time

    return localforage.iterate(iterator).then ->
      lastUsed = _.min(meta, (value) -> value.time) 
      return cache.remove(lastUsed.id)
    .catch (error) -> console.error("Error iterating storage", error)

  return cache
