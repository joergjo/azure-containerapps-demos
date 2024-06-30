using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace QueueWorker;

public static class Telemetry
{
    private const string Name = nameof(QueueWorker);
    
    public const string ServiceName = "queue-worker";
    public static readonly ActivitySource WorkerActivitySource = new(Name);
    public static readonly Meter WorkerMeter = new(Name, "1.0.0");
    public static readonly Counter<long> MessagesReceivedCounter = WorkerMeter.CreateCounter<long>(
        "messages_received", 
        description: "Counts the number of received messages");
}