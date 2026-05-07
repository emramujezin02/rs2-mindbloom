using DotNetEnv;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

Env.Load("../../.env");

IHost host = Host.CreateDefaultBuilder(args)
    .ConfigureServices((context, services) =>
    {

    })
    .Build();

await host.RunAsync();