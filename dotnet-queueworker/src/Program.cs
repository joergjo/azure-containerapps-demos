using System.Diagnostics;
using Azure.Storage.Queues;
using Lamar.Microsoft.DependencyInjection;
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using QueueWorker;
using static QueueWorker.Telemetry;

var host = Host.CreateDefaultBuilder(args)
    .UseLamar()
    .ConfigureServices((hostContext, services) =>
    {
        services.AddHostedService<Worker>();
        services.AddOpenTelemetry()
            .ConfigureResource(resource => resource.AddService(ServiceName))
            .UseOtlpExporter()
            .WithTracing(config =>
            {
                config.AddSource("Azure.*", Telemetry.WorkerActivitySource.Name);
                config.AddSource(WorkerActivitySource.Name);
                config.AddHttpClientInstrumentation(http =>
                {
                    // See https://github.com/Azure/azure-sdk-for-net/blob/main/sdk/core/Azure.Core/samples/Diagnostics.md#avoiding-double-collection-of-http-activities
                    http.FilterHttpRequestMessage = _ => Activity.Current?.Parent?.Source.Name != "Azure.Core.Http";
                });
            })
            .WithMetrics(config =>
            {
                config.AddHttpClientInstrumentation();
                config.AddRuntimeInstrumentation();
                config.AddMeter(WorkerMeter.Name);
            });
        services.AddSingleton(_ =>
        {
            var connectionString = hostContext.Configuration.GetValue<string>("WorkerOptions:StorageConnectionString");
            var queueName = hostContext.Configuration.GetValue<string>("WorkerOptions:QueueName");
            return new QueueClient(connectionString, queueName);
        });
        services.AddSingleton(_ =>
        {
            var decodeBase64 = hostContext.Configuration.GetValue("WorkerOptions:DecodeBase64", true);
            IBodyDecoder decoder = decodeBase64 ? new Base64BodyDecoder() : new IdentityBodyDecoder();
            return decoder;
        });
        var useInitializer = hostContext.Configuration.GetValue("WorkerOptions:InitializeQueue", false);
        if (useInitializer)
        {
            services.AddSingleton<IQueueLifecycle, CreateIfNotExistsQueueLifecycle>();
        }
        else
        {
            services.AddSingleton<IQueueLifecycle, NoopQueueLifecycle>();
        }
    })
    .Build();

await host.RunAsync();