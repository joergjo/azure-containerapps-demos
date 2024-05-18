using Azure.Storage.Queues;
using Lamar.Microsoft.DependencyInjection;
using OpenTelemetry.Exporter;
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
            .ConfigureResource(resource => resource.AddService(hostContext.HostingEnvironment.ApplicationName))
            .WithTracing(builder =>
            {
                builder.AddSource("Azure.*", Telemetry.WorkerActivitySource.Name);
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
            })
            .WithMetrics(metrics =>
            {
                metrics.AddHttpClientInstrumentation();
                metrics.AddRuntimeInstrumentation();
                metrics.AddMeter(WorkerMeter.Name);
                metrics.AddOtlpExporter((exporterOptions, metricReaderOptions) =>
                {
                    exporterOptions.Endpoint = new Uri("http://localhost:9090/api/v1/otlp/v1/metrics");
                    exporterOptions.Protocol = OtlpExportProtocol.HttpProtobuf;
                    metricReaderOptions.PeriodicExportingMetricReaderOptions.ExportIntervalMilliseconds = 1000;
                });
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