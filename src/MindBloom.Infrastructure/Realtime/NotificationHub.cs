using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using System.Security.Claims;

namespace MindBloom.Infrastructure.Realtime;

//[Authorize]
public class NotificationHub : Hub
{
    public override async Task OnConnectedAsync()
    {
        var userId =
             Context.User?
                 .FindFirst(ClaimTypes.NameIdentifier)?
                 .Value;

        Console.WriteLine($"CONNECTED USER: {userId}");

        if (!string.IsNullOrEmpty(userId))
        {
            await Groups.AddToGroupAsync(
                Context.ConnectionId,
                $"user-{userId}");

            Console.WriteLine($"ADDED TO GROUP user-{userId}");
        }

        await base.OnConnectedAsync();


    }
}

