
Future = Npm.require 'fibers/future'

Job = share.Job
Jobs = share.Jobs
events = share.events


KILL_SECRET = '__xue_killed__'


share.Worker = class Worker extends EventEmitter

  constructor: (@queue, @type) -> super()

  start: (fn) ->
    fn = Meteor.bindEnvironment fn
    @getJob (err, job) =>
      @error err, job if err?
      return Meteor.defer(=> @start fn) if err? or !job?
      @process job, fn
    this

  error: (err, job) ->
    err = stack: err.stack, message: err.message if err.stack?
    @emit 'error', err, job
    this

  failed: (job, err, fn) ->
    attempts = job.error(err).failed().attempt()
    if attempts.remaining > 0
      @emit 'job failed attempt', job
      events.emit job.id, 'failed attempt', attempts.attempts
      job.inactive()
    else
      @emit 'job failed', job
      events.emit job.id, 'failed'
    Meteor.defer => @start fn

  killed: (job, fn) ->
    @emit 'job killed', job
    events.emit job.id, 'killed'
    job.killed().attempt()
    Meteor.defer => @start fn

  completed: (job, start, fn) ->
    job.duration = new Date - start
    job.set('duration', job.duration).complete().attempt()
    @emit 'job complete', job
    events.emit job.id, 'complete'
    Meteor.defer => @start fn

  process: (job, fn) ->
    start = new Date
    future = new Future
    job.kill = -> future.throw new Error KILL_SECRET

    kill = (id) =>
      return unless id is job.id
      @queue.removeListener 'job kill', kill
      job.kill()
      
    @queue.on 'job kill', kill

    (->
      try
        future.wait()
      catch err
        job.emit 'kill' if err?.message is KILL_SECRET
        throw err
    ).future()().resolve (err) =>
      @queue.removeListener 'job kill', kill
      job.removeAllListeners 'kill'
      delete job.kill
      return @killed job, fn if err?.message is KILL_SECRET
      return @failed job, err, fn if err?
      @completed job, start, fn

    Meteor.defer ->
      fn job, (err) ->
        return if future.resolved
        return future.throw err if err?
        future.return()

    this

  getJob: (callback) ->
    sel =
      state: 'inactive'
      type: @type
    options =
      sort: [['priority', 'asc']]
      limit: 1
      fields: _id: true
    cursor = Jobs.find sel, options
    stopped = false
    query = cursor.observe
      added: (job) ->
        return query.stop() if query? and stopped
        return if stopped
        activated = Jobs.update _id: job._id, state: 'inactive',
          $set: state: 'active'
        return if activated is 0
        stopped = true
        query.stop() if query?
        Meteor.defer -> callback null, Job.get job._id
