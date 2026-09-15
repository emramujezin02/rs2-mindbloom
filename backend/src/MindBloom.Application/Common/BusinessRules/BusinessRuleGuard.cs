using MindBloom.Application.Common.Exceptions;

namespace MindBloom.Application.Common.BusinessRules;

public static class BusinessRuleGuard
{
    public static void Against(
        bool condition,
        string message)
    {
        if (condition)
        {
            throw new BusinessException(message);
        }
    }

    public static void AgainstNull<T>(
        T? value,
        string message)
        where T : class
    {
        if (value == null)
        {
            throw new BusinessException(message);
        }
    }

    public static void AgainstNotOwned(
        bool isOwner,
        string message =
            "You do not have permission to access this resource.")
    {
        if (!isOwner)
        {
            throw new BusinessException(message);
        }
    }
}