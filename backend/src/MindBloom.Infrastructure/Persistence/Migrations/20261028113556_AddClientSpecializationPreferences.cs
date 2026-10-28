using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddClientSpecializationPreferences : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ClientSpecializations",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ClientId = table.Column<int>(type: "int", nullable: false),
                    TherapistSpecializationId = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ClientSpecializations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ClientSpecializations_Clients_ClientId",
                        column: x => x.ClientId,
                        principalTable: "Clients",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ClientSpecializations_TherapistSpecializations_TherapistSpecializationId",
                        column: x => x.TherapistSpecializationId,
                        principalTable: "TherapistSpecializations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ClientSpecializations_ClientId_TherapistSpecializationId",
                table: "ClientSpecializations",
                columns: new[] { "ClientId", "TherapistSpecializationId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ClientSpecializations_TherapistSpecializationId",
                table: "ClientSpecializations",
                column: "TherapistSpecializationId");

            // Preserve legacy text and existing FKs. Link only an unambiguous exact name.
            migrationBuilder.Sql("""
                WITH Matches AS (
                    SELECT t.Id AS TherapistId, MIN(s.Id) AS SpecializationId
                    FROM Therapists t
                    JOIN TherapistSpecializations s ON
                        LOWER(LTRIM(RTRIM(t.Specialization))) = LOWER(LTRIM(RTRIM(s.Name)))
                    WHERE t.SpecializationId IS NULL AND s.IsDeleted = 0
                    GROUP BY t.Id HAVING COUNT(*) = 1
                )
                UPDATE t SET SpecializationId = m.SpecializationId
                FROM Therapists t JOIN Matches m ON m.TherapistId = t.Id;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ClientSpecializations");
        }
    }
}
