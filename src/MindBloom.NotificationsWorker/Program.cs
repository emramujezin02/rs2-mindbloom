

IHost host = Host.CreateDefaultBuilder(args)
    .ConfigureServices(services =>
    {
    })
    .Build();

await host.RunAsync();