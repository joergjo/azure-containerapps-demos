# azure-containerapps-demos

## A collection of demo applications to try out [Azure Container Apps](https://azure.microsoft.com/en-us/services/container-apps/)

- [dotnet-queueworker](https://github.com/joergjo/azure-containerapps-demos/tree/main/dotnet-queueworker): A .NET 6 worker service that reads messages from Azure Storage Queues using [Dapr](http://dapr.io).
- [go-helloworld-v1](https://github.com/joergjo/azure-containerapps-demos/tree/main/go-helloworld-v1) and [go-helloworld-v2](https://github.com/joergjo/azure-containerapps-demos/tree/main/go-helloworld-v2): 
Go "Hello World" API that can be used as quick start and to test [revisions](https://docs.microsoft.com/en-us/azure/container-apps/revisions).
- [java-boot-todo](https://github.com/joergjo/azure-containerapps-demos/tree/main/java-boot-todo): A simple Spring Boot API that uses JPA Data to access PostgreSQL adopted from [Azure' Spring Boot docs]
(https://docs.microsoft.com/en-us/azure/developer/java/spring-framework/configure-spring-data-jpa-with-azure-postgresql). This shows how to use structured logging with JSON.
- [java-boot-todo-dd](https://github.com/joergjo/azure-containerapps-demos/tree/main/java-boot-todo-dd): The same application as [java-boot-todo](https://github.com/joergjo/azure-containerapps-demos/tree/main/java-boot-todo),
but with [Datadog](https://www.datadoghq.com) support. Note that this is *experimental* at best and in no way a supported solution! 
