using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddTransactionalOutbox : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "OutboxMessages",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    EventId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CorrelationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    EventType = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    RoutingKey = table.Column<string>(type: "nvarchar(250)", maxLength: 250, nullable: false),
                    PayloadJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    OccurredAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ProcessedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    AttemptCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    LastAttemptAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    NextAttemptAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    LastError = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    IsDeadLettered = table.Column<bool>(type: "bit", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OutboxMessages", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_OutboxMessages_CreatedAtUtc",
                table: "OutboxMessages",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_OutboxMessages_EventId",
                table: "OutboxMessages",
                column: "EventId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_OutboxMessages_ProcessedAtUtc_IsDeadLettered_NextAttemptAtUtc",
                table: "OutboxMessages",
                columns: new[] { "ProcessedAtUtc", "IsDeadLettered", "NextAttemptAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "OutboxMessages");
        }
    }
}
