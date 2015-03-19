# Internal function to set in cache
saveToCache = (programId, data) -> 
  value = 
    time: Date.now()
    data: data
  localStorage.setItem(programId, JSON.stringify(value))

# Saves data in a LocalStorage LRU cache
# TODO: use polyfill for LocalStorage?
# TODO: use IndexedDB for more space
angular.module("gamEvolve.model.cache", [])
.factory 'cache', ->
  # Saves in cache, or throws exception
  save: (programId, data) -> 
    if not localStorage then throw new Error("LocalStorage not available")

    # Keep trying to save in cache by removing last item until there are no more items
    loop
      try
        saveToCache(programId, data)
        return
      catch e
        if localStorage.length is 0
          throw new Error("Too big to fit in LocalStorage")
        @clearLast()

  # Returns code from LocalStorage or null if it doesn't exist
  load: (programId) -> 
    if not localStorage then throw new Error("LocalStorage not available")

    item = JSON.parse(localStorage.getItem(programId))
    return if item then item.data else null

  # Remove code in LocalStorage
  remove: (programId) -> localStorage.removeItem(programId)

  # Remove code in LocalStorage
  clearAll: -> localStorage.clear()

  # Removes the code last used 
  clearLast: ->
    meta = for key, value of localStorage 
      id: key
      time: JSON.parse(value).time
    lastUsed = _.min(meta, (value) -> value.time) 
    @remove(lastUsed.id)

