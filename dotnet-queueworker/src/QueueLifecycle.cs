using Azure.Storage.Queues;
using static QueueWorker.Telemetry;

namespace QueueWorker;

public interface IQueueLifecycle
{
    Task InitializeAsync(CancellationToken cancellationToken = default) { return Task.CompletedTask; }
    Task CleanupAsync(CancellationToken cancellationToken = default) { return Task.CompletedTask; }
}

public class NoopQueueLifecycle : IQueueLifecycle
{
}

public class CreateIfNotExistsQueueLifecycle : IQueueLifecycle
{
    private readonly QueueClient _queueClient;
    private readonly ILogger _logger;
    
    public CreateIfNotExistsQueueLifecycle(QueueClient queueClient, ILogger<CreateIfNotExistsQueueLifecycle> logger)
    {
        _queueClient = queueClient ?? throw new ArgumentNullException(nameof(queueClient));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }
    
    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        using var activity = WorkerActivitySource.StartActivity("initialize");
        _logger.LogInformation("Creating queue if it does not exist");
        var response = await _queueClient.CreateIfNotExistsAsync(cancellationToken: cancellationToken);
        if (response is not null)
        {
            _logger.LogInformation("Queue {Queue} created", _queueClient.Name);
        }
        else
        {
            _logger.LogInformation("Queue {Queue} already exists", _queueClient.Name);
        }
    }
}