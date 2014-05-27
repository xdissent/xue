
class Xue

  @priorities: share.priorities

  @Job: share.Job
  
  @Jobs: share.Jobs

  @Queue: share.Queue

  @Events: share.Events

  @queue: null

  @createQueue: (options) ->
    return if Meteor.isClient
    @queue ?= new @Queue options
    share.events.subscribe @queue
    @queue
