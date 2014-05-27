
Package.describe({
  summary: "Xue is a priority job queue backed by MongoDB, built for Meteor"
});

Package.on_use(function (api, where) {
  api.use('coffeescript');
  api.use(['underscore', 'event-emitter'], 'server');
  api.add_files('src/priorities.coffee', ['client', 'server']);
  api.add_files('src/collections.coffee', ['client', 'server']);
  api.add_files('src/events.coffee', ['server']);
  api.add_files('src/job.coffee', ['server']);
  api.add_files('src/worker.coffee', ['server']);
  api.add_files('src/queue.coffee', ['server']);
  api.add_files('src/index.coffee', ['client', 'server']);
  api.export('Xue');
});
