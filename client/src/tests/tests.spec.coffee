# Get alias for the global scope
globals = @

makeEvaluator = -> eval

describe "gamEvolve", ->
  beforeEach ->
    @addMatchers 
      toDeeplyEqual: (expected) -> _.isEqual(@actual, expected)
      toBeEmpty: () -> @actual.length == 0

  describe "patches", -> 
    it "can remove value from array", ->
      a = 
        v: [10..15]
      b = 
        v: [10, 12, 13, 14, 15] # Missing 11

      patches = GE.makePatches(a, b)
      patchResult = GE.applyPatches(patches, a)

      expect(patchResult).toDeeplyEqual(b)

  describe "memory", ->
    it "can be created empty", ->
      memory = new GE.Memory()
      expect(memory.version).toEqual(0)
      expect(memory.data).toDeeplyEqual({})

    it "can be created with data", ->
      memory = new GE.Memory({a: 1, b: 2})
      expect(memory.version).toEqual(0)
      expect(memory.data).toDeeplyEqual({a: 1, b: 2})

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
      patches = GE.makePatches(oldData, newData)

      # Create memory objects of the data
      oldMemory = new GE.Memory(oldData)
      newMemory = oldMemory.applyPatches(patches)

      # The new memory and the old memory should still both be valid and different
      expect(oldMemory.version).toEqual(0)
      expect(oldMemory.data).toDeeplyEqual(oldData)
      expect(newMemory.version).toEqual(1)
      expect(newMemory.data).toDeeplyEqual(newData)

    it "rejects conflicting patches", ->
      # Create old data, new data, and the patches between
      oldData = 
        a: 1
      newDataA = 
        a: 2 
      newDataB = 
        b: 3
      patchesA = GE.makePatches(oldData, newDataA)
      patchesB = GE.makePatches(oldData, newDataB)

      # Create memory objects of the data
      oldMemory = new GE.Memory(oldData)
      expect(-> oldMemory.applyPatches(_.flatten([patchesA, patchesB]))).toThrow()

    it "can be retrieved at a given version", ->
      v0 = 
        a: 0
      v1 =
        a: 1
      v2 = 
        a: 2

      memory = new GE.Memory(v0).setData(v1).setData(v2)

      expect(memory.clonedData()).toDeeplyEqual(v2)
      expect(memory.version).toBe(2)

      expect(memory.atVersion(1).clonedData()).toDeeplyEqual(v1)
      expect(memory.atVersion(1).version).toBe(1)

      expect(memory.atVersion(0).clonedData()).toDeeplyEqual(v0)
      expect(memory.atVersion(0).version).toBe(0)


  describe "visitChip()", ->
    it "calls processors", ->
      isCalled = false

      processors = 
        doNothing: 
          pinDefs:
            x: 
              direction: "in" 
              default: "1"
            y: 
              direction: "in"
              default: "'z'"
          update: (pins, transformers, log) ->
            isCalled = true
            expect(pins).toDeeplyEqual
              x: 2
              y: "z"

      board = 
        processor: "doNothing"
        pins: 
          in: 
            x: "1 + 1"

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
                "value": "memory.a"
              out:
                "memory.a": "pins.value"
          },
          {
            processor: "increment"
            pins: 
              in:
                "value": "memory.b"
              out:
                "memory.b": "pins.value"
          },
          {
            processor: "increment"
            pins: 
              in:
                "value": "io.c"
              out:
                "io.c": "pins.value"
          },
          {
            processor: "log"
            pins: 
              in:
                "message": "'hi'"
          },
          { 
            emitter: 
              "memory.message": "transformers.logIt('hi')"
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
              default: "2"
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
            x: "memory.a"
            y: "memory.b"
            e: "assets.image"
          out:
            "memory.a": "pins.x"
            "memory.b": "pins.y"
            "memory.c": "pins.z"

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
          "memory.a.a1": 2
          "memory.b": "memory.c"
          "io.s.a": -5

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
      memorys = [
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
              default: 0
          listActiveChildren: (pins, children, transformers, log) -> 
            expect(children).toDeeplyEqual(["0", "2nd"])
            return [pins.activeChild]
          handleSignals: (pins, children, activeChildren, signals, transformers, log) ->
            expect(children).toDeeplyEqual(["0", "2nd"])
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
            activeChild: "memory.activeChild"
          out: 
            "memory.activeChild": "pins.activeChild"
        children: [
          {
            processor: "reportDone"
            pins: 
              in:
                timesCalled: "memory.child0TimesCalled"
              out:
                "memory.child0TimesCalled": "pins.timesCalled"
          },
          {
            name: "2nd"
            processor: "reportDone"
            pins: 
              in:
                timesCalled: "memory.child1TimesCalled"
              out:
                "memory.child1TimesCalled": "pins.timesCalled"
          }
        ]

      constants = new GE.ChipVisitorConstants
        memoryData: memorys[0]
        processors: processors
        switches: switches
        evaluator: makeEvaluator()
      results = GE.visitChip([], board, constants, {})
      memorys[1] = GE.applyPatches(results.memoryPatches, memorys[0])

      expect(memorys[1].child0TimesCalled).toBe(1)
      expect(memorys[1].child1TimesCalled).toBe(0)
      expect(memorys[1].activeChild).toBe(1)
      
      constants = new GE.ChipVisitorConstants
        memoryData: memorys[1]
        processors: processors
        switches: switches
        evaluator: makeEvaluator()
      results = GE.visitChip([], board, constants, {})
      memorys[2] = GE.applyPatches(results.memoryPatches, memorys[1])

      expect(memorys[2].child0TimesCalled).toBe(1)
      expect(memorys[2].child1TimesCalled).toBe(1)
      expect(memorys[2].activeChild).toBe(2)

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
                name: "bindings.person.first"
                index: "bindings.personIndex"
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
                newName: "bindings.person.first"
                index: "bindings.personIndex"
              out:
                "bindings.person.last": "pins.toChange"
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
            service: "io.serviceA"
          out:
            "io.serviceA": "pins.service"

      constants = new GE.ChipVisitorConstants
        ioData: oldIoData
        processors: processors
        evaluator: makeEvaluator()
      results = GE.visitChip([], board, constants, {})
      newIoData = GE.applyPatches(results.ioPatches, oldIoData)

      expect(newIoData.serviceA.a).toBe(2)

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
            service: "io.myService"
          out: 
            "io.myService": "pins.service" 

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
            service: "io.myService"
          out:
            "io.myService": "pins.service"

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

      processors = 
        group:
          pinDefs: {}
          update: ->
        setDataTo: 
          pinDefs:
            in: 
              value: null
            out:
              var: null
          update: -> @pins.var = @pins.value

      boardA = 
        processor: "group"
        children: [
          {
            processor: "setDataTo"
            pins:
              in:
               value: 1
              out:
                "memory.a": "pins.var"
          },
          {
            processor: "setDataTo"
            pins:
              in:
               value: 2
              out:
                "memory.a": "pins.var"
          }
        ]

      results = GE.stepLoop 
        chip: boardA
        memoryData: oldData
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
               value: 2
              out:
                "io.myService.a": "pins.var"
          },
          {
            processor: "setDataTo"
            pins:
             in:
               value: 2
              out:
                "io.myService.a": "pins.var"
          }
        ]

      results = GE.stepLoop 
        chip: boardB 
        processors: processors 
        io: io
        evaluator: makeEvaluator()
      expect(results.errors.length).not.toBeEmpty()
