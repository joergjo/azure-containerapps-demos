using Azure.Storage.Queues;
using Lamar.Microsoft.DependencyInjection;
using QueueWorker;

var host = Host.CreateDefaultBuilder(args)
    .UseLamar()
    .ConfigureServices((hostContext, services) =>
    {
        services.AddHostedService<Worker>();
        services.AddApplicationInsightsTelemetryWorkerService();
        services.AddSingleton(_ =>
        {
            var connectionString = hostContext.Configuration.GetValue<string>("WorkerOptions:StorageConnectionString");
            var queueName = hostContext.Configuration.GetValue<string>("WorkerOptions:QueueName");
            return new QueueClient(connectionString, queueName);
        });
    })
    .Build();

await host.RunAsync();
