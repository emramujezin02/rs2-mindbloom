namespace MindBloom.API.Security;

public static class AdminAuditRequestResolver
{
    public static bool ShouldAudit(
        HttpContext context)
    {
        if (context.User.Identity
                ?.IsAuthenticated != true)
        {
            return false;
        }

        if (!context.User.IsInRole(
                "Admin"))
        {
            return false;
        }

        if (!context.Request.Path
                .StartsWithSegments(
                    "/api/Admin",
                    StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        if (HttpMethods.IsGet(
                context.Request.Method) ||
            HttpMethods.IsHead(
                context.Request.Method) ||
            HttpMethods.IsOptions(
                context.Request.Method))
        {
            return false;
        }

        return true;
    }

    public static string ResolveAction(
        HttpContext context)
    {
        var method =
            context.Request.Method
                .ToUpperInvariant();

        var path =
            context.Request.Path.Value
                ?.Trim('/')
                .ToLowerInvariant()
            ?? string.Empty;

        if (path.EndsWith(
                "/status",
                StringComparison.Ordinal))
        {
            return "StatusChanged";
        }

        if (path.EndsWith(
                "/verification",
                StringComparison.Ordinal))
        {
            return "VerificationChanged";
        }

        if (path.EndsWith(
                "/approve",
                StringComparison.Ordinal))
        {
            return "Approved";
        }

        if (path.EndsWith(
                "/reject",
                StringComparison.Ordinal))
        {
            return "Rejected";
        }

        if (path.EndsWith(
                "/hide",
                StringComparison.Ordinal))
        {
            return "Hidden";
        }

        if (path.EndsWith(
                "/cancel",
                StringComparison.Ordinal))
        {
            return "Cancelled";
        }

        if (path.EndsWith(
                "/refund",
                StringComparison.Ordinal))
        {
            return "RefundRequested";
        }

        if (path.EndsWith(
                "/send-password-reset",
                StringComparison.Ordinal))
        {
            return "PasswordResetRequested";
        }

        if (path.EndsWith(
                "/delete",
                StringComparison.Ordinal))
        {
            return "Deleted";
        }

        return method switch
        {
            "POST" => "Created",
            "PUT" => "Updated",
            "PATCH" => "Updated",
            "DELETE" => "Deleted",
            _ => method
        };
    }

    public static string ResolveEntityType(
        HttpContext context)
    {
        var segments =
            context.Request.Path.Value
                ?.Split(
                    '/',
                    StringSplitOptions
                        .RemoveEmptyEntries)
            ?? [];

        if (segments.Length < 3)
        {
            return "Admin";
        }

        var resource =
            segments[2]
                .Trim()
                .ToLowerInvariant();

        return resource switch
        {
            "users" => "User",
            "therapists" => "Therapist",
            "reviews" => "Review",
            "appointments" => "Appointment",
            "payments" => "Payment",
            "memberships" => "Membership",
            "membership-plans" =>
                "MembershipPlan",
            _ => ToPascalCase(resource)
        };
    }

    public static string?
        ResolveEntityId(
            HttpContext context)
    {
        var routeValues =
            context.Request.RouteValues;

        var preferredKeys =
            new[]
            {
                "userId",
                "therapistId",
                "reviewId",
                "appointmentId",
                "paymentId",
                "membershipId",
                "planId",
                "id"
            };

        foreach (var key
                 in preferredKeys)
        {
            if (routeValues.TryGetValue(
                    key,
                    out var value) &&
                value != null)
            {
                return value.ToString();
            }
        }

        return null;
    }

    private static string ToPascalCase(
        string value)
    {
        var parts =
            value.Split(
                '-',
                StringSplitOptions
                    .RemoveEmptyEntries);

        return string.Concat(
            parts.Select(part =>
                part.Length == 0
                    ? string.Empty
                    : char.ToUpperInvariant(
                          part[0])
                      + part[1..]));
    }
}