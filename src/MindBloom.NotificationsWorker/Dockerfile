# =========================================================
# RESTORE STAGE
# =========================================================

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS restore

WORKDIR /src

COPY . .

RUN dotnet restore \
    ./src/MindBloom.NotificationsWorker/MindBloom.Worker.csproj


# =========================================================
# BUILD STAGE
# =========================================================

FROM restore AS build

RUN dotnet build \
    ./src/MindBloom.NotificationsWorker/MindBloom.Worker.csproj \
    --configuration Release \
    --no-restore \
    --output /app/build


# =========================================================
# PUBLISH STAGE
# =========================================================

FROM build AS publish

RUN dotnet publish \
    ./src/MindBloom.NotificationsWorker/MindBloom.Worker.csproj \
    --configuration Release \
    --no-build \
    --output /app/publish \
    /p:UseAppHost=false


# =========================================================
# RUNTIME STAGE
# =========================================================

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=publish /app/publish .

ENV DOTNET_ENVIRONMENT=Production
ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:8080

EXPOSE 8080

HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=30s \
    --retries=3 \
    CMD curl --fail --silent http://localhost:8080/health || exit 1

USER $APP_UID

ENTRYPOINT ["dotnet", "MindBloom.Worker.dll"]