# ============================================
# BUILD STAGE
# ============================================

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /src

COPY . .

WORKDIR /src/src/MindBloom.API

RUN dotnet restore

RUN dotnet publish \
    -c Release \
    -o /app/publish \
    /p:UseAppHost=false

# ============================================
# RUNTIME STAGE
# ============================================

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime

WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080

EXPOSE 8080

ENTRYPOINT ["dotnet","MindBloom.API.dll"]