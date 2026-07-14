using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddStripeMembershipPayments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ClientMemberships_ClientId",
                table: "ClientMemberships");

            migrationBuilder.AlterColumn<DateTime>(
                name: "PurchasedAtUtc",
                table: "ClientMemberships",
                type: "datetime2",
                nullable: true,
                oldClrType: typeof(DateTime),
                oldType: "datetime2");

            migrationBuilder.CreateTable(
                name: "MembershipPayments",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ClientMembershipId = table.Column<int>(type: "int", nullable: false),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Currency = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    StripePaymentIntentId = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    PaidAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MembershipPayments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MembershipPayments_ClientMemberships_ClientMembershipId",
                        column: x => x.ClientMembershipId,
                        principalTable: "ClientMemberships",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ClientMemberships_ClientId_TherapistId_IsActive",
                table: "ClientMemberships",
                columns: new[] { "ClientId", "TherapistId", "IsActive" });

            migrationBuilder.CreateIndex(
                name: "IX_ClientMemberships_ClientId_TherapistId_PlanType_IsDeleted",
                table: "ClientMemberships",
                columns: new[] { "ClientId", "TherapistId", "PlanType", "IsDeleted" });

            migrationBuilder.CreateIndex(
                name: "IX_MembershipPayments_ClientMembershipId",
                table: "MembershipPayments",
                column: "ClientMembershipId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MembershipPayments_StripePaymentIntentId",
                table: "MembershipPayments",
                column: "StripePaymentIntentId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "MembershipPayments");

            migrationBuilder.DropIndex(
                name: "IX_ClientMemberships_ClientId_TherapistId_IsActive",
                table: "ClientMemberships");

            migrationBuilder.DropIndex(
                name: "IX_ClientMemberships_ClientId_TherapistId_PlanType_IsDeleted",
                table: "ClientMemberships");

            migrationBuilder.AlterColumn<DateTime>(
                name: "PurchasedAtUtc",
                table: "ClientMemberships",
                type: "datetime2",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified),
                oldClrType: typeof(DateTime),
                oldType: "datetime2",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_ClientMemberships_ClientId",
                table: "ClientMemberships",
                column: "ClientId");
        }
    }
}
