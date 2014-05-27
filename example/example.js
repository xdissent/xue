
if (Meteor.isServer) {

  Meteor.startup(function () {

    Xue.Jobs.remove({});
    Xue.Events.remove({});

    var jobs = Xue.createQueue();

    function create() {
        var name = ['tobi', 'loki', 'jane', 'manny'][Math.random() * 4 | 0];
        var data = {
            title: 'converting ' + name + '\'s to avi', user: 1, frames: 200
        };
        if (Math.random() < 0.2) data.crash = true;
        if (Math.random() < 0.3) data.kill = true;
        var j = jobs.create('video conversion', data);
        if (Math.random() < 0.2) j.delay(Math.random() * 120000);
        j.save();
        Meteor.setTimeout(create, Math.random() * 3000 | 0);
    }

    create();

    // process video conversion jobs, 3 at a time.

    jobs.process('video conversion', 3, function (job, done) {
        var frames = job.data.frames,
            running = true;

        job.on('kill', function () {
            console.log('Killed - stopping video worker');
            running = false;
        });

        // console.log("job process %d", job.id);
        function next(i) {
            if (job.data.crash && Math.random() > 0.5)
                return done(new Error('Random crash!'));
            if (job.data.kill && Math.random() > 0.5)
                return job.kill()
            if (Math.random() > 0.99) job.log('Randomly logging %s', job.id);
            // pretend we are doing some work
            convertFrame(i, function (err) {
                if (!running) return;
                if (err) return done(err);
                // report progress, i/frames complete
                job.progress(i, frames);
                if (i == frames) done()
                else next(i + 1);
            });
        }

        next(0);
    });

    function convertFrame(i, fn) {
        Meteor.setTimeout(fn, Math.random() * 100);
    }

    jobs.promote();

  });
}
