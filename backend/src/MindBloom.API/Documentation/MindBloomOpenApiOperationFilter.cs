using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.ApiExplorer;
using Microsoft.OpenApi.Models;
using MindBloom.API.Models;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Articles.DTOs;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Workshops.DTOs;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace MindBloom.API.Documentation;

public sealed class MindBloomOpenApiOperationFilter
    : IOperationFilter
{
    private const string BearerSchemeName = "Bearer";

    private static readonly IReadOnlyDictionary<string, EndpointDoc>
        EndpointDocs =
            new Dictionary<string, EndpointDoc>(
                StringComparer.Ordinal)
            {
                ["Payments.CreateIntent"] =
                    new(
                        "Create payment intent",
                        "Creates a Stripe payment intent for an appointment payment.",
                        StatusCodes.Status200OK,
                        typeof(PaymentIntentResponseDto),
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Payments.Confirm"] =
                    new(
                        "Confirm payment",
                        "Confirms an appointment payment after Stripe confirmation.",
                        StatusCodes.Status204NoContent,
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Payments.GetMyPayments"] =
                    new(
                        "Get my payments",
                        "Returns payment history for the authenticated client.",
                        StatusCodes.Status200OK,
                        typeof(List<PaymentHistoryDto>)),

                ["Payments.GetReceipt"] =
                    new(
                        "Get payment receipt",
                        "Returns a receipt for an appointment payment owned by the authenticated client.",
                        StatusCodes.Status200OK,
                        typeof(PaymentReceiptDto),
                        CanReturnNotFound: true),

                ["Membership.GetPlansForTherapist"] =
                    new(
                        "Get therapist membership plans",
                        "Returns membership plans offered by a therapist.",
                        StatusCodes.Status200OK,
                        typeof(List<MembershipPlanDto>),
                        CanReturnNotFound: true),

                ["Membership.CreatePaymentIntent"] =
                    new(
                        "Create membership payment intent",
                        "Creates a Stripe payment intent for a client membership purchase.",
                        StatusCodes.Status200OK,
                        typeof(MembershipPaymentIntentResponseDto),
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Membership.ConfirmPayment"] =
                    new(
                        "Confirm membership payment",
                        "Confirms a membership payment and returns the purchased membership.",
                        StatusCodes.Status200OK,
                        typeof(MembershipResponseDto),
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Membership.GetMyMemberships"] =
                    new(
                        "Get my memberships",
                        "Returns memberships owned by the authenticated client.",
                        StatusCodes.Status200OK,
                        typeof(List<MembershipResponseDto>)),

                ["Membership.GetReceipt"] =
                    new(
                        "Get membership receipt",
                        "Returns a receipt for a membership payment owned by the authenticated client.",
                        StatusCodes.Status200OK,
                        typeof(MembershipReceiptDto),
                        CanReturnNotFound: true),

                ["Membership.UseMembership"] =
                    new(
                        "Use membership session",
                        "Consumes a membership session for the authenticated client.",
                        StatusCodes.Status204NoContent,
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Appointments.Create"] =
                    new(
                        "Create appointment",
                        "Books an appointment for the authenticated client.",
                        StatusCodes.Status200OK,
                        typeof(AppointmentResponseDto),
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Appointments.Mine"] =
                    new(
                        "Get my appointments",
                        "Returns appointments for the authenticated client.",
                        StatusCodes.Status200OK,
                        typeof(List<AppointmentResponseDto>)),

                ["Appointments.GetClientAppointmentDetails"] =
                    new(
                        "Get appointment details",
                        "Returns appointment details for the authenticated client.",
                        StatusCodes.Status200OK,
                        typeof(AppointmentResponseDto),
                        CanReturnNotFound: true),

                ["Appointments.GetTherapistAppointments"] =
                    new(
                        "Get therapist appointments",
                        "Returns appointments assigned to the authenticated therapist.",
                        StatusCodes.Status200OK,
                        typeof(List<AppointmentResponseDto>)),

                ["Appointments.UpdateStatus"] =
                    new(
                        "Update appointment status",
                        "Updates appointment status as the authenticated therapist.",
                        StatusCodes.Status204NoContent,
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Appointments.CancelAppointment"] =
                    new(
                        "Cancel appointment",
                        "Cancels an appointment owned by the authenticated client.",
                        StatusCodes.Status204NoContent,
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Appointments.GetTherapistStats"] =
                    new(
                        "Get therapist appointment stats",
                        "Returns appointment statistics for the authenticated therapist.",
                        StatusCodes.Status200OK,
                        typeof(TherapistStatsDto)),

                ["Appointments.AddAppointmentNote"] =
                    new(
                        "Add appointment note",
                        "Adds or updates a therapist note for an appointment.",
                        StatusCodes.Status200OK,
                        HasRequestValidation: true,
                        CanReturnNotFound: true),

                ["Appointments.GetAppointmentNote"] =
                    new(
                        "Get appointment note",
                        "Returns the therapist note for an appointment when one exists.",
                        StatusCodes.Status200OK,
                        typeof(AppointmentNoteResponseDto)),

                ["Appointments.GetClientDashboard"] =
                    new(
                        "Get client appointment dashboard",
                        "Returns appointment dashboard data for the authenticated client.",
                        StatusCodes.Status200OK,
                        typeof(ClientDashboardDto)),

                ["Appointments.UpdateMeetingLink"] =
                    new(
                        "Update appointment meeting link",
                        "Updates the meeting link for an appointment assigned to the authenticated therapist.",
                        StatusCodes.Status204NoContent,
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Appointments.GetOccupiedSlots"] =
                    new(
                        "Get occupied appointment slots",
                        "Returns occupied appointment slots for a therapist and date.",
                        StatusCodes.Status200OK,
                        typeof(List<OccupiedAppointmentSlotDto>)),

                ["Articles.GetPublic"] =
                    new(
                        "Get public articles",
                        "Returns published articles for public browsing.",
                        StatusCodes.Status200OK,
                        typeof(PagedResponse<ArticleResponseDto>)),

                ["Articles.GetById"] =
                    new(
                        "Get article details",
                        "Returns a published article by identifier.",
                        StatusCodes.Status200OK,
                        typeof(ArticleResponseDto),
                        CanReturnNotFound: true),

                ["Articles.GetManagement"] =
                    new(
                        "Get article management list",
                        "Returns articles for administrator management.",
                        StatusCodes.Status200OK,
                        typeof(PagedResponse<ArticleResponseDto>)),

                ["Articles.GetManagementById"] =
                    new(
                        "Get article management details",
                        "Returns article details for administrator management.",
                        StatusCodes.Status200OK,
                        typeof(ArticleResponseDto),
                        CanReturnNotFound: true),

                ["Articles.Create"] =
                    new(
                        "Create article",
                        "Creates an article as an administrator or therapist.",
                        StatusCodes.Status200OK,
                        typeof(ArticleResponseDto),
                        HasRequestValidation: true,
                        CanReturnConflict: true),

                ["Articles.Update"] =
                    new(
                        "Update article",
                        "Updates an existing article as an administrator or therapist.",
                        StatusCodes.Status200OK,
                        typeof(ArticleResponseDto),
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Articles.UpdatePublication"] =
                    new(
                        "Update article publication",
                        "Updates publication status for an existing article.",
                        StatusCodes.Status200OK,
                        typeof(ArticleResponseDto),
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Articles.Delete"] =
                    new(
                        "Delete article",
                        "Deletes an existing article.",
                        StatusCodes.Status200OK,
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Articles.GetCategories"] =
                    new(
                        "Get article categories",
                        "Returns active article categories.",
                        StatusCodes.Status200OK,
                        typeof(List<ArticleCategoryResponseDto>)),

                ["Articles.UploadImage"] =
                    new(
                        "Upload article image",
                        "Uploads an image for article content.",
                        StatusCodes.Status200OK,
                        typeof(ArticleImageUploadDto),
                        HasRequestValidation: true),

                ["Therapists.Create"] =
                    new(
                        "Create therapist profile",
                        "Creates a therapist profile for the authenticated therapist.",
                        StatusCodes.Status201Created,
                        typeof(TherapistResponseDto),
                        HasRequestValidation: true,
                        CanReturnConflict: true),

                ["Therapists.GetAll"] =
                    new(
                        "Get therapists",
                        "Returns available therapists.",
                        StatusCodes.Status200OK,
                        typeof(List<TherapistResponseDto>)),

                ["Therapists.AddAvailability"] =
                    new(
                        "Add therapist availability",
                        "Adds availability for the authenticated therapist.",
                        StatusCodes.Status204NoContent,
                        HasRequestValidation: true,
                        CanReturnConflict: true),

                ["Therapists.GetAvailabilities"] =
                    new(
                        "Get therapist availability",
                        "Returns availability entries for a therapist.",
                        StatusCodes.Status200OK,
                        typeof(List<AvailabilityResponseDto>)),

                ["Therapists.Search"] =
                    new(
                        "Search therapists",
                        "Searches therapists using query filters.",
                        StatusCodes.Status200OK,
                        typeof(PagedResponse<TherapistResponseDto>)),

                ["Therapists.Filter"] =
                    new(
                        "Filter therapists",
                        "Filters therapists using structured criteria.",
                        StatusCodes.Status200OK,
                        typeof(List<TherapistResponseDto>),
                        HasRequestValidation: true),

                ["Therapists.GetById"] =
                    new(
                        "Get therapist details",
                        "Returns public therapist details by identifier.",
                        StatusCodes.Status200OK,
                        typeof(TherapistDetailsDto),
                        CanReturnNotFound: true),

                ["Therapists.DeleteAvailability"] =
                    new(
                        "Delete therapist availability",
                        "Deletes an availability entry owned by the authenticated therapist.",
                        StatusCodes.Status204NoContent,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Therapists.GetDashboard"] =
                    new(
                        "Get therapist dashboard",
                        "Returns dashboard data for the authenticated therapist.",
                        StatusCodes.Status200OK,
                        typeof(TherapistDashboardDto)),

                ["Therapists.AddUnavailableDate"] =
                    new(
                        "Add unavailable date",
                        "Adds an unavailable date for the authenticated therapist.",
                        StatusCodes.Status204NoContent,
                        HasRequestValidation: true,
                        CanReturnConflict: true),

                ["Therapists.GetUnavailableDates"] =
                    new(
                        "Get therapist unavailable dates",
                        "Returns unavailable dates for a therapist.",
                        StatusCodes.Status200OK,
                        typeof(List<UnavailableDateResponseDto>)),

                ["Therapists.DeleteUnavailableDate"] =
                    new(
                        "Delete unavailable date",
                        "Deletes an unavailable date owned by the authenticated therapist.",
                        StatusCodes.Status204NoContent,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Therapists.GetDocuments"] =
                    new(
                        "Get therapist documents",
                        "Returns uploaded verification documents for a therapist.",
                        StatusCodes.Status200OK,
                        typeof(List<TherapistDocumentResponseDto>),
                        CanReturnNotFound: true),

                ["Therapists.DeleteDocument"] =
                    new(
                        "Delete therapist document",
                        "Deletes a document uploaded by the authenticated therapist.",
                        StatusCodes.Status204NoContent,
                        CanReturnNotFound: true),

                ["Therapists.GetClients"] =
                    new(
                        "Get therapist clients",
                        "Returns clients assigned to the authenticated therapist.",
                        StatusCodes.Status200OK,
                        typeof(List<TherapistClientListDto>)),

                ["Therapists.GetClientDetails"] =
                    new(
                        "Get therapist client details",
                        "Returns client details visible to the authenticated therapist.",
                        StatusCodes.Status200OK,
                        typeof(TherapistClientDetailsDto),
                        CanReturnNotFound: true),

                ["Therapists.GetProfile"] =
                    new(
                        "Get therapist profile",
                        "Returns the profile for the authenticated therapist.",
                        StatusCodes.Status200OK,
                        typeof(TherapistProfileDto),
                        CanReturnNotFound: true),

                ["Therapists.UpdateProfile"] =
                    new(
                        "Update therapist profile",
                        "Updates the profile for the authenticated therapist.",
                        StatusCodes.Status204NoContent,
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Therapists.UploadProfileImage"] =
                    new(
                        "Upload therapist profile image",
                        "Uploads a profile image for the authenticated therapist.",
                        StatusCodes.Status200OK,
                        typeof(TherapistProfileImageDto),
                        HasRequestValidation: true),

                ["Therapists.DeleteProfileImage"] =
                    new(
                        "Delete therapist profile image",
                        "Deletes the profile image for the authenticated therapist.",
                        StatusCodes.Status204NoContent,
                        CanReturnNotFound: true),

                ["Workshops.GetPublic"] =
                    new(
                        "Get public workshops",
                        "Returns public workshop listings.",
                        StatusCodes.Status200OK,
                        typeof(PagedResponse<WorkshopResponseDto>)),

                ["Workshops.GetById"] =
                    new(
                        "Get workshop details",
                        "Returns public details for a workshop.",
                        StatusCodes.Status200OK,
                        typeof(WorkshopResponseDto),
                        CanReturnNotFound: true),

                ["Workshops.GetManageList"] =
                    new(
                        "Get workshop management list",
                        "Returns workshops for administrator or therapist management.",
                        StatusCodes.Status200OK,
                        typeof(PagedResponse<WorkshopResponseDto>)),

                ["Workshops.GetRegistrations"] =
                    new(
                        "Get workshop registrations",
                        "Returns registrations for a managed workshop.",
                        StatusCodes.Status200OK,
                        typeof(PagedResponse<WorkshopRegistrationResponseDto>),
                        CanReturnNotFound: true),

                ["Workshops.Create"] =
                    new(
                        "Create workshop",
                        "Creates a workshop as an administrator or therapist.",
                        StatusCodes.Status200OK,
                        typeof(WorkshopResponseDto),
                        HasRequestValidation: true,
                        CanReturnConflict: true),

                ["Workshops.Update"] =
                    new(
                        "Update workshop",
                        "Updates an existing workshop.",
                        StatusCodes.Status200OK,
                        typeof(WorkshopResponseDto),
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Workshops.UpdateStatus"] =
                    new(
                        "Update workshop status",
                        "Updates the status of an existing workshop.",
                        StatusCodes.Status200OK,
                        typeof(WorkshopResponseDto),
                        HasRequestValidation: true,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Workshops.Delete"] =
                    new(
                        "Delete workshop",
                        "Deletes an existing workshop.",
                        StatusCodes.Status200OK,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Workshops.Register"] =
                    new(
                        "Register for workshop",
                        "Registers the authenticated client for a workshop.",
                        StatusCodes.Status200OK,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Workshops.CancelRegistration"] =
                    new(
                        "Cancel workshop registration",
                        "Cancels the authenticated client's workshop registration.",
                        StatusCodes.Status200OK,
                        CanReturnNotFound: true,
                        CanReturnConflict: true),

                ["Workshops.GetMyRegistrations"] =
                    new(
                        "Get my workshop registrations",
                        "Returns workshop registrations for the authenticated client.",
                        StatusCodes.Status200OK,
                        typeof(PagedResponse<WorkshopResponseDto>)),

                ["Workshops.UploadImage"] =
                    new(
                        "Upload workshop image",
                        "Uploads an image for workshop content.",
                        StatusCodes.Status200OK,
                        typeof(WorkshopImageUploadDto),
                        HasRequestValidation: true)
            };

    public void Apply(
        OpenApiOperation operation,
        OperationFilterContext context)
    {
        var apiDescription =
            context.ApiDescription;

        var controller =
            GetRouteValue(
                apiDescription,
                "controller");

        var action =
            GetRouteValue(
                apiDescription,
                "action");

        var docKey =
            $"{controller}.{action}";

        EndpointDocs.TryGetValue(
            docKey,
            out var doc);

        operation.Summary =
            doc?.Summary ??
            CreateSummary(
                action,
                controller);

        operation.Description =
            CreateDescription(
                apiDescription,
                doc);

        var allowAnonymous =
            AllowsAnonymous(apiDescription);

        var authorizeData =
            GetAuthorizeData(apiDescription);

        if (allowAnonymous)
        {
            operation.Security =
                new List<OpenApiSecurityRequirement>();
        }
        else if (authorizeData.Length > 0)
        {
            EnsureBearerSecurityRequirement(operation);
            AddErrorResponse(
                operation,
                context,
                StatusCodes.Status401Unauthorized,
                "Unauthorized");

            if (HasRestrictiveAuthorization(authorizeData))
            {
                AddErrorResponse(
                    operation,
                    context,
                    StatusCodes.Status403Forbidden,
                    "Forbidden");
            }
        }

        if (doc is not null)
        {
            AddSuccessResponse(
                operation,
                context,
                doc);

            if (doc.HasRequestValidation ||
                IsUnsafeHttpMethod(apiDescription.HttpMethod))
            {
                AddErrorResponse(
                    operation,
                    context,
                    StatusCodes.Status400BadRequest,
                    "Bad Request");
            }

            if (doc.CanReturnNotFound)
            {
                AddErrorResponse(
                    operation,
                    context,
                    StatusCodes.Status404NotFound,
                    "Not Found");
            }

            if (doc.CanReturnConflict)
            {
                AddErrorResponse(
                    operation,
                    context,
                    StatusCodes.Status409Conflict,
                    "Conflict");
            }
        }
        else if (IsUnsafeHttpMethod(apiDescription.HttpMethod))
        {
            AddErrorResponse(
                operation,
                context,
                StatusCodes.Status400BadRequest,
                "Bad Request");
        }

        NormalizeResponseDescriptions(operation);
    }

    private static string GetRouteValue(
        ApiDescription apiDescription,
        string key)
    {
        return apiDescription
                   .ActionDescriptor
                   .RouteValues
                   .TryGetValue(
                       key,
                       out var value)
               && !string.IsNullOrWhiteSpace(value)
            ? value
            : "Endpoint";
    }

    private static string CreateSummary(
        string action,
        string controller)
    {
        var words =
            SplitPascalCase(action);

        if (!string.IsNullOrWhiteSpace(words))
        {
            return words;
        }

        return $"Use {controller} endpoint";
    }

    private static string CreateDescription(
        ApiDescription apiDescription,
        EndpointDoc? doc)
    {
        var parts =
            new List<string>();

        if (!string.IsNullOrWhiteSpace(doc?.Description))
        {
            parts.Add(doc.Description);
        }

        if (AllowsAnonymous(apiDescription))
        {
            parts.Add("This endpoint is publicly accessible.");
        }
        else
        {
            var authorizeData =
                GetAuthorizeData(apiDescription);

            if (authorizeData.Length > 0)
            {
                var policies =
                    authorizeData
                        .Select(data => data.Policy)
                        .Where(policy =>
                            !string.IsNullOrWhiteSpace(policy))
                        .Distinct(StringComparer.Ordinal)
                        .ToArray();

                parts.Add(
                    policies.Length == 0
                        ? "Requires Bearer JWT authentication."
                        : "Requires Bearer JWT authentication and the "
                          + string.Join(", ", policies)
                          + " authorization policy.");
            }
        }

        return string.Join(" ", parts);
    }

    private static bool AllowsAnonymous(
        ApiDescription apiDescription)
    {
        return apiDescription
            .ActionDescriptor
            .EndpointMetadata
            .OfType<IAllowAnonymous>()
            .Any();
    }

    private static IAuthorizeData[] GetAuthorizeData(
        ApiDescription apiDescription)
    {
        return apiDescription
            .ActionDescriptor
            .EndpointMetadata
            .OfType<IAuthorizeData>()
            .ToArray();
    }

    private static bool HasRestrictiveAuthorization(
        IEnumerable<IAuthorizeData> authorizeData)
    {
        return authorizeData.Any(data =>
            !string.IsNullOrWhiteSpace(data.Roles) ||
            !string.IsNullOrWhiteSpace(data.Policy) &&
            !string.Equals(
                data.Policy,
                "AuthenticatedUser",
                StringComparison.Ordinal));
    }

    private static bool IsUnsafeHttpMethod(
        string? httpMethod)
    {
        return string.Equals(
                   httpMethod,
                   "POST",
                   StringComparison.OrdinalIgnoreCase) ||
               string.Equals(
                   httpMethod,
                   "PUT",
                   StringComparison.OrdinalIgnoreCase) ||
               string.Equals(
                   httpMethod,
                   "PATCH",
                   StringComparison.OrdinalIgnoreCase) ||
               string.Equals(
                   httpMethod,
                   "DELETE",
                   StringComparison.OrdinalIgnoreCase);
    }

    private static void EnsureBearerSecurityRequirement(
        OpenApiOperation operation)
    {
        operation.Security ??= new List<OpenApiSecurityRequirement>();

        if (operation.Security.Any(requirement =>
                requirement.Keys.Any(scheme =>
                    string.Equals(
                        scheme.Reference?.Id,
                        BearerSchemeName,
                        StringComparison.Ordinal))))
        {
            return;
        }

        operation.Security.Add(
            new OpenApiSecurityRequirement
            {
                {
                    new OpenApiSecurityScheme
                    {
                        Reference =
                            new OpenApiReference
                            {
                                Type =
                                    ReferenceType.SecurityScheme,
                                Id =
                                    BearerSchemeName
                            }
                    },
                    Array.Empty<string>()
                }
            });
    }

    private static void AddSuccessResponse(
        OpenApiOperation operation,
        OperationFilterContext context,
        EndpointDoc doc)
    {
        var statusCode =
            doc.SuccessStatus.ToString();

        var description =
            doc.SuccessStatus switch
            {
                StatusCodes.Status201Created => "Created",
                StatusCodes.Status204NoContent => "No Content",
                _ => "OK"
            };

        AddResponse(
            operation,
            context,
            statusCode,
            description,
            doc.ResponseType,
            includeJsonContent:
                doc.SuccessStatus != StatusCodes.Status204NoContent &&
                doc.ResponseType is not null);
    }

    private static void AddErrorResponse(
        OpenApiOperation operation,
        OperationFilterContext context,
        int statusCode,
        string description)
    {
        AddResponse(
            operation,
            context,
            statusCode.ToString(),
            description,
            typeof(ApiErrorResponse),
            includeJsonContent: true);
    }

    private static void AddResponse(
        OpenApiOperation operation,
        OperationFilterContext context,
        string statusCode,
        string description,
        Type? responseType,
        bool includeJsonContent)
    {
        if (!operation.Responses.TryGetValue(
                statusCode,
                out var response))
        {
            response =
                new OpenApiResponse
                {
                    Description =
                        description
                };

            operation.Responses[statusCode] =
                response;
        }
        else if (string.IsNullOrWhiteSpace(response.Description) ||
                 string.Equals(
                     response.Description,
                     "Success",
                     StringComparison.OrdinalIgnoreCase))
        {
            response.Description =
                description;
        }

        if (!includeJsonContent ||
            responseType is null ||
            response.Content.Count > 0)
        {
            return;
        }

        var schema =
            context.SchemaGenerator.GenerateSchema(
                responseType,
                context.SchemaRepository);

        response.Content["application/json"] =
            new OpenApiMediaType
            {
                Schema =
                    schema
            };

        if (responseType == typeof(ApiErrorResponse))
        {
            response.Content["application/problem+json"] =
                new OpenApiMediaType
                {
                    Schema =
                        schema
                };
        }
    }

    private static void NormalizeResponseDescriptions(
        OpenApiOperation operation)
    {
        foreach (var response in operation.Responses)
        {
            if (!string.IsNullOrWhiteSpace(
                    response.Value.Description) &&
                !string.Equals(
                    response.Value.Description,
                    "Success",
                    StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            response.Value.Description =
                response.Key switch
                {
                    "200" => "OK",
                    "201" => "Created",
                    "204" => "No Content",
                    "400" => "Bad Request",
                    "401" => "Unauthorized",
                    "403" => "Forbidden",
                    "404" => "Not Found",
                    "409" => "Conflict",
                    _ => response.Value.Description
                };
        }
    }

    private static string SplitPascalCase(
        string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        var words =
            System.Text.RegularExpressions.Regex.Replace(
                value,
                "([a-z])([A-Z])",
                "$1 $2");

        return words[..1].ToUpperInvariant() +
               words[1..];
    }

    private sealed record EndpointDoc(
        string Summary,
        string Description,
        int SuccessStatus,
        Type? ResponseType = null,
        bool HasRequestValidation = false,
        bool CanReturnNotFound = false,
        bool CanReturnConflict = false);
}
