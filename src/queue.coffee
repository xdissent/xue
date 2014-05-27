
Worker = share.Worker
Job = share.Job
Jobs = share.Jobs
events = share.events


share.Queue = class Queue extends EventEmitter

  constructor: (options = {}) ->
    super()
    @promoter = null
    @workers = []

  create: (type, data) -> new Job type, data
  
  createJob: -> @create arguments...

  promote: (ms = 5000, limit = 200) ->
    Meteor.clearInterval @promoter if @promoter?
    @promoter = Meteor.setInterval ->
      options = sort: [['delay', 'asc']], limit: limit
      jobs = Jobs.find(state: 'delayed', options).fetch()
      for job in jobs when job.created_at.getTime() + job.delay - Date.now() < 0
        job = Job.create job
        events.emit job.id, 'promotion'
        job.inactive()
    , ms

  process: (type, num, fn) ->
    [fn, num] = [num, 1] if 'function' is typeof num
    for n in [0...num]
      worker = new Worker(this, type).start fn
      @workers.push worker

  types: -> _.uniq Jobs.find({}, fields: _id: false, type: true).map (job) ->
    job.type

  state: (state) ->
    Jobs.find({state: state}, fields: _id: true).map (job) -> job._id

  card: (state) -> Jobs.find(state: state).count()

  complete: -> @state 'complete'

  failed: -> @state 'failed'

  inactive: -> @state 'inactive'

  active: -> @state 'active'
  
  delayed: -> @state 'delayed'

  completeCount: -> @card 'complete'

  failedCount: -> @card 'failed'

  inactiveCount: -> @card 'inactive'

  activeCount: -> @card 'active'

  delayedCount: -> @card 'delayed'

  shutdown: -> # XXX
