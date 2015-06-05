# Tracker.Computation constructor is private, so we are using this object as a guard.
# External code cannot access this, and will not be able to directly construct a
# Tracker.Computation instance.
privateObject = {}

nextId = 1
willFlush = false
inFlush = false
inCompute = false
firstError = false
throwFirstError = false
queue = new Meteor._SynchronousQueue()
afterFlushCallbacks = []

# Copied from tracker.js.
_debugFunc = ->
  return Meteor._debug if Meteor?._debug

  if console?.log
    return ->
      console.log.apply console, arguments

  return ->

# Copied from tracker.js, but it stores the first error if throwFirstError is set.
_throwOrLog = (from, error) ->
  if throwFirstError
    firstError = error
    throwFirstError = false
  else
    messageAndStack = undefined
    if error.stack and error.message
      idx = error.stack.indexOf error.message
      if idx >= 0 and idx <= 10
        messageAndStack = error.stack
      else
        messageAndStack = error.message + (if error.stack.charAt(0) is '\n' then '' else '\n') + error.stack
    else
      messageAndStack = error.stack or error.message

    _debugFunc() "Exception from Tracker " + from + " function:", messageAndStack

requireFlush = ->
  return if willFlush

  Meteor.defer ->
    Tracker.flush _requireFlush: true
  willFlush = true

_.extend Tracker,
  _currentComputation: new Meteor.EnvironmentVariable()

  flush: (_options) ->
    if inFlush or queue._draining
      # We ignore flushes which come from requireFlush if they are while some other flush
      # is in progress. It is safe to just return here, as in this case we are still inside
      # the main flush loop at least in some fiber. So any flush requests will still be
      # handled by that loop.
      return if _options?._requireFlush

      throw new Error "Can't call Tracker.flush while flushing"

    if inCompute or not queue.safeToRunTask()
      # We ignore flushes which come from requireFlush if they are while some other flush
      # is in progress. In this case we cannot simply return as no fiber is actually running
      # the main flush loop (if it was, then inFlush would be true and the above code block
      # would run). We must defer the flush function to be retried as otherwise this will
      # leave willFlush at true and will thus block all future flushes.
      if _options?._requireFlush
        Meteor.defer ->
          Tracker.flush _options
        return

      throw new Error "Can't flush inside Tracker.autorun"

    inFlush = true
    willFlush = true
    firstError = null
    throwFirstError = !!_options?._throwFirstError

    # XXX COMPAT WITH METEOR 1.0.3.2
    if queue._taskHandles.isEmpty
      isQueueEmpty = -> queue._taskHandles.isEmpty.call queue._taskHandles
    else
      isQueueEmpty = -> _.isEmpty(queue._taskHandles)

    try
      while not isQueueEmpty() or afterFlushCallbacks.length
        queue.drain()

        if afterFlushCallbacks.length
          func = afterFlushCallbacks.shift()
          try
            func()
          catch error
            _throwOrLog "afterFlush", error

      # If throwFirstError is set, only the first error is stored away, and
      # the rest is still flushed, with potential future errors going to the log.
      # This matches the behavior of the client-side Tracker, but the approach
      # is different. No recursive calls to the flush.
      throw firstError if firstError
    finally
      firstError = null
      willFlush = false
      inFlush = false

  autorun: (f) ->
    throw new Error 'Tracker.autorun requires a function argument' unless typeof f is 'function'

    c = new Tracker.Computation f, Tracker.currentComputation, privateObject

    if Tracker.active
      Tracker.onInvalidate ->
        c.stop()

    c

  nonreactive: (f) ->
    Tracker._currentComputation.withValue null, f

  onInvalidate: (f) ->
    throw new Error "Tracker.onInvalidate requires a currentComputation" unless Tracker.active

    Tracker.currentComputation.onInvalidate(f)

  afterFlush: (f) ->
    afterFlushCallbacks.push f
    requireFlush()

# Compatibility with the client-side Tracker. On node.js we can use defineProperties to define getters.
Object.defineProperties Tracker,
  currentComputation:
    get: ->
      # We want to make sure we are returning null and not
      # undefined if there is no current computation.
      Tracker._currentComputation.get() or null

  active:
    get: ->
      !!Tracker._currentComputation.get()

class Tracker.Computation
  constructor: (f, @_parent, _private) ->
    throw new Error "Tracker.Computation constructor is private; use Tracker.autorun" if _private isnt privateObject

    @stopped = false
    @invalidated = false
    @firstRun = true
    @_id = nextId++
    @_onInvalidateCallbacks = []
    @_recomputing = false

    onException = (error) =>
      throw error if @firstRun
      _throwOrLog "recompute", error

    Tracker._currentComputation.withValue @, =>
      @_func = Meteor.bindEnvironment f, onException, @

    errored = true
    try
      @_compute()
      errored = false
    finally
      @firstRun = false
      @stop() if errored

  onInvalidate: (f) ->
    throw new Error "onInvalidate requires a function" unless typeof f is 'function'

    if @invalidated
      Tracker.nonreactive =>
        f @
    else
      @_onInvalidateCallbacks.push f

  invalidate: ->
    if not @invalidated
      if not @_recomputing and not @stopped
        requireFlush()
        queue.queueTask =>
          @_recompute()

      @invalidated = true

      for callback in @_onInvalidateCallbacks
        Tracker.nonreactive =>
          callback @
      @_onInvalidateCallbacks = []

  stop: ->
    if not @stopped
      @stopped = true
      @invalidate()

  _compute: ->
    @invalidated = false
    previousInCompute = inCompute
    inCompute = true
    try
      @_func @
    finally
      inCompute = previousInCompute

  _recompute: ->
    @_recomputing = true
    while @invalidated and not @stopped
      @_compute()
    @_recomputing = false

class Tracker.Dependency
  constructor: ->
    @_dependentsById = {}

  depend: (computation) ->
    unless computation
      return false unless Tracker.currentComputation
      computation = Tracker.currentComputation

    id = computation._id

    if id not of @_dependentsById
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
