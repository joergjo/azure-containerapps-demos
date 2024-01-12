FROM mcr.microsoft.com/dotnet/runtime:8.0-alpine AS base
WORKDIR /app

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
ARG TARGETARCH
WORKDIR /src
COPY ["./QueueWorker.csproj", "."]
RUN dotnet restore -a $TARGETARCH
COPY [".", "."]
RUN dotnet publish -a $TARGETARCH --no-restore -o /app/publish /p:UseAppHost=false

FROM base AS final
ENV \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8
RUN apk add --no-cache \
    icu-data-full \
    icu-libs
USER $APP_UID
WORKDIR /app
COPY --from=build ["/app/publish", "."]
ENTRYPOINT ["dotnet", "QueueWorker.dll"]