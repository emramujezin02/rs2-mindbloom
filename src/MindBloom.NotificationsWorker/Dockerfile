# ============================================
# BUILD STAGE
# ============================================

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /src

COPY . .

WORKDIR /src/src/MindBloom.NotificationsWorker

RUN dotnet restore

RUN dotnet publish \
    -c Release \
    -o /app/publish \
    /p:UseAppHost=false


# ============================================
# RUNTIME STAGE
# ============================================

FROM mcr.microsoft.com/dotnet/runtime:8.0 AS runtime

WORKDIR /app

COPY --from=build /app/publish .

ENV DOTNET_ENVIRONMENT=Production

ENTRYPOINT ["dotnet", "MindBloom.NotificationsWorker.dll"]