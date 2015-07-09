# We patch client side as well so that they have the same API.
unless Tracker.Computation::flush
  Tracker.Computation::flush = ->
    return if @_recomputing

    @_recompute()
