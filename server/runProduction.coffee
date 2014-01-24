#!/usr/bin/env coffee

# Based on http://docs.deployd.com/docs/server/run-script.md
# Meant to be launched with forever.js to avoid failure

deployd = require('deployd')

# Use port 5000 and a separate MongoDB instance
config = 
  port: process.env.PORT || 5000
  env: 'dev'
  db: 
    host: 'localhost'
    port: 27017
    name: 'redwire'

server = deployd(config)
server.listen()

server.on('listening', -> console.log("Server is listening on port #{config.port}"))

server.on 'error', (err) ->
  console.error(err)
  process.nextTick -> # Give the server a chance to return an error
    process.exit()
