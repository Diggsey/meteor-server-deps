# External code can't access this, and so won't be able to directly construct a Deps.Computation instance
privateObj = {}
nextId = 1
afterFlushCallbacks = []
queue = new Meteor._SynchronousQueue()

_.extend Deps,
	currentComputationVar: new Meteor.EnvironmentVariable()
	
	flush: ->
		if not queue.safeToRunTask()
			throw new Error("Can't call Deps.flush while flushing, or inside Deps.autorun")
		
		queue.drain()
			
	_postRun: ->
		while (queue._taskHandles.length == 0) and (afterFlushCallbacks.length > 0)
			f = afterFlushCallbacks.shift()
			try
				f()
			catch e
				console.log "Exception from Deps afterFlush function:", e.stack || e.message
	
	autorun: (f) ->
		c = new Deps.Computation(f, Deps.currentComputation, privateObj)
		
		if Deps.active
			Deps.onInvalidate -> c.stop()
			
		c
	
	nonreactive: (f) ->
		Deps.currentComputationVar.withValue null, f
	
	_makeNonreactive: (f) ->
		if f.$isNonreactive
			return f
		result = (args...) ->
			Deps.nonreactive =>
				f.apply(@, args)
		result.$isNonreactive = true
		result
	
	onInvalidate: (f) ->
		if not Deps.active
			throw new Error("Deps.onInvalidate requires a currentComputation")
			
		Deps.currentComputation.onInvalidate(f)
		
	afterFlush: (f) ->
		afterFlushCallbacks.push(f)

# Compatibility with client-side Deps
Object.defineProperties Deps,
	currentComputation:
		get: ->
			Deps.currentComputationVar.get()
	active:
		get: ->
			!!Deps.currentComputationVar.get()

class Deps.Computation
	constructor: (f, @_parent, p)->
		if p != privateObj
			throw new Error("Deps.Computation constructor is private; use Deps.autorun")
		
		@stopped = false
		@invalidated = false
		@firstRun = true
		@_id = nextId++
		@_onInvalidateCallbacks = []
		@_recomputing = false
		
		Deps.currentComputationVar.withValue @, =>
			@_func = Meteor.bindEnvironment(f, null, @)
		
		errored = true
		try
			@._compute()
			errored = false
		finally
			@firstRun = false
			if errored
				@stop()
	
	onInvalidate: (f) ->
		if typeof f != "function"
			throw new Error("onInvalidate requires a function")
		
		f = Deps._makeNonreactive(Meteor.bindEnvironment(f, null, @))
		
		if @invalidated
			f()
		else
			@_onInvalidateCallbacks.push(f)
		
	invalidate: ->
		if not @invalidated
			if not @_recomputing and not @stopped
				queue.queueTask =>
					@._recompute()
					Deps._postRun()
			
			@invalidated = true
			
			for callback in @_onInvalidateCallbacks
				callback()
			@_onInvalidateCallbacks = []
	
	stop: ->
		if not @stopped
			@stopped = true
			@invalidate()
			
	_compute: ->
		@invalidated = false
		@._func(@)
		
	_recompute: ->
		@_recomputing = true
		while @invalidated and not @stopped
			try
				@._compute()
			catch e
				console.log e
		@_recomputing = false
		
class Deps.Dependency
	constructor: ->
		@_dependentsById = {}
	
	depend: (computation = Deps.currentComputation) ->
		if not computation
			return false
		
		id = computation._id
		
		if not (id of @_dependentsById)
			@_dependentsById[id] = computation
			computation.onInvalidate =>
				delete @_dependentsById[id]
			
			return true
		false
		
	changed: ->
		for id, computation of @_dependentsById
			computation.invalidate()
		
	hasDependents: ->
		for id, computation of @_dependentsById
			return true
		false
		
