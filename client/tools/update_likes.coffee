#!/usr/bin/env coffee

# Copy over likes from raccoon directly into MongoDB

mongodb = require("mongodb")
raccoon = require("raccoon")

DB_URL = "mongodb://localhost:27017/redwire"

raccoon.connect(6379, "localhost")

mongodb.connect(DB_URL).then (db) ->
  console.log("Connected")

  db.collection("games").find({}).toArray (err, games) -> 
    for game in games
      do (game) ->
        console.log("found game", game._id)

        raccoon.likedBy game._id, (likedBy) ->
          # console.log("game", game._id, "liked by", likedBy)

          likeCount = likedBy.length

          console.log("setting likedCount of", game._id, "to", likeCount)
          db.collection("games").findOneAndUpdate({ _id: game._id }, { likeCount: likeCount })

          for userId in likedBy
            do (userId) ->
              console.log("adding game", game._id, "to likes of user", userId)
              db.collection("users").findOneAndUpdate({ _id: userId }, { $addToSet: { "likedGames": game._id }})

    #db.close()
.catch (err) ->
  console.error("Can't connect", err)

