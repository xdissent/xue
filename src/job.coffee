
events = share.events
priorities = share.priorities
Jobs = share.Jobs


share.Job = class Job extends EventEmitter

  @get: (id) -> @create Jobs.findOne id

  @create: (hash) ->
    job = new Job
    job.id = hash._id
    job.type = hash.type
    job._delay = hash.delay
    job.priority hash.priority
    job._progress = hash.progress
    job._attempts = hash.attempts
    job._max_attempts = hash.max_attempts
    job._state = hash.state
    job._error = hash.error
    job.created_at = hash.created_at
    job.updated_at = hash.updated_at
    job.failed_at = hash.failed_at
    job.duration = hash.duration
    job.data = hash.data
    job

  constructor: (@type, @data = {}) ->
    super()
    @_max_attempts = 1
    @priority 'normal'
    @on 'error', (err) ->

  log: (str, args...) ->
    count = -1
    str = str.replace /%([sd])/g, (m, type) ->
      count += 1
      if type is 's' then args[count] else args[count] | 0
    Jobs.update @id, $push: logs: message: str, timestamp: new Date
    @set 'updated_at', new Date

  set: (key, val) ->
    mod = {}
    mod[key] = val
    Jobs.update @id, $set: mod
    this

  progress: (complete, total) ->
    return @_progress if arguments.length is 0
    percent = Math.min 100, complete / total * 100 | 0
    @set 'progress', percent
    @set 'updated_at', new Date
    events.emit @id, 'progress', percent
    this

  delay: (ms) ->
    return @_delay if arguments.length is 0
    @_delay = ms
    @_state = 'delayed'
    this

  priority: (level) ->
    return @_priority if arguments.length is 0
    @_priority = priorities[level] ? level
    this

  # XXX Not chainable
  attempt: ->
    Jobs.update @id, $inc: attempts: 1
    job = Jobs.findOne @id,
      fields: _id: false, attempts: true, max_attempts: true
    job.remaining = Math.max 0, job.max_attempts - job.attempts
    job

  attempts: (num) ->
    @_max_attempts = num
    this

  remove: -> Jobs.remove @id

  state: (state) ->
    @_state = state
    @set 'state', state
    @set 'updated_at', new Date

  error: (err) ->
    return @_error if arguments.length is 0
    if 'string' is typeof err
      str = err
      summary = ''
    else
      str = err.stack ? err.message
      summary = str?.split('\n')[0] ? ''
    @set 'failed_at', new Date
    @set 'error', str
    @log '%s', summary
    events.emit @id, 'error', str
    this

  complete: ->
    @set 'progress', 100
    @state 'complete'

  failed: -> @state 'failed'

  inactive: -> @state 'inactive'

  active: -> @state 'active'

  delayed: -> @state 'delayed'

  save: ->
    return @update() if @id?
    job = type: @type, created_at: new Date, attempts: 0, logs: []
    job.max_attempts = @_max_attempts if @_max_attempts?
    @id = Jobs.insert job
    @subscribe()
    @_state ?= 'inactive'
    @update()

  update: ->
    mod = $set:
      updated_at: new Date
      priority: @_priority
      data: @data
      state: @_state
    mod.$set.delay = @_delay if @_delay?
    Jobs.update @id, mod
    this

  subscribe: ->
    events.add this
    this

  killed: ->
    @log 'Killed'
    @state 'killed'

  kill: -> events.emit @id, 'kill'
