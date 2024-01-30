using Azure.Storage.Queues;
using Lamar.Microsoft.DependencyInjection;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using QueueWorker;

var host = Host.CreateDefaultBuilder(args)
    .UseLamar()
    .ConfigureServices((hostContext, services) =>
    {
        services.AddHostedService<Worker>();
        services.AddOpenTelemetry()
            .ConfigureResource(resource => resource.AddService(hostContext.HostingEnvironment.ApplicationName))
            .WithTracing(builder =>
            {
                builder.AddSource("Azure.*");
                builder.AddSource(nameof(QueueWorker));
                builder.AddHttpClientInstrumentation();
                var exporter = hostContext.Configuration.GetValue("OpenTelemetry:Exporter", defaultValue: "console")!
                    .ToLowerInvariant();
                switch (exporter)
                {
                    case "otlp":
                        builder.AddOtlpExporter();
                        break;
                    case "zipkin":
                        builder.AddZipkinExporter(zipkinOptions =>
                        {
                            zipkinOptions.Endpoint = new Uri(hostContext.Configuration.GetValue("Zipkin:Endpoint",
                                defaultValue: "http://localhost:9411/api/v2/spans")!);
                        });
                        break;
                    default:
                        builder.AddConsoleExporter();
                        break;
                }
            });
        services.AddSingleton(_ =>
        {
            var connectionString = hostContext.Configuration.GetValue<string>("WorkerOptions:StorageConnectionString");
            var queueName = hostContext.Configuration.GetValue<string>("WorkerOptions:QueueName");
            return new QueueClient(connectionString, queueName);
        });
    })
    .Build();

await host.RunAsync();