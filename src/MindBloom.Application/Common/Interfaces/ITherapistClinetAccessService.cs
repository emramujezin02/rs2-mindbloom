namespace MindBloom.Application.Common.Interfaces;

public interface ITherapistClientAccessService
{
    Task<bool> HasRelationshipAsync(
        int therapistUserId,
        int clientId,
        CancellationToken cancellationToken = default);

    Task<bool> HasActiveRelationshipAsync(
        int therapistUserId,
        int clientId,
        CancellationToken cancellationToken = default);

    Task EnsureRelationshipAsync(
        int therapistUserId,
        int clientId,
        CancellationToken cancellationToken = default);

    Task EnsureActiveRelationshipAsync(
        int therapistUserId,
        int clientId,
        CancellationToken cancellationToken = default);
}