# Azure Container Apps sample: .NET Azure Storage Queue worker service

## About

This application is a [.NET 8 worker service](https://learn.microsoft.com/en-us/dotnet/core/extensions/workers?pivots=dotnet-6-0)
that reads messages from an [Azure Queue Storage](https://learn.microsoft.com/en-us/azure/storage/queues/storage-queues-introduction)
and logs them. The service can be deployed as an [Azure Container App](https://learn.microsoft.com/en-us/azure/container-apps/)
and uses [KEDA to scale to zero](https://learn.microsoft.com/en-us/azure/container-apps/scale-app?pivots=azure-cli) if there are no more messages to process.
The application uses [OpenTelemetry](https://opentelemetry.io) to send telemetry data 
to either [Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/) or
any APM tool that offers an OTLP endpoint such as Honeycomb.

## Prerequisites

The following prerequisites are required to use this application. Please ensure
that you have them all installed locally.

- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

## Quickstart

This sample uses the Azure Developer CLI to provision the required Azure services and
to deploy the application.

```bash
# Log in to azd (only required before first use)
azd auth login

# Provision the Azure services
azd provision

# Build your own application container image and deploy
azd deploy
```

`azd` will prompt you to select an Azure subscription, an environment name (e.g., `queueworker-demo`) and an Azure region
when deploying the app for the first time.

Running `azd deploy` is optional. If you only run `azd provision`, the application
will already work, but use a [ready-tou-use container image from Docker Hub](https://hub.docker.com/repository/docker/joergjo/dotnet-queueworker/general).
If you are running `azd deploy`, you will build your own container image and
deploy it instead of using the image from Docker Hub. This also allows you to
change the source code and deploy the application without additional scripts
or infrastructure as code.

Instead of using `azd provision` and `azd deploy`, you can combine
these in one command: `azd up`.

## Testing auto-scaling

The Azure storage account that is created by `azd provision` includes a firewall rule to grant access to your local network (i.e., your router's IP address).

You can use the Azure CLI to quickly create test messages and submit them
to the Azure Queue Storage.

```bash
name=<storage_account_name>
msg=$(echo 'Hello World' | base64)
conn_str=$(az storage account show-connection-string -n $name --query connectionString -o tsv)
for i in {1..10}; do az storage message put --account-name $name -q queueworker --content $msg --connection-string $conn_str; done
```

## Project structure

This project is structured to follow the [Azure Developer CLI](https://aka.ms/azure-dev/overview).
You can learn more about `azd` architecture in [the official documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/make-azd-compatible?pivots=azd-create#understand-the-azd-architecture).

## Additional `azd` commands

- [`azd monitor`](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/monitor-your-app) - to monitor the application and quickly navigate to the various Application Insights dashboards (e.g. overview, live metrics, logs)

- [Run and Debug Locally](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/debug?pivots=ide-vs-code) - using Visual Studio Code and the Azure Developer CLI extension

- [`azd down`](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/reference#azd-down) - to delete all the Azure resources created for this project

## Local development support

The included Compose file allows you to run either just the OpenTelemetry Collector, the Azurite emulator or 
the entire application locally.

### Run the OpenTelemetry Collector

This allows you to run the OpenTelemetry Collector locally, and launch the app from the commandline or
from your IDE.

```bash
cd <path-to-repo>/dotnet-queueworker
export WorkerOptions__StorageConnectionString='<your_storage_connection_string>'
export WorkerOptions__QueueName='<your_queue_name>'
export HONEYCOMB_API_KEY='<your_honeycomb_api_key>'
export HONEYCOMB_DATASET='<your_honeycomb_dataset>'
docker compose up -d
# If running from your IDE, skip the next command and launch the application from your IDE
dotnet run --project src/QueueWorker.csproj
```

### Run the OpenTelemetry Collector and Azurite

This allows you to run the OpenTelemetry Collector and Azurite locally, and launch the app from the commandline or 
from your IDE.

```bash
cd <path-to-repo>/dotnet-queueworker
export WorkerOptions__StorageConnectionString='DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;TableEndpoint=http://127.0.0.1:10002/devstoreaccount1;'
export WorkerOptions__QueueName='dotnet-queueworker'
export HONEYCOMB_API_KEY='<your_honeycomb_api_key>'
export HONEYCOMB_DATASET='<your_honeycomb_dataset>'
docker compose --profile dev up -d
# If running from your IDE, skip the next command and launch the application from your IDE
dotnet run --project src/QueueWorker.csproj
```

### Run the entire application locally

This allows you to run the entire stack locally, except for the OTLP endpoint the collector sends telemetry to. 

```bash
export WorkerOptions__StorageConnectionString='DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;TableEndpoint=http://127.0.0.1:10002/devstoreaccount1;'
export WorkerOptions__QueueName='dotnet-queueworker'
export HONEYCOMB_API_KEY='<your_honeycomb_api_key>'
export HONEYCOMB_DATASET='<your_honeycomb_dataset>'
docker compose --profile all up -d
```