# =========================================================
# RESTORE STAGE
# =========================================================

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS restore

WORKDIR /src

COPY . .

RUN dotnet restore \
    ./src/MindBloom.API/MindBloom.API.csproj


# =========================================================
# BUILD STAGE
# =========================================================

FROM restore AS build

RUN dotnet build \
    ./src/MindBloom.API/MindBloom.API.csproj \
    --configuration Release \
    --no-restore \
    --output /app/build


# =========================================================
# PUBLISH STAGE
# =========================================================

FROM build AS publish

RUN dotnet publish \
    ./src/MindBloom.API/MindBloom.API.csproj \
    --configuration Release \
    --no-build \
    --output /app/publish \
    /p:UseAppHost=false


# =========================================================
# RUNTIME STAGE
# =========================================================

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime

WORKDIR /app

# curl se koristi isključivo za Docker HEALTHCHECK.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=publish /app/publish .

ENV ASPNETCORE_ENVIRONMENT=Production
ENV DOTNET_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:8080

EXPOSE 8080

HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=20s \
    --retries=3 \
CMD curl --fail --silent http://localhost:8080/health/live || exit 1

# .NET Linux images podržavaju ugrađenog non-root korisnika.
USER $APP_UID

ENTRYPOINT ["dotnet", "MindBloom.API.dll"]