using System;
using System.Threading;
using System.Threading.Tasks;
using Azure.Storage.Queues;
using Azure.Storage.Queues.Models;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace QueueWorker
{
    public class Worker : BackgroundService
    {
        private readonly ILogger _logger;
        private readonly QueueClient _queueClient;

        public Worker(QueueClient queueClient, ILogger<Worker> logger)
        {
            _queueClient = queueClient;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    QueueMessage message = await _queueClient.ReceiveMessageAsync(cancellationToken: stoppingToken);
                    if (message is null)
                    {
                        await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                        continue;
                    }
                    await _queueClient.DeleteMessageAsync(message.MessageId, message.PopReceipt, stoppingToken);
                    _logger.LogInformation(
                        "Message received: [{messageId}] {messageBody}", message.MessageId, message.Body);
                }
                catch (OperationCanceledException)
                {
                    _logger.LogDebug("Shutting down due to cancellation");
                }
                catch (Exception ex)
                {
                    _logger.LogError(
                        ex,
                        "Error processing event at {time:u}",
                        DateTimeOffset.UtcNow);
                }
            }
        }

        public override Task StartAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("Worker starting: {time:u}", DateTimeOffset.UtcNow);
            return base.StartAsync(cancellationToken);
        }

        public override async Task StopAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("Worker shutting down: {time:u}", DateTimeOffset.UtcNow);
            await base.StopAsync(cancellationToken);
        }
    }
}
