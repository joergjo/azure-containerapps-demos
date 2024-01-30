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
    private readonly IQueueLifecycle _lifecycle;

    public Worker(QueueClient queueClient, IBodyDecoder decoder, IQueueLifecycle lifecycle, ILogger<Worker> logger)
    {
        _queueClient = queueClient ?? throw new ArgumentNullException(nameof(queueClient));
        _decoder = decoder ?? throw new ArgumentNullException(nameof(decoder));
        _lifecycle = lifecycle ?? throw new ArgumentNullException(nameof(lifecycle));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
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

    public override async Task StartAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Worker starting: {Time:u}", DateTimeOffset.UtcNow);
        await _lifecycle.InitializeAsync(cancellationToken);
        await base.StartAsync(cancellationToken);
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Worker shutting down: {Time:u}", DateTimeOffset.UtcNow);
        await base.StopAsync(cancellationToken);
        await _lifecycle.CleanupAsync(cancellationToken);
    }
}