# Azure Container Apps sample: Spring Boot app accessing Azure Database for PostgreSQL passwordless

## About

This application is based on a [sample To Do API from Azure's Spring Boot docs](https://docs.microsoft.com/en-us/azure/developer/java/spring-framework/configure-spring-data-jpa-with-azure-postgresql) and has been enhanced to
- use a [User-assigned Managed Identity](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview) to [access the PostgreSQL database "passwordless"](https://learn.microsoft.com/en-us/azure/developer/java/spring-framework/migrate-postgresql-to-passwordless-connection).
- 🔥 send telemetry to [Datadog](https://docs.datadoghq.com/serverless/azure_container_apps/?code-lang=java)
- use structured JSON logging with [logback](https://logback.qos.ch)
- [seed test data](#spring-boot-profiles)

## Motivation

This sample demonstrates the use of a User-assigned Managed Identity, 
because it solves the otherwise inevitable chickend-and-egg problem&mdash;
the application cannot be deployed unless the database model exists, 
but authorizing the application to access the database requires the application
to exist if a System-assigend Managed identity is used...

There are other "passwordless" samples available in the [Azure Samples repo](https://github.com/Azure-Samples/Passwordless-Connections-for-Java-Apps) 
that also make use of Flexible Server. 


## Prerequisites

The following prerequisites are required to use this application. Please ensure
that you have them all installed locally.

- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- The [PostgreSQL psql](https://www.postgresql.org/docs/current/app-psql.html) client (14.0 or later) and available on your `$PATH`. 
- A bash shell. On macOS/Linux, this is available out of the box. On Windows 10/11, use [WSL 2](https://docs.microsoft.com/en-us/windows/wsl/install) with your preferred Linux distribution (e.g., [Ubuntu 20 LTS](https://apps.microsoft.com/store/detail/ubuntu-20046-lts/9MTTCL66CPXJ)).


## Quickstart

This sample uses the Azure Developer CLI to provision the required Azure services and
to deploy the application.

```bash
# Log in to azd (only required before first use)
azd auth login

# Set a Postgres admin login and password
azd env set POSTGRES_LOGIN todoadmin
azd env set POSTGRES_LOGIN_PASSWORD "$(openssl rand -hex 20)##"

# Set required Datadog parameters
azd env set DD_API_KEY <Datadog API Key>
azd env set DD_ENV <Datadog environment>

# Set Datadog site - if not set, defaults to datadoghq.com
azd env set DD_SITE <Datadog site>

# Provision the Azure services
azd provision

# Build your own application container image and deploy
azd deploy
```

`azd` will prompt you to select an Azure subscription, an environment name (e.g., `todoapi-demo`) and an Azure region when deploying the app for the first time.

Instead of using `azd provision` and `azd deploy`, you can combine
these in one command: `azd up`.

`POSTGRES_LOGIN` and `POSTGRES_LOGIN_PASSWORD` designate a regular, non-Azure AD integrated PostgreSQL admin user. This user is required only at deployment tine, but _not_ used by the application at runtime. 

For more information on the various `DD_*` settings, see [Datadog's documentation](https://docs.datadoghq.com/serverless/azure_container_apps/?code-lang=java#environment-variables).


### Implementation remarks

`azd provision` deploys the Azure Container App with my own [ready-to-use container image from Docker Hub](https://hub.docker.com/repository/docker/joergjo/java-boot-todo/general). The challenge here is that the PostgreSQL database used by application can only be provisioned _after_ `azd provision` has finished, since the Container Apps's mananaged identity must exist before it can be granted access to the database . After running `azd provision` the application will start and fail to access to database while building its connection pool. Hence the application terminates and is restarted according to its startup probe. This 
crash and restart cycle will repeat a number of times. The application will eventually be restarted in a stable state and run properly. Running `azd deploy` gets the application up much faster, though. 

Running `azd provision` multiple times will not reset the Container App to use the aforementioned default image, but it will drop and recreate the database. That was
a conscious decision to keep the database creation logic idempotent.

### Deployed Resources

The Azure Developer CLI will use the included [Bicep templates](./infra/) to create the following Azure resources:
- An [Azure Container App environment](https://docs.microsoft.com/en-us/azure/container-apps/environment).
- An [Azure Container App](https://learn.microsoft.com/en-us/azure/container-apps/overview) for the application.
- A [Log Analytics workspace](https://docs.microsoft.com/en-us/azure/container-apps/monitor?tabs=bash). The application logs to stdout and hence its log will be written to the workspace, but this can be turned off. Note that if you are using Datadog, the logs will be written to both Datadog _and_ Log Analytics by default.
- An [Azure Database for PostgreSQL Flexible Server](https://docs.microsoft.com/en-us/azure/postgresql/flexible-server/overview) that supports Azure AD authentication.
- [A Virtual Network for the Container Apps environment](https://docs.microsoft.com/en-us/azure/container-apps/vnet-custom?tabs=bash&pivots=azure-cli). The Flexible Server is _not_ injected in the virtual network to keep the deployment of the application simple. 
- A [User-assigned Managed Identity](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview) for the application.
- An [Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/) to which your the container images built by running `azd provision` are pushed.

### Datadog support
In case you want to use the sample without Datadog support, either don't set the required Datadog settings or use the included alternate Dockerfile to build an image that does not include Datadog's agent.

To build an image without Datadog support baked in, update the `services.todoapi.docker.path` field in [`azure.yaml`](azure.yaml) as follows:

```yaml
services:
  todoapi:
    project: .
    language: java
    host: containerapp
    docker:
      path: ./Dockerfile
```


## Notes for hacking on the sample

### Building and running the application on your machine

If you wan to hack on the sample, I recommend installing the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) in addition to the Azure Developer CLI.

The application has been set up using the [Spring Boot Initializer](https://start.spring.io) to use JDK 17 and Maven, so follow the usual steps to build a Spring Boot application in your favorite IDE or using the command line. If you are using [Visual Studio Code](https://code.visualstudio.com/), the editor will prompt to install all recommended extensions if you don't have them installed already.

If you run the application locally but still connect to an Azure Database for PostgreSQL, you must provide an alternate identity that the application can use for authenticating
with Azure AD, since there is no managed identity on your PC or Mac.

The simplest solution is to log in to Azure CLI and grant your Azure AD user access to your Azure Database for PostgreSQL Flexible Server. See this [article](https://learn.microsoft.com/en-us/azure/developer/java/spring-framework/authentication) to understand how this works.

### Running the application with Docker Compose

Prebuilt images with and without Datadog support are available on [Docker Hub](https://hub.docker.com/repository/docker/joergjo/java-boot-todo). 

If you want to build your own container image locally, use the included Docker Compose files:

```bash
cd <path-to-project-directory>

# With Datadog supprt
docker compose -f "Dockerfile.dd" build

# Without Datadog support
docker compose build
```

The included Docker Compose files make use of [multi-stage builds](https://docs.docker.com/develop/develop-images/multistage-build/), so they will work on any machine which has Docker installed _without_ needing a local JDK and Maven installation.

The Compose files can also be used to run the application locally:

- `compose.yaml` runs the application locally, but requires a separate PostgreSQL database (e.g., Azure Database or a locally installed PostgreSQL server)
- `compose.all.yaml` runs the application and a PostgreSQL database container. In this case, username and password are used instead of Azure AD.
- `compose.db.yaml` runs a PostgreSQL database container. In this case, username and password are used instead of Azure AD.


### Spring Boot Profiles

The project uses a few Spring Boot profiles to enable or disable certain features:

- `json-logging`: Enables JSON Logging instead of the standard Logback text format.
- `prod`: Disables seeding of test data. The application's database will be empty.
- `local`: Disables passwordless authentication and falls back to username/password authentication. This is useful local development with Docker Compose.
