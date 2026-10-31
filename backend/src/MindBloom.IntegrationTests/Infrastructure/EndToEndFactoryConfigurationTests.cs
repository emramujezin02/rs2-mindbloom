using MindBloom.IntegrationTests.EndToEnd.Infrastructure;

namespace MindBloom.IntegrationTests.Infrastructure;

[CollectionDefinition("E2E server configuration", DisableParallelization = true)]
public sealed class EndToEndFactoryConfigurationCollection { }

[Collection("E2E server configuration")]
public sealed class EndToEndFactoryConfigurationTests
{
    [Fact]
    public void GuiRunner_KeepsFixtureConstructorCompatibleAndRejectsNonApiRoot()
    {
        Assert.Single(typeof(MindBloomEndToEndTestFactory).GetConstructors());
        Assert.Throws<ArgumentException>(() => MindBloomEndToEndTestFactory.ForGuiRunner(Path.GetTempPath()));
    }

    [Theory]
    [InlineData("220075")]
    [InlineData("UnrelatedApplication")]
    [InlineData("")]
    [InlineData("model")]
    [InlineData("msdb")]
    [InlineData("tempdb")]
    public async Task ExternalServer_RejectsApplicationOrUnspecifiedCatalogBeforeConnecting(string catalog)
    {
        const string setting = "MINDBLOOM_E2E_SQL_SERVER_CONNECTION";
        var previous = Environment.GetEnvironmentVariable(setting);
        Environment.SetEnvironmentVariable(setting,
            $"Server=localhost;Database={catalog};Integrated Security=True;");
        var factory = new MindBloomEndToEndTestFactory();
        try
        {
            var error = await Assert.ThrowsAsync<InvalidOperationException>(factory.InitializeAsync);
            Assert.Contains("must target master", error.Message);
        }
        finally
        {
            await factory.DisposeAsync();
            Environment.SetEnvironmentVariable(setting, previous);
        }
    }

    [Fact]
    public async Task ExternalServer_RejectsAttachedDatabaseBeforeConnecting()
    {
        const string setting = "MINDBLOOM_E2E_SQL_SERVER_CONNECTION";
        var previous = Environment.GetEnvironmentVariable(setting);
        Environment.SetEnvironmentVariable(setting,
            @"Server=localhost;Database=master;AttachDbFilename=C:\data\220075.mdf;Integrated Security=True;");
        var factory = new MindBloomEndToEndTestFactory();
        try
        {
            var error = await Assert.ThrowsAsync<InvalidOperationException>(factory.InitializeAsync);
            Assert.Contains("without an attached database file", error.Message);
        }
        finally
        {
            await factory.DisposeAsync();
            Environment.SetEnvironmentVariable(setting, previous);
        }
    }
}
