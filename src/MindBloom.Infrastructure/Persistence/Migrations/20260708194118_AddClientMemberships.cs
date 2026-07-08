using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddClientMemberships : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ClientMemberships",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ClientId = table.Column<int>(type: "int", nullable: false),
                    TherapistId = table.Column<int>(type: "int", nullable: false),
                    PlanType = table.Column<int>(type: "int", nullable: false),
                    TotalSessions = table.Column<int>(type: "int", nullable: false),
                    RemainingSessions = table.Column<int>(type: "int", nullable: false),
                    Price = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    PurchasedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ClientMemberships", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ClientMemberships_Clients_ClientId",
                        column: x => x.ClientId,
                        principalTable: "Clients",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ClientMemberships_Therapists_TherapistId",
                        column: x => x.TherapistId,
                        principalTable: "Therapists",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "MembershipUsages",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ClientMembershipId = table.Column<int>(type: "int", nullable: false),
                    AppointmentId = table.Column<int>(type: "int", nullable: false),
                    UsedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MembershipUsages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MembershipUsages_Appointments_AppointmentId",
                        column: x => x.AppointmentId,
                        principalTable: "Appointments",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MembershipUsages_ClientMemberships_ClientMembershipId",
                        column: x => x.ClientMembershipId,
                        principalTable: "ClientMemberships",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ClientMemberships_ClientId",
                table: "ClientMemberships",
                column: "ClientId");

            migrationBuilder.CreateIndex(
                name: "IX_ClientMemberships_TherapistId",
                table: "ClientMemberships",
                column: "TherapistId");

            migrationBuilder.CreateIndex(
                name: "IX_MembershipUsages_AppointmentId",
                table: "MembershipUsages",
                column: "AppointmentId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MembershipUsages_ClientMembershipId",
                table: "MembershipUsages",
                column: "ClientMembershipId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "MembershipUsages");

            migrationBuilder.DropTable(
                name: "ClientMemberships");
        }
    }
}
