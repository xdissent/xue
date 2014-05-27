
share.Events = Events = new Meteor.Collection 'xue-events'

share.events = events =

  _subscription: null
  
  jobs: {}

  add: (job) ->
    events.jobs[job.id] = job if job.id?

  remove: (job) -> delete events.jobs[job.id] if events.jobs[job.id]?

  subscribe: (queue) ->
    return if events.queue?
    events.queue = queue
    sel = created_at: $gt: new Date
    options = sort: [['created_at', 'asc']]
    cursor = Events.find sel, options
    events._subscription = cursor.observe
      added: (evt) -> events.onMessage evt

  unsubscribe: ->
    return unless events.queue?
    events._subscription.stop()
    events._subscription = null
    events.queue = null

  onMessage: (msg) ->
    job = events.jobs[msg.id]
    if job?
      job.emit msg.event, msg.args...
      events.remove job if msg.event in ['complete', 'failed', 'killed']
    events?.queue?.emit "job #{msg.event}", msg.id, msg.args...
    
  emit: (id, evt, args...) ->
    Events.insert id: id, event: evt, args: args, created_at: new Date
