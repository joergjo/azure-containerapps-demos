using System.Text;
using Azure.Storage.Queues;
using Azure.Storage.Queues.Models;

namespace QueueWorker;

public class Worker : BackgroundService
{
    private readonly ILogger<Worker> _logger;
    private readonly QueueClient _queueClient;
    private readonly bool _decodeBase64;

    public Worker(QueueClient queueClient, IConfiguration configuration, ILogger<Worker> logger)
    {
        _queueClient = queueClient;
        _logger = logger;
        _decodeBase64 = configuration.GetValue<bool>("WorkerOptions:DecodeBase64");
    }

    protected override async Task ExecuteAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                QueueMessage message = await _queueClient.ReceiveMessageAsync(cancellationToken: cancellationToken);
                if (message is null)
                {
                    await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
                    continue;
                }

                await _queueClient.DeleteMessageAsync(message.MessageId, message.PopReceipt, cancellationToken);
                var body = _decodeBase64
                    ? Encoding.UTF8.GetString(Convert.FromBase64String(message.Body.ToString()))
                    : message.Body.ToString();
                _logger.LogInformation(
                    "Message received: [{MessageId}] {MessageBody}", message.MessageId, body);
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