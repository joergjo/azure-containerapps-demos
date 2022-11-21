# azure-containerapps-demos

## A collection of demo applications to try out [Azure Container Apps](https://azure.microsoft.com/en-us/services/container-apps/)

- [dotnet-queueworker](https://github.com/joergjo/azure-containerapps-demos/tree/main/dotnet-queueworker): A .NET 6 worker service that reads messages from Azure Storage Queues using [Dapr](http://dapr.io).
- [go-helloworld](https://github.com/joergjo/azure-containerapps-demos/tree/main/go-helloworld): 
Go "Hello World" API that can be used as quick start and to test [revisions](https://docs.microsoft.com/en-us/azure/container-apps/revisions) and [structured logging](https://docs.microsoft.com/en-us/azure/container-apps/monitor?tabs=bash#simple-text-vs-structured-data).
- [go-cronjob](https://github.com/joergjo/azure-containerapps-demos/tree/main/go-cronjob): Demonstrates hwo to use the [KEDA Cron scaler] to mimic a CronJob with Azure Container Apps. 
- [java-boot-todo](https://github.com/joergjo/azure-containerapps-demos/tree/main/java-boot-todo): A simple Spring Boot API that uses JPA Data to access PostgreSQL adopted from [Azure' Spring Boot docs](https://docs.microsoft.com/en-us/azure/developer/java/spring-framework/configure-spring-data-jpa-with-azure-postgresql). It demonstrates passwordless access to an Azure Database for PostgreSQL Flexible Server and using structured logging.
