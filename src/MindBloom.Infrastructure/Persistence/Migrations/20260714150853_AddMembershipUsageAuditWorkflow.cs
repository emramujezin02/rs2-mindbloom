using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddMembershipUsageAuditWorkflow : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_MembershipUsages_ClientMembershipId",
                table: "MembershipUsages");

            migrationBuilder.AddColumn<DateTime>(
                name: "ConsumedAtUtc",
                table: "MembershipUsages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ReservedAtUtc",
                table: "MembershipUsages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ResolutionReason",
                table: "MembershipUsages",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "RestoredAtUtc",
                table: "MembershipUsages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Status",
                table: "MembershipUsages",
                type: "int",
                nullable: false,
                defaultValue: 2);

            migrationBuilder.CreateIndex(
                name: "IX_MembershipUsages_ClientMembershipId_Status",
                table: "MembershipUsages",
                columns: new[] { "ClientMembershipId", "Status" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_MembershipUsages_ClientMembershipId_Status",
                table: "MembershipUsages");

            migrationBuilder.DropColumn(
                name: "ConsumedAtUtc",
                table: "MembershipUsages");

            migrationBuilder.DropColumn(
                name: "ReservedAtUtc",
                table: "MembershipUsages");

            migrationBuilder.DropColumn(
                name: "ResolutionReason",
                table: "MembershipUsages");

            migrationBuilder.DropColumn(
                name: "RestoredAtUtc",
                table: "MembershipUsages");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "MembershipUsages");

            migrationBuilder.CreateIndex(
                name: "IX_MembershipUsages_ClientMembershipId",
                table: "MembershipUsages",
                column: "ClientMembershipId");
        }
    }
}
