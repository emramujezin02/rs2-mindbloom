using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class CompleteTransactionaloutbox : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_OutboxMessages_ProcessedAtUtc_IsDeadLettered_NextAttemptAtUtc",
                table: "OutboxMessages");

            migrationBuilder.AddColumn<string>(
                name: "IdempotencyKey",
                table: "OutboxMessages",
                type: "nvarchar(250)",
                maxLength: 250,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Status",
                table: "OutboxMessages",
                type: "int",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.CreateIndex(
                name: "IX_OutboxMessages_IdempotencyKey",
                table: "OutboxMessages",
                column: "IdempotencyKey",
                unique: true,
                filter: "[IdempotencyKey] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_OutboxMessages_Status_ProcessedAtUtc_NextAttemptAtUtc",
                table: "OutboxMessages",
                columns: new[] { "Status", "ProcessedAtUtc", "NextAttemptAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_OutboxMessages_IdempotencyKey",
                table: "OutboxMessages");

            migrationBuilder.DropIndex(
                name: "IX_OutboxMessages_Status_ProcessedAtUtc_NextAttemptAtUtc",
                table: "OutboxMessages");

            migrationBuilder.DropColumn(
                name: "IdempotencyKey",
                table: "OutboxMessages");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "OutboxMessages");

            migrationBuilder.CreateIndex(
                name: "IX_OutboxMessages_ProcessedAtUtc_IsDeadLettered_NextAttemptAtUtc",
                table: "OutboxMessages",
                columns: new[] { "ProcessedAtUtc", "IsDeadLettered", "NextAttemptAtUtc" });
        }
    }
}
