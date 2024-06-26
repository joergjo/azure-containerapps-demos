# azure-containerapps-demos

This repo contains Azure Container Apps sample apps. These samples can be deployed
using their included deployment scripts&mdash;these require a Bash shell. Some of the projects have been updated to make use of the Azure Developer CLI and can be
run on either Bash (macOS, Linux) or PowerShell (Windows).  

## A collection of demo applications for [Azure Container Apps](https://azure.microsoft.com/en-us/services/container-apps/)

### [dotnet-queueworker](https://github.com/joergjo/azure-containerapps-demos/tree/main/dotnet-queueworker)
A .NET 8 worker service that reads messages from Azure Queue Storage using [KEDA](https://learn.microsoft.com/en-us/azure/container-apps/scale-app?pivots=azure-cli) to scale to zero.


### [go-helloworld](https://github.com/joergjo/azure-containerapps-demos/tree/main/go-helloworld)
A Go "Hello World" API that can be used as quick start and to demo [revisions](https://docs.microsoft.com/en-us/azure/container-apps/revisions), [configuration](https://learn.microsoft.com/en-us/azure/container-apps/containers#configuration) and [structured logging](https://learn.microsoft.com/en-us/azure/container-apps/logging) using [Logrus](https://github.com/sirupsen/logrus).

### [go-chi-todo](https://github.com/joergjo/azure-containerapps-demos/tree/main/go-chi-todo)
A Go "To Do" API that uses [`chi`](https://go-chi.io/) for routing and [`pgx`](https://github.com/jackc/pgx) to access PostgreSQL. It demonstrates passwordless access to an [Azure Database for PostgreSQL Flexible Server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/overview) and structured logging using the [slog](https://pkg.go.dev/golang.org/x/exp/slog) package.   


### [go-cronjob](https://github.com/joergjo/azure-containerapps-demos/tree/main/go-cronjob)
A Go application that demonstrates the use of the [KEDA Cron scaler](https://keda.sh/docs/2.9/scalers/cron/) to mimic a cron job with Azure Container Apps. 

*This sample predates the availability of [Scheduled Jobs](https://learn.microsoft.com/en-us/azure/container-apps/jobs?tabs=azure-cli#scheduled-jobs). Check out those first!*  


### [java-boot-todo](https://github.com/joergjo/azure-containerapps-demos/tree/main/java-boot-todo)
A Spring Boot "To Do" API that uses JPA to access a PostgreSQL database (adopted from [Azure's Spring Boot docs](https://docs.microsoft.com/en-us/azure/developer/java/spring-framework/configure-spring-data-jpa-with-azure-postgresql)). It demonstrates passwordless access to an [Azure Database for PostgreSQL Flexible Server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/overview), structured logging and using [Datadog's Azue Container Apps agent](https://docs.datadoghq.com/serverless/azure_container_apps).
