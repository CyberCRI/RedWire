# Get alias for the global scope
globals = @

compileExpression = (expression) -> RW.compileExpression(expression, eval)
compileEmitter = (expression) -> RW.compileEmitter(expression, eval)

describe "RedWire", ->
  beforeEach ->
    @addMatchers 
      toDeeplyEqual: (expected) -> _.isEqual(@actual, expected)
      toBeEmpty: () -> @actual.length == 0
      toDeeplyContain: (expected) -> 
        for x in @actual
          if _.isEqual(x, expected) then return true
        return false

  describe "memory", -> 
    it "can remove value from array", ->
      a = 
        v: [10..15]
      b = 
        v: [10, 12, 13, 14, 15] # Missing 11

      patches = RW.makePatches(a, b)
      patchResult = RW.applyPatches(patches, a)

      expect(patchResult).toDeeplyEqual(b)

    it "can be patched", ->
      # Create old data, new data, and the patches between
      oldData = 
        a: 1
        b: 
          b1: true
          b2: "hi"
      newData = 
        b: 
          b1: true
          b2: "there"
        c: 
          bob: "is cool"

      # Create the result via patches
      patches = RW.makePatches(oldData, newData)
      result = RW.applyPatches(patches, oldData)

      # The new data and old data should still be valid and different
      expect(oldData).not.toDeeplyEqual(newData)
      expect(result).toDeeplyEqual(newData)

    it "detects conflicting patches", ->
      # Test changing same attribute
      oldData = 
        a: 
          b: 1
        c: 2
      newDataA = 
        a: 
          b: 2
      newDataB = 
        a:
          b: 3
        c: 2
      
      patchesA = RW.makePatches(oldData, newDataA, "a")
      patchesB = RW.makePatches(oldData, newDataB, "b")
      allPatches = RW.concatenate(patchesA, patchesB)

      conflicts = RW.detectPatchConflicts(allPatches)
      expect(conflicts.length).toBe(1)
      expect(conflicts[0].path).toBe("/a/b")

      # Test child attribute
      oldData = 
        a: 
          b: 1
      newDataA = 
        a: 
          b: 
            c: 2
      newDataB = 
        a:
          b: 3
      
      patchesA = RW.makePatches(oldData, newDataA, "a")
      patchesB = RW.makePatches(oldData, newDataB, "b")
      allPatches = RW.concatenate(patchesA, patchesB)

      conflicts = RW.detectPatchConflicts(allPatches)
      expect(conflicts.length).toBe(1)
      expect(conflicts[0].path).toBe("/a/b")

       # Test no conflict
      oldData = 
        a: 
          b: 1
        c: 2
      newDataA = 
        a: 
          b: 2
        c: 2
      newDataB = 
        a: 
          b: 1
        c: 3
      
      patchesA = RW.makePatches(oldData, newDataA, "a")
      patchesB = RW.makePatches(oldData, newDataB, "b")
      allPatches = RW.concatenate(patchesA, patchesB)

      conflicts = RW.detectPatchConflicts(allPatches)
      expect(conflicts).toBeEmpty()

    # Issue #299
    it "does not consider parent removal as conflict", ->
      patches = [
        {
          "remove": "/explosions/0",
          "path": [
            "0"
          ]
        },
        {
          "replace": "/explosions/0/frame",
          "value": 65,
          "path": [
            "1",
            "0",
            "0"
          ]
        }
      ]

      conflicts = RW.detectPatchConflicts(patches)
      expect(conflicts).toBeEmpty()

    it "does not consider identical modifications as conflict", ->
      # Test changing same attribute
      oldData = 
        a: 1
        b: 1
      newDataA = 
        a: 2
        b: 2
      newDataB = 
        a: 2
        b: 1
      
      patchesA = RW.makePatches(oldData, newDataA, "a")
      patchesB = RW.makePatches(oldData, newDataB, "b")
      allPatches = RW.concatenate(patchesA, patchesB)

      conflicts = RW.detectPatchConflicts(allPatches)
      expect(conflicts).toBeEmpty()

      result = RW.applyPatches(allPatches, oldData)
      expect(result).toDeeplyEqual({ a: 2, b: 2 })

    it "adds to and removes from arrays", ->
      oldData = 
        a: [1, 2, 3]
      newDataA = 
        a: [1, 2, 3, 4]
      newDataB = 
        a: [2, 3]
      
      patchesA = RW.makePatches(oldData, newDataA, "a")
      patchesB = RW.makePatches(oldData, newDataB, "b")
      allPatches = RW.concatenate(patchesA, patchesB)

      conflicts = RW.detectPatchConflicts(allPatches)
      expect(conflicts).toBeEmpty()

      result = RW.applyPatches(allPatches, oldData)
      expect(result).toDeeplyEqual({ a: [2, 3, 4] })

    it "modifies within arrays", ->
      oldData = 
        a: [{ b: 1 }, { c: 2 }, { f: 5 }, 6]
      newDataA = 
        a: [{ b: 1 }, { c: -2 }, { d: 3 }, { e: 4 }, { f: 5 }, 6]
      newDataB = 
        a: [{ b: -1 }, { c: 2 }, { f: 5 }, -6, { g: 7 }]
      
      patchesA = RW.makePatches(oldData, newDataA, "a")
      patchesB = RW.makePatches(oldData, newDataB, "b")
      allPatches = RW.concatenate(patchesA, patchesB)

      conflicts = RW.detectPatchConflicts(allPatches)
      expect(conflicts).toBeEmpty()

      result = RW.applyPatches(allPatches, oldData)
      expect(result).toDeeplyEqual({ a: [{ b: -1 }, { c: -2 }, { d: 3 }, { e: 4 }, { f: 5 }, -6, { g: 7 }] })

  describe "parsing", ->
    it "can find references to memory and io", ->
      # Multi-part references
      code = """
        memory.x.y["z"] = 2;
      """
      dependencies = RW.findFunctionDependencies(code)
      expect(dependencies.length).toBe(1)
      expect(dependencies[0]).toDeeplyEqual(["memory", "x", "y", "z"])

      # Filter out parents
      code = """
        memory.x = 1;
        memory.x.y = 2;
      """
      dependencies = RW.findFunctionDependencies(code)
      expect(dependencies.length).toBe(1)

      # Handle number indices
      code = """
        memory.x[2].y = 1;
      """
      dependencies = RW.findFunctionDependencies(code)
      expect(dependencies.length).toBe(1)
      expect(dependencies[0]).toDeeplyEqual(["memory", "x"])

      # Only deal with memory and io
      code = """
        memory.x = 1;
        io.z = 3;
        var a = 4;
      """
      dependencies = RW.findFunctionDependencies(code)
      expect(dependencies.length).toBe(2)

      # Capture in all places
      code = """
        var x = memory.a;
        function f() { return memory.b; }
        [memory.c];
        { i: 1 + memory.d }
        f(memory.e);
        function g() { return memory.f; }
      """
      dependencies = RW.findFunctionDependencies(code)
      expect(dependencies.length).toBe(6)

  describe "stimulateCircuits()", ->
    it "calls emitters", ->
      oldMemory = 
        a: 1
        b: 10

      board = 
        emitter: compileEmitter("memory.a += memory.b")
      
      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        memoryData: 
          main: oldMemory
      results = RW.stimulateCircuits(constants)

      expect(results.circuitResults.main.memoryPatches.length).toBe(1)
      newMemory = RW.applyPatches(results.circuitResults.main.memoryPatches, oldMemory)

      expect(newMemory.a).toBe(11)
      expect(newMemory.b).toBe(10)

    it "emitters can write to new keys and unknown parents", ->
      oldMemory = 
        a: 1

      board = 
        emitter: compileEmitter("memory.b = memory.a + 1")
      
      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        memoryData: 
          main: oldMemory
      results = RW.stimulateCircuits(constants)

      expect(results.circuitResults.main.memoryPatches.length).toBe(1)
      newMemory = RW.applyPatches(results.circuitResults.main.memoryPatches, oldMemory)

      expect(newMemory.a).toBe(1)
      expect(newMemory.b).toBe(2)

    it "calls processors", ->
      isCalled = false

      processors = 
        doNothing: 
          pinDefs: 
            x: 
              direction: "in" 
              default: compileExpression("1")
            y: 
              direction: "in"
              default: compileExpression("'z'")
          update: (pins, transformers, log) ->
            isCalled = true
            expect(pins).toDeeplyEqual
              x: 2
              y: "z"

      board = 
        processor: "doNothing"
        pins: 
          in: 
            x: compileExpression("1 + 1")

      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        processors: processors
      RW.stimulateCircuits(constants)
      expect(isCalled).toBeTruthy()

    it "calls children of switches", ->
      timesCalled = 0

      processors = 
        doNothing: 
          pinDefs: {}
          update: -> timesCalled++

      switches = 
        doAll: 
          pinDefs: {}
          handleSignals: -> timesCalled++

      board = 
        switch: "doAll"
        pins: {}
        children: [
          {
            processor: "doNothing"
            pins: {}
          },
          {
            processor: "doNothing"
            pins: {}
          }
        ]

      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        processors: processors
        switches: switches
      RW.stimulateCircuits(constants)
      expect(timesCalled).toEqual(3)

    it "returns the path for patches", ->
      memoryData =
        a: 0
        b: 1
        message: null

      ioData = 
        c: 2

      processors = 
        increment: 
          pinDefs: 
            value: 
              direction: "inout"
          update: (pins, transformers, log) -> pins.value++
        log: 
          pinDefs: 
            message: null
          update: (pins, transformers, log) -> log(RW.logLevels.INFO, pins.message)

      switches = 
        doAll: 
          pinDefs: {}

      # Transformers must be compiled this way
      # TODO: create function that does this work for us
      transformers = {}
      transformers.logIt = RW.compileTransformer("log(RW.logLevels.INFO, msg); return msg;", ["msg"], eval)(transformers)

      board = 
        switch: "doAll"
        pins: {}
        children: [
          {
            processor: "increment"
            pins: 
              in:
                "value": compileExpression("memory.a")
              out:
                "memory.a": compileExpression("pins.value")
          },
          {
            processor: "increment"
            pins: 
              in:
                "value": compileExpression("memory.b")
              out:
                "memory.b": compileExpression("pins.value")
          },
          {
            processor: "increment"
            pins: 
              in:
                "value": compileExpression("io.c")
              out:
                "io.c": compileExpression("pins.value")
          },
          {
            processor: "log"
            pins: 
              in:
                "message": compileExpression("'hi'")
          },
          { 
            emitter: compileEmitter("memory.message = transformers.logIt('hi');")
          }
        ]

      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        processors: processors
        switches: switches
        transformers: transformers
        memoryData: 
          main: memoryData
        ioData: 
          main: ioData
      results = RW.stimulateCircuits(constants)

      mainResults = results.circuitResults.main

      expect(mainResults.memoryPatches.length).toBe(3)
      for memoryPatch in mainResults.memoryPatches
        if memoryPatch.replace is "/a"
          expect(memoryPatch.path).toDeeplyEqual(["0"])
        else if memoryPatch.replace is "/b"
          expect(memoryPatch.path).toDeeplyEqual(["1"])
        else if memoryPatch.replace is "/message"
          expect(memoryPatch.path).toDeeplyEqual(["4"])
        else 
          throw new Error("Memory patch affects wrong attribute")

      expect(mainResults.ioPatches.length).toBe(1)
      expect(mainResults.ioPatches[0].path).toDeeplyEqual(["2"])

      expect(mainResults.logMessages.length).toBe(2)
      expect(mainResults.logMessages[0].path).toDeeplyEqual(["3"])
      expect(mainResults.logMessages[1].path).toDeeplyEqual(["4"])

    it "evaluates pins for processors", ->
      oldMemory = 
        a: 1
        b: 10
        c: 20

      assets = { image: new Image() }

      processors = 
        adjustMemory: 
          pinDefs:
            x: 
              direction: "inout"
            y: 
              direction: "inout"
            z:
              direction: "out"
            d: 
              default: compileExpression("2")
            e: {}
          update: (pins, transformers, log) ->
            pins.x++
            pins.y--
            pins.z = 30
            expect(pins.d).toBe(2)
            expect(pins.e).toBe(assets.image)

      board = 
        processor: "adjustMemory"
        pins:
          in:  
            x: compileExpression("memory.a")
            y: compileExpression("memory.b")
            e: compileExpression("assets.image")
          out:
            "memory.a": compileExpression("pins.x")
            "memory.b": compileExpression("pins.y")
            "memory.c": compileExpression("pins.z")

      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        processors: processors
        memoryData: 
          main: oldMemory
        assets: assets
      results = RW.stimulateCircuits(constants)
      newMemory = RW.applyPatches(results.circuitResults.main.memoryPatches, oldMemory)

      # The new memory should be changed, but the old one shouldn't be
      expect(oldMemory.a).toBe(1)
      expect(oldMemory.b).toBe(10)
      expect(oldMemory.c).toBe(20)
      expect(newMemory.a).toBe(2)
      expect(newMemory.b).toBe(9)
      expect(newMemory.c).toBe(30)

    it "sends to memory and io", ->
      oldMemory = 
        a: 
          a1: 1
        b: 10
        c: "hi"

      oldIoData = 
        s: 
          a: -1

      board = 
        emitter: compileEmitter("""
          memory.a.a1 = 2;
          memory.b = memory.c;
          io.s.a = -5;
        """)
      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        memoryData: 
          main: oldMemory
        ioData: 
          main: oldIoData
      results = RW.stimulateCircuits(constants)
      newMemory = RW.applyPatches(results.circuitResults.main.memoryPatches, oldMemory)
      newIoData = RW.applyPatches(results.circuitResults.main.ioPatches, oldIoData)

      # The new memory and io should be changed, but the old ones shouldn't be
      expect(oldMemory.a.a1).toBe(1)
      expect(oldMemory.b).toBe(10)
      expect(oldIoData.s.a).toBe(-1)

      expect(newMemory.a.a1).toBe(2)
      expect(newMemory.b).toBe("hi")
      expect(newIoData.s.a).toBe(-5)

    it "checks and adjusts activation", ->
      memories = [
        {
          activeChild: 0
          child0TimesCalled: 0
          child1TimesCalled: 0
        }
      ]

      switches = 
        nextOnDone: 
          pinDefs: 
            activeChild: 
              direction: "inout"
              default: compileExpression("0")
          listActiveChildren: (pins, children, transformers, log) -> 
            expect(children).toDeeplyEqual([0, "2nd"])
            return [children[pins.activeChild]]
          handleSignals: (pins, children, activeChildren, signals, transformers, log) ->
            expect(children).toDeeplyEqual([0, "2nd"])
            if signals[pins.activeChild] == RW.signals.DONE 
              pins.activeChild++
            if pins.activeChild >= children.length - 1
              return RW.signals.DONE

      processors =
        reportDone:
          pinDefs:
            timesCalled: 
              direction: "inout"
          update: (pins, transformers, log) -> 
            pins.timesCalled++
            return RW.signals.DONE

      board = 
        switch: "nextOnDone"
        pins: 
          in:
            activeChild: compileExpression("memory.activeChild")
          out: 
            "memory.activeChild": compileExpression("pins.activeChild")
        children: [
          {
            processor: "reportDone"
            pins: 
              in:
                timesCalled: compileExpression("memory.child0TimesCalled")
              out:
                "memory.child0TimesCalled": compileExpression("pins.timesCalled")
          },
          {
            name: "2nd"
            processor: "reportDone"
            pins: 
              in:
                timesCalled: compileExpression("memory.child1TimesCalled")
              out:
                "memory.child1TimesCalled": compileExpression("pins.timesCalled")
          }
        ]

      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        processors: processors
        switches: switches
        memoryData: 
          main: memories[0]
      results = RW.stimulateCircuits(constants)
      memories[1] = RW.applyPatches(results.circuitResults.main.memoryPatches, memories[0])

      expect(memories[1].child0TimesCalled).toBe(1)
      expect(memories[1].child1TimesCalled).toBe(0)
      expect(memories[1].activeChild).toBe(1)
      
      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        processors: processors
        switches: switches
        memoryData: 
          main: memories[1]
      results = RW.stimulateCircuits(constants)
      memories[2] = RW.applyPatches(results.circuitResults.main.memoryPatches, memories[1])

      expect(memories[2].child0TimesCalled).toBe(1)
      expect(memories[2].child1TimesCalled).toBe(1)
      expect(memories[2].activeChild).toBe(2)

    it "binds across constant arrays", ->
      people = [
        { first: "bill", last: "bobson" }
        { first: "joe", last: "johnson" }
      ]

      processors = 
        getName: 
          pinDefs:
            name: 
              direction: "in" 
            index: 
              direction: "in"
          update: (pins, transformers, log) -> 
            expect(pins.index).toEqual(if pins.name is "bill" then "0" else "1")

      spyOn(processors.getName, "update").andCallThrough()

      board = 
        splitter:
          from: people
          bindTo: "person"
          index: "personIndex"
        children: [
          { 
            processor: "getName"
            pins: 
              in: 
                name: compileExpression("bindings.person.first")
                index: compileExpression("bindings.personIndex")
          }
        ]

      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        processors: processors
      RW.stimulateCircuits(constants)

      expect(processors.getName.update).toHaveBeenCalled()

    it "binds across memory arrays", ->
      oldMemory = 
        people: [
          { first: "bill", last: "bobson" }
          { first: "joe", last: "johnson" }
        ]

      processors = 
        changeName: 
          pinDefs:
            newName: 
              direction: "in" 
            toChange: 
              direction: "out"
            index: 
              direction: "in"
          update: (pins, transformers, log) -> 
            expect(pins.index).toEqual(if pins.newName is "bill" then "0" else "1")
            pins.toChange = pins.newName

      board = 
        splitter:
          from: "memory.people"
          bindTo: "person"
          index: "personIndex"
        children: [
          { 
            processor: "changeName"
            pins: 
              in: 
                newName: compileExpression("bindings.person.first")
                index: compileExpression("bindings.personIndex")
              out:
                "bindings.person.last": compileExpression("pins.toChange")
          }
        ]

      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        processors: processors
        memoryData: 
          main: oldMemory
      results = RW.stimulateCircuits(constants)
      newMemory = RW.applyPatches(results.circuitResults.main.memoryPatches, oldMemory)

      expect(newMemory.people[0].last).toBe("bill")
      expect(newMemory.people[1].last).toBe("joe")

    it "binds with where guard", ->
      oldMemory = 
        people: [
          { first: "bill", last: "bobson" }
          { first: "joe", last: "johnson" }
        ]

      processors = 
        getName: 
          pinDefs:
            lastName: null
          update: (pins, transformers, log) -> 
            expect(pins.lastName).toEqual("bobson")

      board = 
        splitter:
          from: "memory.people"
          bindTo: "person"
          where: compileExpression("bindings.person.first == 'bill'")
        children: [
          { 
            processor: "getName"
            pins: 
              in: 
                lastName: compileExpression("bindings.person.last")
          }
        ]

      spyOn(processors.getName, "update").andCallThrough()

      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        processors: processors
        memoryData: 
          main: oldMemory
      results = RW.stimulateCircuits(constants)

      expect(processors.getName.update).toHaveBeenCalled()

    it "communicates with io", ->
      oldIoData = 
        serviceA: 
          a: 1

      processors = 
        incrementIoData: 
          pinDefs:
            service:
              direction: "inout"
          update: (pins, transformers, log) -> 
            expect(pins.service.a).toBe(1)
            pins.service.a++

      board = 
        processor: "incrementIoData"
        pins:
          in:
            service: compileExpression("io.serviceA")
          out:
            "io.serviceA": compileExpression("pins.service")

      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        processors: processors
        ioData: 
          main: oldIoData
      results = RW.stimulateCircuits(constants)
      newIoData = RW.applyPatches(results.circuitResults.main.ioPatches, oldIoData)

      expect(newIoData.serviceA.a).toBe(2)

    it "ignores muted chips", ->
      timesCalled = 0

      processors = 
        doNothing: 
          pinDefs: {}
          update: -> timesCalled++

      switches = 
        doAll: 
          pinDefs: {}

      board = 
        switch: "doAll"
        pins: {}
        children: [
          {
            processor: "doNothing"
            pins: {}
          },
          {
            processor: "doNothing"
            pins: {}
            muted: true
          }
        ]

      # Only one of these chips should have been called
      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        processors: processors
        switches: switches
      RW.stimulateCircuits(constants)
      expect(timesCalled).toEqual(1)

    it "handles multiple circuits", ->
      switches = 
        doAll: 
          pinDefs: {}

      circuits = 
        main: new RW.Circuit
          board:
            switch: "doAll"
            children: [
              { 
                emitter: compileEmitter("""
                  memory.a.a1 = 2;
                  memory.b = memory.c;
                  io.s.a = -5;
                """)
              }
              { 
                circuit: "sub"
                id: "subId"
              }
            ]
        sub: new RW.Circuit
          board: 
            emitter: compileEmitter("""
              memory.a = 99;
              memory.b = memory.c;
              io.s.a = 100;
            """)

      memoryData = 
        main: 
          a: 
            a1: 1
          b: 10
          c: "hi"
        "main.subId":
          a: 32
          b: "hi"
          c: "bye"

      ioData = 
        main: 
          s: 
            a: -1
        "main.subId":
          s: 
            a: -1

      constants = new RW.ChipVisitorConstants
        circuits: circuits 
        switches: switches
        memoryData: memoryData
        ioData: ioData
      results = RW.stimulateCircuits(constants)

      newMemory = {}
      newIo = {}
      for name in ["main", "main.subId"]
        newMemory[name] = RW.applyPatches(results.circuitResults[name].memoryPatches, memoryData[name])
        newIo[name] = RW.applyPatches(results.circuitResults[name].ioPatches, ioData[name])

      expect(newMemory.main.a.a1).toBe(2)
      expect(newMemory.main.b).toBe("hi")
      expect(newIo.main.s.a).toBe(-5)
      expect(newMemory["main.subId"].a).toBe(99)
      expect(newMemory["main.subId"].b).toBe("bye")
      expect(newMemory["main.subId"].c).toBe("bye")
      expect(newIo["main.subId"].s.a).toBe(100)

    it "circuits can have pins", ->
      switches = 
        doAll: 
          pinDefs: {}

      circuits = 
        main: new RW.Circuit
          board:
            switch: "doAll"
            children: [
              { 
                emitter: compileEmitter("""
                  memory.a = 2;
                """)
              }
              { 
                circuit: "sub"
                id: "subId"
                pins: 
                  in: 
                    p: compileExpression("10")
                    q: compileExpression("20")
                  out:
                    "memory.b": compileExpression("pins.q")
              }
            ]
        sub: new RW.Circuit
          pinDefs:
            p: 
              direction: "in"
            q: 
              direction: "inout"
          board: 
            emitter: compileEmitter("""
              memory.a = 99;
              circuit.q = circuit.p + circuit.q;
            """)

      memoryData = 
        main: 
          a: 0
          b: 0
        "main.subId":
          a: 32

      constants = new RW.ChipVisitorConstants
        circuits: circuits 
        switches: switches
        memoryData: memoryData
      results = RW.stimulateCircuits(constants)

      newMemory = {}
      for name in ["main", "main.subId"]
        newMemory[name] = RW.applyPatches(results.circuitResults[name].memoryPatches, memoryData[name])

      expect(newMemory.main.a).toBe(2)
      expect(newMemory.main.b).toBe(30)
      expect(newMemory["main.subId"].a).toBe(99)

    it "sends data across pipes", ->
      memoryData = 
        x: 5
        y: 1

      board = 
        pipe: 
          bindTo: "cumul"
          initialValue: compileExpression("memory.x")
          outputDestination: "memory.y"
        children: [
          {
            emitter: compileEmitter("bindings.cumul = bindings.cumul + 1")
          }
          {
            emitter: compileEmitter("memory.x = bindings.cumul")
          }
          {
            emitter: compileEmitter("bindings.cumul = bindings.cumul + 1")
          }
        ]

      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        memoryData:
          main: memoryData
      results = RW.stimulateCircuits(constants)

      newMemory = RW.applyPatches(results.circuitResults["main"].memoryPatches, memoryData)
      expect(newMemory.x).toEqual(6)
      expect(newMemory.y).toEqual(7)

    it "handles nested pipes", ->
      memoryData = 
        outerX: 5
        outerY: 5
        innerX: 2
        innerY: 2

      board = 
        pipe: 
          bindTo: "outerBind"
          initialValue: compileExpression("memory.outerX")
          outputDestination: "memory.outerY"
        children: [
          {
            emitter: compileEmitter("bindings.outerBind = bindings.outerBind + 1")
          }
          {
            pipe: 
              bindTo: "innerBind"
              initialValue: compileExpression("memory.innerX")
              outputDestination: "memory.innerY"
            children: [
              {
                emitter: compileEmitter("bindings.innerBind = bindings.outerBind + 1")
              }
            ]
          } 
          {
            emitter: compileEmitter("bindings.outerBind = bindings.outerBind + 2")
          }
        ]

      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        memoryData:
          main: memoryData
      results = RW.stimulateCircuits(constants)

      newMemory = RW.applyPatches(results.circuitResults["main"].memoryPatches, memoryData)
      expect(newMemory.innerY).toEqual(7)
      expect(newMemory.outerY).toEqual(8)

    it "returns active chips paths", ->
      processors = 
        doNothing: 
          pinDefs: {}
          update: -> 

      switches = 
        doAll: 
          pinDefs: {}

      board = 
        switch: "doAll"
        pins: {}
        children: [
          {
            processor: "doNothing"
            pins: {}
          }
          {
            processor: "doNothing"
            pins: {}
            muted: true
          }
          {
            switch: "doAll"
            pins: {}
            children: [
              {
                processor: "doNothing"
                pins: {}
              }
            ]
          }
          {
            processor: "doNothing"
            pins: {}
          }
        ]

      constants = new RW.ChipVisitorConstants
        circuits:  
          main: new RW.Circuit
            board: board
        processors: processors
        switches: switches
      results = RW.stimulateCircuits(constants)
      
      expect(results.circuitResults.main.activeChipPaths.length).toBe(5)
      expect(results.circuitResults.main.activeChipPaths).toDeeplyContain([])
      expect(results.circuitResults.main.activeChipPaths).toDeeplyContain(["0"])
      expect(results.circuitResults.main.activeChipPaths).toDeeplyContain(["2"])
      expect(results.circuitResults.main.activeChipPaths).toDeeplyContain(["2", "0"])
      expect(results.circuitResults.main.activeChipPaths).toDeeplyContain(["3"])

  describe "stepLoop()", ->
    it "sends output data directly to io", ->
      io = 
        myService:
          establishData: jasmine.createSpy()

      outputIoData = 
        main: 
          myService:
            a = 1

      result = RW.stepLoop 
        io: io
        outputIoData: outputIoData

      expect(io.myService.establishData).toHaveBeenCalled()
      expect(io.myService.establishData.calls.length).toEqual(1)
      # Only test 1st argument
      expect(io.myService.establishData.calls[0].args[0]).toEqual({ main: 1 }) 

      expect(_.size(result.memoryPatches)).toBe(0)
      expect(_.size(result.ioPatches)).toBe(0)

    it "sends io input data to stimulateCircuits()", ->
      io = 
        myService:
          establishData: jasmine.createSpy()

      inputIoData = 
        global:
          myService:
            a: 0
        main:
          myService:
            a: 1

      processors = 
        incrementIoData: 
          pinDefs:
            service:
              direction: "inout"
          update: (pins, transformers, log) -> 
            expect(pins.service.a).toBe(1)
            pins.service.a++

      board = 
        processor: "incrementIoData"
        pins:
          in: 
            service: compileExpression("io.myService")
          out: 
            "io.myService": compileExpression("pins.service")

      result = RW.stepLoop 
        circuits: 
          main: new RW.Circuit
            board: board
        processors: processors 
        io: io
        inputIoData: inputIoData

      expect(io.myService.establishData).toHaveBeenCalled()
      expect(io.myService.establishData.calls.length).toEqual(1)
      # Only test 1st argument
      expect(io.myService.establishData.calls[0].args[0]).toEqual({ main: { a: 2 } }) 

      expect(result.memoryPatches.main).toBeEmpty()
      expect(result.ioPatches.main.length).toEqual(1)

    it "gathers io input data, visits chips, uses transformers, and gives output to io", ->
      io = 
        myService:
          provideData: -> { main: { a: 1 } }
          establishData: jasmine.createSpy()

      spyOn(io.myService, "provideData").andCallThrough()

      transformers =
        testTransformer: (arg1, arg2) -> return {_1: arg1, _2: arg2};

      processors = 
        incrementIoData: 
          pinDefs:
            service: 
              direction: "inout"
          update: (pins, assets,  transformers, log) -> 
            expect(transformers.testTransformer(pins.service.a, 2)._1).toBe(1)
            pins.service.a++

      board = 
        processor: "incrementIoData"
        pins:
          in:
            service: compileExpression("io.myService")
          out:
            "io.myService": compileExpression("pins.service")

      result = RW.stepLoop 
        circuits:
          main: new RW.Circuit
            board: board
        processors: processors 
        transformers: transformers
        io: io

      expect(io.myService.provideData).toHaveBeenCalledWith()

      expect(io.myService.establishData).toHaveBeenCalled()
      expect(io.myService.establishData.calls.length).toEqual(1)
      # Only test 1st argument
      expect(io.myService.establishData.calls[0].args[0]).toEqual({ main: { a: 2 } }) 

      expect(result.memoryPatches).toDeeplyEqual({ main: [] })

    it "rejects conflicting patches", ->
      # Create old data, new data, and the patches between
      oldData = 
        a: 0

      io = 
        myService:
          provideData: -> return { main: { a: 0 } }
          establishData: jasmine.createSpy()

      switches = 
        group:
          pinDefs: {}

      processors = 
        setDataTo: 
          pinDefs:
            value: null
            var:
              direction: "out"
          update: (pins, transformers, log) -> pins.var = pins.value

      boardA = 
        switch: "group"
        children: [
          {
            processor: "setDataTo"
            pins:
              in:
               value: compileExpression("1")
              out:
                "memory.a": compileExpression("pins.var")
          },
          {
            processor: "setDataTo"
            pins:
              in:
               value: compileExpression("2")
              out:
                "memory.a": compileExpression("pins.var")
          }
        ]

      results = RW.stepLoop 
        circuits:
          main: new RW.Circuit
            board: boardA
        switches: switches
        processors: processors 
        memoryData: 
          main: oldData
      expect(results.errors[0].stage).toBe("patchMemory")
      
      boardB = 
        switch: "group"
        children: [
          {
            processor: "setDataTo"
            pins:
             in:
               value: compileExpression("1")
              out:
                "io.myService.a": compileExpression("pins.var")
          },
          {
            processor: "setDataTo"
            pins:
             in:
               value: compileExpression("2")
              out:
                "io.myService.a": compileExpression("pins.var")
          }
        ]

      results = RW.stepLoop 
        circuits:
          main: new RW.Circuit
            board: boardB 
        switches: switches
        processors: processors 
        io: io
      expect(results.errors[0].stage).toBe("patchIo")
