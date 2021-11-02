using System.Threading.Tasks;
using Azure.Storage.Queues;
using Lamar.Microsoft.DependencyInjection;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Oakton;

namespace QueueWorker
{
    public class Program
    {
        public static Task<int> Main(string[] args)
        {
            return CreateHostBuilder(args).RunOaktonCommands(args);
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
             Host.CreateDefaultBuilder(args)
                 .UseLamar()
                 .ConfigureServices((hostContext, services) =>
                 {
                     services.AddHostedService<Worker>();
                     services.AddApplicationInsightsTelemetryWorkerService();
                     services.AddSingleton<QueueClient>(services =>
                     {
                         string connectionString = hostContext.Configuration["WorkerOptions:StorageConnectionString"];
                         string queueName = hostContext.Configuration["WorkerOptions:QueueName"];
                         return new QueueClient(connectionString, queueName);
                     });
                 });
    }
}
