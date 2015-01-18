if Meteor.isClient
  collection = new Mongo.Collection null
else
  collection = new Mongo.Collection 'test_collection'

Tinytest.add "tracker - reactive variable", (test) ->
  try
    computation = null
    variable = new ReactiveVar 0

    runs = []

    computation = Tracker.autorun ->
      runs.push variable.get()

    variable.set 1
    Tracker.flush()

    variable.set 1
    Tracker.flush()

    variable.set 2
    Tracker.flush()

    test.equal runs, [0, 1, 2]

  finally
    computation.stop()

Tinytest.add "tracker - queries", (test) ->
  collection.remove {}

  try
    computations = []
    variable = new ReactiveVar 0

    runs = []

    computations.push Tracker.autorun ->
      collection.insert variable: variable.get()

    computations.push Tracker.autorun ->
      variable.get()

      if Meteor.isServer
        # Sleep a bit. To test blocking operations.
        Meteor._sleepForMs 250

      # Non-reactive so that it is the same on client and server.
      # But on the server this is a blocking operation.
      runs.push collection.findOne({}, reactive: false)?.variable

    computations.push Tracker.autorun ->
      variable.get()
      collection.remove {}

    variable.set 1
    Tracker.flush()

    variable.set 1
    Tracker.flush()

    variable.set 2
    Tracker.flush()

    test.equal runs, [0, 1, 2]

  finally
    for computation in computations
      computation.stop()
