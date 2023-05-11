# Azure Container Apps sample: Spring Boot app accessing Azure Database for PostgreSQL passwordless

## About

This application is based on a [sample To Do API from Azure's Spring Boot docs](https://docs.microsoft.com/en-us/azure/developer/java/spring-framework/configure-spring-data-jpa-with-azure-postgresql) and has been enhanced to
- use a [User-assigned Managed Identity](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview) to [access the PostgreSQL database "passwordless"](https://learn.microsoft.com/en-us/azure/developer/java/spring-framework/migrate-postgresql-to-passwordless-connection).
- 🔥 send telemetry to Datadog ([feature still in Beta](https://docs.datadoghq.com/serverless/azure_container_apps/))
- use structured JSON logging with [logback](https://logback.qos.ch)
- [seed test data](#spring-boot-profiles)

## Motivation

At the time of writing, the official Azure documentation for passwordless connections covers the use of Azure Database for PostgreSQL *Single Server*. Setting up Azure AD support for Flexible Server works differently and is currently not detailed in the documentation for an end-to-end scenario. 

This sample also demonstrates how to use a User-assigned Managed Identity, 
because it solves the otherwise inevitable chickend-and-egg problem&mdash;
the application cannot be deployed unless the database model exists, 
but authorizing the application to access the database requires the application
to exist if a System-assigend Managed identity is used...

There are other "passwordless" samples available in the [Azure Samples repo](https://github.com/Azure-Samples/Passwordless-Connections-for-Java-Apps) that also make use of Flexible Server. 


## Prerequisites

- [Azure CLI 2.0](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (**v2.43** or newer)
- Azure Container App extension for Azure CLI

  ```bash
  az extension add --name containerapp --upgrade  
  ```
- Bicep extension for Azure CLI
  ```bash
  az bicep upgrade
  ``` 
- A bash shell. On Windows 10/11, [WSL 2](https://docs.microsoft.com/en-us/windows/wsl/install) provides you the best experience.
- The [PostgreSQL psql](https://www.postgresql.org/docs/current/app-psql.html) client (14.0 or later)


## [Deploy to an Azure Container App](#deploy-to-azure)

The bash script [`deploy.sh`](deploy/deploy.sh) allows you to deploy the application as an Azure Container App with all required dependencies.
Before running the script, you must export the following environment variables:

| Environment variable              | Purpose                               | Default value        |
| --------------------------------- | ------------------------------------- | -------------------- |
| `CONTAINERAPP_RESOURCE_GROUP`     | Resource group to deploy to           | none                 |
| `CONTAINERAPP_POSTGRES_LOGIN`     | PostgreSQL admin user login           | none                 |
| `CONTAINERAPP_POSTGRES_LOGIN_PWD` | PostgreSQL admin user password        | none                 |
| `CONTAINERAPP_DD_API_KEY`         | Datadog API Key                       | none                 |
| `CONTAINERAPP_DD_APPLICATION_KEY` | Datadog Application Key               | none                 |

> `CONTAINERAPP_POSTGRES_LOGIN` and `CONTAINERAPP_POSTGRES_LOGIN_PWD` designate a regular,
> non-Azure AD integrated PostgreSQL admin user. This user is currently required for deployment, but
> _not_ used afterwards. 

Depending on whether you have exported `CONTAINERAPP_DD_API_KEY`, the script will either deploy
the app with or without Datadog support.

Next, execute `deploy.sh`:

```bash
cd <path-to-project-directory>/deploy
export CONTAINERAPP_RESOURCE_GROUP=todoapi-passwordless
export CONTAINERAPP_POSTGRES_LOGIN=flexadmin
# Add non-letter characters to satisfy password strength requirement 
export CONTAINERAPP_POSTGRES_LOGIN_PWD="$(openssl rand -hex 20)##"
# Export to enable Datadog support
# export CONTAINERAPP_DD_API_KEY=<your-dd-api-key>
# export CONTAINERAPP_DD_APPLICATION_KEY=<your-dd-application-key>
./deploy.sh
```

The script sets the Azure AD user that is currently logged in to Azure CLI as database owner. 
This allows you to run the application locally without any modifications, since the Azure AD plugin in PostgreSQL will
[probe for a way to log in to Azure if no managed identity is available](https://learn.microsoft.com/en-us/java/api/overview/azure/identity-readme?view=azure-java-stable#authenticate-a-user-assigned-managed-identity-with-defaultazurecredential).    

## Deployment Options

You can control additional deployment details (e.g., the Azure region to deploy to) by exporting the following environment variables:

| Environment variable              | Purpose                               | Default value                   |
| --------------------------------- | ------------------------------------- | ------------------------------- |
| `CONTAINERAPP_LOCATION`           | Azure region to deploy to             | `westeurope`                    |
| `CONTAINERAPP_NAME`               | Name of the Azure Container App       | `todoapi`                       |
| `CONTAINERAPP_IMAGE`              | Application container image           | `joergjo/java-boot-todo:latest` or `joergjo/java-boot-todo:dd-latest`  |
| `CONTAINERAPP_POSTGRES_DB`        | Database name used by the application |  `demo`                         |


## Deployed Resources

The Bicep templates create the following Azure resources:
- An [Azure Container App environment](https://docs.microsoft.com/en-us/azure/container-apps/environment).
- An [Azure Container App](https://learn.microsoft.com/en-us/azure/container-apps/overview) for the application.
- A [Log Analytics workspace](https://docs.microsoft.com/en-us/azure/container-apps/monitor?tabs=bash). Container Apps environments require this. The application logs to stdout and hence its log will be written to the workspace, but this can be turned off. Note that if you enable Datadog support, the logs will be written to both Datadog _and_ Log Analytics.
- An [Azure Database for PostgreSQL Flexible Server](https://docs.microsoft.com/en-us/azure/postgresql/flexible-server/overview) that supports Azure AD authenticatiob. This is required by the application.
- [A Virtual Network for the Container Apps environment](https://docs.microsoft.com/en-us/azure/container-apps/vnet-custom?tabs=bash&pivots=azure-cli). Since the deployment script requires access to the PostgreSQL server, the Flexible Server is _not_ injected in the virtual network. 
- A [User-assigned Managed Identity](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview) for the application.


## Building the application (optional)

### Building the application on your machine

Building the application yourself is only required if you want to change it or its configuration (e.g., replace PostgreSQL with MySQL).

The application has been set up using the [Spring Boot Initializer](https://start.spring.io) to use JDK 17 and Maven, so follow the usual steps to build a Spring Boot application in your favorite IDE or using the command line. If you are using [Visual Studio Code](https://code.visualstudio.com/), the editor will prompt to install all recommended extensions if you don't have them installed already.

As mentioned before, if you run the application locally but connect to Azure Database, you must provide an alternate identity that the application can use to log in to Azure AD since there is no managed identity on your PC or Mac.

The simplest option is to log in to Azure CLI and grant your user access to the Flexible Server. If you have set up the Flexible Server with the included deployment script, this will be the case. See this [article](https://learn.microsoft.com/en-us/azure/developer/java/spring-framework/authentication) to understand how this works.

### Building the application's container image

Prebuilt images with and without Datadog support are available on [Docker Hub](https://hub.docker.com/repository/docker/joergjo/java-boot-todo). These container images are used when you deploy the application with the included [deployment script](deploy/deploy.sh).

If you want to build your own container image, use the included Docker Compose files:

```bash
$ cd <path-to-project-directory>
$ docker compose build
$ docker tag java-boot-todo <your-registry>/java-boot-todo:<your-tag>
$ docker push <your-registry>/java-boot-todo:<your-tag>
```

> If you are using an older version of Docker, you may have to use `docker-compose build` (note the dash).

The included Compose files make use of [multi-stage builds](https://docs.docker.com/develop/develop-images/multistage-build/), so they will work on any machine which has Docker installed _without_ needing a local JDK and Maven installation.

The Compose files can also be used to run the application locally:

- `compose.yaml` runs the application locally, but requires a separate PostgreSQL database (e.g., Azure Database or a locally installed PostgreSQL server)
- `compose.all.yaml` runs the application and a PostgreSQL database container. In this case, username and password are used instead of Azure AD.

### Datadog support

Datadog support is provided by through a separate Dockerfile. By default, the Composes file will build the application
without Datadog support. To build a container image with Datadog support, export `DOCKERFILE` as follows:

```bash
cd <path-to-project-directory>
export DOCKERFILE=Dockerfile.dd.buildkit
```

Instead of exporting an environment variable, you can create an `.env` file in the repo's root directory. Docker Compose will evaluate the content of this file by default.

```bash
cd <path-to-project-directory>
echo "DOCKERFILE=Dockerfile.dd.buildkit" > .env
```

The [Dockerfile](Dockerfile.dd.buildkit) sets the following Datadog specific environment variables
```Dockerfile
ENV DD_SERVICE=java-boot-todo
ENV DD_ENV=dev
ENV DD_VERSION=1.0.0
ENV DD_PROFILING_ENABLED=true
ENV DD_LOGS_ENABLED=true 
```

If you want to override them or set additional Datadog specific settings, add them in the application's [Bicep file](deploy/modules/app.bicep) directly.

## Spring Boot Profiles

`json-logging`: Enables JSON Logging instead of the standard Logback text format.

`prod`: Disables seeding of test data. All other profiles will seed test data.

`local`: Disables passwordless authentication and falls back to username/password. Useful for local development.
