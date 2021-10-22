# Jobs

HummingbirdJobs allows you to offload work your server would be doing to another server. You can setup jobs to use different drivers for storing job metadata. The module comes with a driver that stores jobs in local memory and uses your current server to process the jobs, but there is also an implementation that comes with the HummingbirdRedis package that stores jobs in a Redis database. 

## Setting up Jobs

Before you can start adding or processing jobs you need to add a jobs driver to the `HBApplication`. The code below adds a redis driver for jobs. To use a Redis driver you will need to setup Redis first.
```swift
        let app = HBApplication()
        try app.addRedis(
            configuration: .init(
                hostname: Self.redisHostname,
                port: 6379
            )
        )
        app.addJobs(
            using: .redis(configuration: .init(queueKey: "_myJobsQueue")),
            numWorkers: 0
        )
```
In this example I called `addJob` with `numWorkers` set to `0`. This means I can add jobs but they will not be processed. To get another server to process these jobs, I should run a separate version of the app which connects to the same Redis queue but with the `numWorkers` set to the number of threads you want to process the jobs on the queue.

## Creating a Job

First you must define your job. Create an object that inherits from `HBJob`. This protocol requires you to implement a static variable `name` and a function `func execute(on:logger)`. The `name` variable should be unique to this job definition. It is used in the serialisation of the job. The `execute` function does the work of the job and returns an `EventLoopFuture` that should be fulfilled when the job is complete. Below is an example of a job that calls a `sendEmail()` function.
```swift
struct SendEmailJob: HBJob {
    static let name = "SendEmail"
    let to: String
    let subject: String
    let message: String
    
    /// do the work
    func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
        return sendEmail(to: self.to, subject: self.subject, message: self.message)
    }
}
```
Before you use this job you have to register it. 
```swift
SendEmailJob.register()
```
Now you job is ready to create. Jobs can be queued up using the function `enqueue` on `HBJobQueue`. You can access the job queue via `HBApplication.jobs.queue`. There is a helper object attached to `HBRequest` that reduces this to `HBRequest.jobs.enqueue`. 
```swift
let job = SendEmailJob(
    to: "joe@email.com",
    subject: "Testing Jobs",
    message: "..."
)
request.jobs.enqueue(job: job)
```
`enqueue` returns an `EventLoopFuture` that will be fulfilled once the job has been added to the queue.

## Multiple Queues

HummingbirdJobs allows for the creation of multiple job queues. To create a new queue you need a new queue id.
```swift
extension HBJobQueueId {
    static var newQueue: HBJobQueueId { "newQueue" }
}
```
Once you have the new queue id you can register your new queue with this id
```swift
app.jobs.registerQueue(.newQueue, queue: .redis(configuration: .init(queueKey: "_myNewJobsQueue")))
```
Then when adding jobs you add the queue id to the `enqueue` function
```swift
request.jobs.enqueue(job: job, queue: .newQueue)
```
