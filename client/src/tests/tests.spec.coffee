# Get alias for the global scope
globals = @

makeEvaluator = -> eval

compileExpression = (expression) -> GE.compileExpression(expression, eval)


describe "gamEvolve", ->
  beforeEach ->
    @addMatchers 
      toDeeplyEqual: (expected) -> _.isEqual(@actual, expected)
      toBeEmpty: () -> @actual.length == 0

  describe "memory", -> 
    it "can remove value from array", ->
      a = 
        v: [10..15]
      b = 
        v: [10, 12, 13, 14, 15] # Missing 11

      patches = GE.makePatches(a, b)
      patchResult = GE.applyPatches(patches, a)

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
      patches = GE.makePatches(oldData, newData)
      result = GE.applyPatches(patches, oldData)

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
      
      patchesA = GE.makePatches(oldData, newDataA, "a")
      patchesB = GE.makePatches(oldData, newDataB, "b")
      allPatches = GE.concatenate(patchesA, patchesB)

      conflicts = GE.detectPatchConflicts(allPatches)
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
      
      patchesA = GE.makePatches(oldData, newDataA, "a")
      patchesB = GE.makePatches(oldData, newDataB, "b")
      allPatches = GE.concatenate(patchesA, patchesB)

      conflicts = GE.detectPatchConflicts(allPatches)
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
      
      patchesA = GE.makePatches(oldData, newDataA, "a")
      patchesB = GE.makePatches(oldData, newDataB, "b")
      allPatches = GE.concatenate(patchesA, patchesB)

      conflicts = GE.detectPatchConflicts(allPatches)
      expect(conflicts).toBeEmpty()

    # Issue #299
    it "detects more conflicting patches", ->
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

      conflicts = GE.detectPatchConflicts(patches)
      expect(conflicts.length).toBe(1)

  describe "visitChip()", ->
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

      constants = new GE.ChipVisitorConstants
        processors: processors
        evaluator: makeEvaluator()
      GE.visitChip([], board, constants, {})
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

      constants = new GE.ChipVisitorConstants
        processors: processors
        switches: switches
      GE.visitChip([], board, constants, {})
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
          update: (pins, transformers, log) -> log(GE.logLevels.INFO, pins.message)

      switches = 
        doAll: 
          pinDefs: {}

      # Transformers must be compiled this way
      # TODO: create function that does this work for us
      transformers = {}
      transformers.logIt = GE.compileTransformer("log(GE.logLevels.INFO, msg); return msg;", ["msg"], eval)(transformers)

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
            emitter: 
              "memory.message": compileExpression("transformers.logIt('hi')")
          }
        ]

      constants = new GE.ChipVisitorConstants
        memoryData: memoryData
        ioData: ioData
        processors: processors
        switches: switches
        evaluator: eval
        transformers: transformers
      results = GE.visitChip([], board, constants, {})

      expect(results.memoryPatches.length).toBe(3)
      for memoryPatch in results.memoryPatches
        if memoryPatch.replace is "/a"
          expect(memoryPatch.path).toDeeplyEqual(["0"])
        else if memoryPatch.replace is "/b"
          expect(memoryPatch.path).toDeeplyEqual(["1"])
        else if memoryPatch.replace is "/message"
          expect(memoryPatch.path).toDeeplyEqual(["4"])
        else 
          throw new Error("Memory patch affects wrong attribute")

      expect(results.ioPatches.length).toBe(1)
      expect(results.ioPatches[0].path).toDeeplyEqual(["2"])

      expect(results.logMessages.length).toBe(2)
      expect(results.logMessages[0].path).toDeeplyEqual(["3"])
      expect(results.logMessages[1].path).toDeeplyEqual(["4"])

    it "evaluates pineters for processors", ->
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

      constants = new GE.ChipVisitorConstants 
        memoryData: oldMemory, 
        assets: assets
        processors: processors
        evaluator: makeEvaluator()
      results = GE.visitChip([], board, constants, {})
      newMemory = GE.applyPatches(results.memoryPatches, oldMemory)

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
        emitter: 
          "memory.a.a1": compileExpression("2")
          "memory.b": compileExpression("memory.c")
          "io.s.a": compileExpression("-5")

      constants = new GE.ChipVisitorConstants
        memoryData: oldMemory
        ioData: oldIoData
        evaluator: makeEvaluator()
      results = GE.visitChip([], board, constants, {})
      newMemory = GE.applyPatches(results.memoryPatches, oldMemory)
      newIoData = GE.applyPatches(results.ioPatches, oldIoData)

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
            if signals[pins.activeChild] == GE.signals.DONE 
              pins.activeChild++
            if pins.activeChild >= children.length - 1
              return GE.signals.DONE

      processors =
        reportDone:
          pinDefs:
            timesCalled: 
              direction: "inout"
          update: (pins, transformers, log) -> 
            pins.timesCalled++
            return GE.signals.DONE

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

      constants = new GE.ChipVisitorConstants
        memoryData: memories[0]
        processors: processors
        switches: switches
        evaluator: makeEvaluator()
      results = GE.visitChip([], board, constants, {})
      memories[1] = GE.applyPatches(results.memoryPatches, memories[0])

      expect(memories[1].child0TimesCalled).toBe(1)
      expect(memories[1].child1TimesCalled).toBe(0)
      expect(memories[1].activeChild).toBe(1)
      
      constants = new GE.ChipVisitorConstants
        memoryData: memories[1]
        processors: processors
        switches: switches
        evaluator: makeEvaluator()
      results = GE.visitChip([], board, constants, {})
      memories[2] = GE.applyPatches(results.memoryPatches, memories[1])

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

      constants = new GE.ChipVisitorConstants
        processors: processors
        evaluator: makeEvaluator()
      GE.visitChip([], board, constants, {})

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

      constants = new GE.ChipVisitorConstants
        memoryData: oldMemory
        processors: processors
        evaluator: makeEvaluator()
      results = GE.visitChip([], board, constants, {})
      newMemory = GE.applyPatches(results.memoryPatches, oldMemory)

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

      constants = new GE.ChipVisitorConstants
        memoryData: oldMemory
        processors: processors
        evaluator: makeEvaluator()
      results = GE.visitChip([], board, constants, {})

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

      constants = new GE.ChipVisitorConstants
        ioData: oldIoData
        processors: processors
        evaluator: makeEvaluator()
      results = GE.visitChip([], board, constants, {})
      newIoData = GE.applyPatches(results.ioPatches, oldIoData)

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
      constants = new GE.ChipVisitorConstants
        processors: processors
        switches: switches
      GE.visitChip([], board, constants, {})
      expect(timesCalled).toEqual(1)

  describe "stepLoop()", ->
    it "sends output data directly to io", ->
      io = 
        myService:
          establishData: jasmine.createSpy()

      outputIoData = 
        myService:
          a = 1

      result = GE.stepLoop 
        io: io
        outputIoData: outputIoData

      expect(io.myService.establishData).toHaveBeenCalledWith(outputIoData.myService, {}, {})
      expect(result.memoryPatches).toBeEmpty()
      expect(result.ioPatches).toBeEmpty()

    it "sends io input data to visitChip()", ->
      io = 
        myService:
          establishData: jasmine.createSpy()

      inputIoData = 
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

      result = GE.stepLoop 
        chip: board
        processors: processors 
        io: io
        inputIoData: inputIoData
        evaluator: makeEvaluator()

      expect(io.myService.establishData).toHaveBeenCalledWith({ a: 2 }, {}, {})
      expect(result.memoryPatches).toBeEmpty()
      expect(result.ioPatches.length).toEqual(1)

    it "gathers io input data, visits chips, uses transformers, and gives output to io", ->
      io = 
        myService:
          provideData: -> return { a: 1 }
          establishData: jasmine.createSpy()

      spyOn(io.myService, "provideData").andCallThrough()

      transformers = {
        testTransformer: (arg1, arg2) -> return {_1: arg1, _2: arg2};
      }

      processors = 
        incrementIoData: 
          pinDefs:
            service: 
              direction: "inout"
          update: (pins, transformers, log) -> 
            expect(transformers.testTransformer(pins.service.a, 2)._1).toBe(1)
            pins.service.a++

      board = 
        processor: "incrementIoData"
        pins:
          in:
            service: compileExpression("io.myService")
          out:
            "io.myService": compileExpression("pins.service")

      ioConfig = { configA: 1 }

      result = GE.stepLoop 
        chip: board
        processors: processors 
        transformers: transformers
        io: io
        ioConfig: ioConfig
        evaluator: makeEvaluator()

      expect(io.myService.provideData).toHaveBeenCalledWith(ioConfig, {})
      expect(io.myService.establishData).toHaveBeenCalledWith({ a: 2 }, ioConfig, {})
      expect(result.memoryPatches).toBeEmpty()

    it "rejects conflicting patches", ->
      # Create old data, new data, and the patches between
      oldData = 
        a: 0

      io = 
        myService:
          provideData: -> return { a: 0 }
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
               value: 1
              out:
                "memory.a": compileExpression("pins.var")
          },
          {
            processor: "setDataTo"
            pins:
              in:
               value: 2
              out:
                "memory.a": compileExpression("pins.var")
          }
        ]

      results = GE.stepLoop 
        chip: boardA
        memoryData: oldData
        switches: switches
        processors: processors 
        evaluator: makeEvaluator()
      expect(results.errors.length).not.toBeEmpty()
      
      boardB = 
        processor: "group"
        children: [
          {
            processor: "setDataTo"
            pins:
             in:
               value: compileExpression("2")
              out:
                "io.myService.a": compileExpression("pins.var")
          },
          {
            processor: "setDataTo"
            pins:
             in:
               value: compileExpression(2)
              out:
                "io.myService.a": compileExpression("pins.var")
          }
        ]

      results = GE.stepLoop 
        chip: boardB 
        processors: processors 
        io: io
        evaluator: makeEvaluator()
      expect(results.errors.length).not.toBeEmpty()
