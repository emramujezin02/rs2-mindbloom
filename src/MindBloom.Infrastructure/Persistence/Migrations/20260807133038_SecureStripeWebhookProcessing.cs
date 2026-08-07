using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class SecureStripeWebhookProcessing : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "StripeWebhookEvents",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    StripeEventId = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    EventType = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    StripePaymentIntentId = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    ReceivedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ProcessedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsProcessed = table.Column<bool>(type: "bit", nullable: false),
                    FailureReason = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StripeWebhookEvents", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_StripeWebhookEvents_IsProcessed_ReceivedAtUtc",
                table: "StripeWebhookEvents",
                columns: new[] { "IsProcessed", "ReceivedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_StripeWebhookEvents_StripeEventId",
                table: "StripeWebhookEvents",
                column: "StripeEventId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_StripeWebhookEvents_StripePaymentIntentId",
                table: "StripeWebhookEvents",
                column: "StripePaymentIntentId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "StripeWebhookEvents");
        }
    }
}
