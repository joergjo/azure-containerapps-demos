using System.Text;
using Azure.Storage.Queues;
using Azure.Storage.Queues.Models;
using static QueueWorker.Telemetry; 

namespace QueueWorker;

public class Worker : BackgroundService
{
    private readonly ILogger<Worker> _logger;
    private readonly QueueClient _queueClient;
    private readonly IBodyDecoder _decoder;

    public Worker(QueueClient queueClient, IBodyDecoder decoder, ILogger<Worker> logger)
    {
        _queueClient = queueClient;
        _logger = logger;
        _decoder = decoder;
    }

    protected override async Task ExecuteAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            using var activity = WorkerActivitySource.StartActivity("execute");
            try
            {
                QueueMessage message = await _queueClient.ReceiveMessageAsync(cancellationToken: cancellationToken);
                if (message is null)
                {
                    await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
                    continue;
                }

                await _queueClient.DeleteMessageAsync(message.MessageId, message.PopReceipt, cancellationToken);
                MessagesReceivedCounter.Add(1);
                var text = _decoder.Decode(message.Body);
                _logger.LogInformation(
                    "Message received: [{MessageId}] {MessageBody}", message.MessageId, text);
            }
            catch (OperationCanceledException)
            {
                _logger.LogDebug("Shutting down due to cancellation");
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Error processing event at {Time:u}",
                    DateTimeOffset.UtcNow);
            }
        }
    }

    public override Task StartAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Worker starting: {Time:u}", DateTimeOffset.UtcNow);
        return base.StartAsync(cancellationToken);
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Worker shutting down: {Time:u}", DateTimeOffset.UtcNow);
        await base.StopAsync(cancellationToken);
    }
}