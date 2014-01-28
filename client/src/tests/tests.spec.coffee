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
          paramDefs:
            x: 
              direction: "in" 
              default: "1"
            y: 
              direction: "in"
              default: "'z'"
          update: (params, transformers, log) ->
            isCalled = true
            expect(params).toDeeplyEqual
              x: 2
              y: "z"

      board = 
        processor: "doNothing"
        params: 
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
          paramDefs: {}
          update: -> timesCalled++

      switches = 
        doAll: 
          paramDefs: {}
          handleSignals: -> timesCalled++

      board = 
        switch: "doAll"
        params: {}
        children: [
          {
            processor: "doNothing"
            params: {}
          },
          {
            processor: "doNothing"
            params: {}
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
          paramDefs: 
            value: 
              direction: "inout"
          update: (params, transformers, log) -> params.value++
        log: 
          paramDefs: 
            message: null
          update: (params, transformers, log) -> log(GE.logLevels.INFO, params.message)

      switches = 
        doAll: 
          paramDefs: {}

      # Transformers must be compiled this way
      # TODO: create function that does this work for us
      transformers = {}
      transformers.logIt = GE.compileTransformer("log(GE.logLevels.INFO, msg); return msg;", ["msg"], eval)(transformers)

      board = 
        switch: "doAll"
        params: {}
        children: [
          {
            processor: "increment"
            params: 
              in:
                "value": "memory.a"
              out:
                "memory.a": "params.value"
          },
          {
            processor: "increment"
            params: 
              in:
                "value": "memory.b"
              out:
                "memory.b": "params.value"
          },
          {
            processor: "increment"
            params: 
              in:
                "value": "io.c"
              out:
                "io.c": "params.value"
          },
          {
            processor: "log"
            params: 
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

    it "evaluates parameters for processors", ->
      oldMemory = 
        a: 1
        b: 10
        c: 20

      assets = { image: new Image() }

      processors = 
        adjustMemory: 
          paramDefs:
            x: 
              direction: "inout"
            y: 
              direction: "inout"
            z:
              direction: "out"
            d: 
              default: "2"
            e: {}
          update: (params, transformers, log) ->
            params.x++
            params.y--
            params.z = 30
            expect(params.d).toBe(2)
            expect(params.e).toBe(assets.image)

      board = 
        processor: "adjustMemory"
        params:
          in:  
            x: "memory.a"
            y: "memory.b"
            e: "assets.image"
          out:
            "memory.a": "params.x"
            "memory.b": "params.y"
            "memory.c": "params.z"

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
          paramDefs: 
            activeChild: 
              direction: "inout"
              default: 0
          listActiveChildren: (params, children, transformers, log) -> 
            expect(children).toDeeplyEqual(["0", "2nd"])
            return [params.activeChild]
          handleSignals: (params, children, activeChildren, signals, transformers, log) ->
            expect(children).toDeeplyEqual(["0", "2nd"])
            if signals[params.activeChild] == GE.signals.DONE 
              params.activeChild++
            if params.activeChild >= children.length - 1
              return GE.signals.DONE

      processors =
        reportDone:
          paramDefs:
            timesCalled: 
              direction: "inout"
          update: (params, transformers, log) -> 
            params.timesCalled++
            return GE.signals.DONE

      board = 
        switch: "nextOnDone"
        params: 
          in:
            activeChild: "memory.activeChild"
          out: 
            "memory.activeChild": "params.activeChild"
        children: [
          {
            processor: "reportDone"
            params: 
              in:
                timesCalled: "memory.child0TimesCalled"
              out:
                "memory.child0TimesCalled": "params.timesCalled"
          },
          {
            name: "2nd"
            processor: "reportDone"
            params: 
              in:
                timesCalled: "memory.child1TimesCalled"
              out:
                "memory.child1TimesCalled": "params.timesCalled"
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
          paramDefs:
            name: 
              direction: "in" 
            index: 
              direction: "in"
          update: (params, transformers, log) -> 
            expect(params.index).toEqual(if params.name is "bill" then "0" else "1")

      spyOn(processors.getName, "update").andCallThrough()

      board = 
        splitter:
          from: people
          bindTo: "person"
          index: "personIndex"
        children: [
          { 
            processor: "getName"
            params: 
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
          paramDefs:
            newName: 
              direction: "in" 
            toChange: 
              direction: "out"
            index: 
              direction: "in"
          update: (params, transformers, log) -> 
            expect(params.index).toEqual(if params.newName is "bill" then "0" else "1")
            params.toChange = params.newName

      board = 
        splitter:
          from: "memory.people"
          bindTo: "person"
          index: "personIndex"
        children: [
          { 
            processor: "changeName"
            params: 
              in: 
                newName: "bindings.person.first"
                index: "bindings.personIndex"
              out:
                "bindings.person.last": "params.toChange"
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
          paramDefs:
            service:
              direction: "inout"
          update: (params, transformers, log) -> 
            expect(params.service.a).toBe(1)
            params.service.a++

      board = 
        processor: "incrementIoData"
        params:
          in:
            service: "io.serviceA"
          out:
            "io.serviceA": "params.service"

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
          paramDefs:
            service:
              direction: "inout"
          update: (params, transformers, log) -> 
            expect(params.service.a).toBe(1)
            params.service.a++

      board = 
        processor: "incrementIoData"
        params:
          in: 
            service: "io.myService"
          out: 
            "io.myService": "params.service" 

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
          paramDefs:
            service: 
              direction: "inout"
          update: (params, transformers, log) -> 
            expect(transformers.testTransformer(params.service.a, 2)._1).toBe(1)
            params.service.a++

      board = 
        processor: "incrementIoData"
        params:
          in:
            service: "io.myService"
          out:
            "io.myService": "params.service"

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
          paramDefs: {}
          update: ->
        setDataTo: 
          paramDefs:
            in: 
              value: null
            out:
              var: null
          update: -> @params.var = @params.value

      boardA = 
        processor: "group"
        children: [
          {
            processor: "setDataTo"
            params:
              in:
               value: 1
              out:
                "memory.a": "params.var"
          },
          {
            processor: "setDataTo"
            params:
              in:
               value: 2
              out:
                "memory.a": "params.var"
          }
        ]

      expect(-> GE.stepLoop 
        chip: boardA
        memoryData: oldData
        processors: processors 
        evaluator: makeEvaluator()
      ).toThrow()
      
      boardB = 
        processor: "group"
        children: [
          {
            processor: "setDataTo"
            params:
             in:
               value: 2
              out:
                "io.myService.a": "params.var"
          },
          {
            processor: "setDataTo"
            params:
             in:
               value: 2
              out:
                "io.myService.a": "params.var"
          }
        ]

      expect(-> GE.stepLoop 
        chip: boardB 
        processors: processors 
        io: io
        evaluator: makeEvaluator()
      ).toThrow()
