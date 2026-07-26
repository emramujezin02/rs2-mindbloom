using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddClinetOnboardingAssessment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Clients_UserId",
                table: "Clients");

            migrationBuilder.AddColumn<string>(
                name: "AssessmentFocusAreas",
                table: "Clients",
                type: "nvarchar(1500)",
                maxLength: 1500,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "HasCompletedOnboarding",
                table: "Clients",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "OnboardingCompletedAtUtc",
                table: "Clients",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PreferredDays",
                table: "Clients",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ClientTherapyApproaches",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ClientId = table.Column<int>(type: "int", nullable: false),
                    TherapyApproachId = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ClientTherapyApproaches", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ClientTherapyApproaches_Clients_ClientId",
                        column: x => x.ClientId,
                        principalTable: "Clients",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ClientTherapyApproaches_TherapyApproaches_TherapyApproachId",
                        column: x => x.TherapyApproachId,
                        principalTable: "TherapyApproaches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Clients_UserId_HasCompletedOnboarding_IsDeleted",
                table: "Clients",
                columns: new[] { "UserId", "HasCompletedOnboarding", "IsDeleted" });

            migrationBuilder.CreateIndex(
                name: "IX_ClientTherapyApproaches_ClientId_IsDeleted",
                table: "ClientTherapyApproaches",
                columns: new[] { "ClientId", "IsDeleted" });

            migrationBuilder.CreateIndex(
                name: "IX_ClientTherapyApproaches_ClientId_TherapyApproachId",
                table: "ClientTherapyApproaches",
                columns: new[] { "ClientId", "TherapyApproachId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ClientTherapyApproaches_TherapyApproachId",
                table: "ClientTherapyApproaches",
                column: "TherapyApproachId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ClientTherapyApproaches");

            migrationBuilder.DropIndex(
                name: "IX_Clients_UserId_HasCompletedOnboarding_IsDeleted",
                table: "Clients");

            migrationBuilder.DropColumn(
                name: "AssessmentFocusAreas",
                table: "Clients");

            migrationBuilder.DropColumn(
                name: "HasCompletedOnboarding",
                table: "Clients");

            migrationBuilder.DropColumn(
                name: "OnboardingCompletedAtUtc",
                table: "Clients");

            migrationBuilder.DropColumn(
                name: "PreferredDays",
                table: "Clients");

            migrationBuilder.CreateIndex(
                name: "IX_Clients_UserId",
                table: "Clients",
                column: "UserId");
        }
    }
}
