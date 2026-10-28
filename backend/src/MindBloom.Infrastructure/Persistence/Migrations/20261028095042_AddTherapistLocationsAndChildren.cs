using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddTherapistLocationsAndChildren : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "LocationId",
                table: "Therapists",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "WorksWithChildren",
                table: "Therapists",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "TherapistLocations",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Country = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Region = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TherapistLocations", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Therapists_LocationId",
                table: "Therapists",
                column: "LocationId");

            migrationBuilder.CreateIndex(
                name: "IX_TherapistLocations_Name_Country_Region",
                table: "TherapistLocations",
                columns: new[] { "Name", "Country", "Region" },
                unique: true,
                filter: "[IsDeleted] = 0");

            migrationBuilder.AddForeignKey(
                name: "FK_Therapists_TherapistLocations_LocationId",
                table: "Therapists",
                column: "LocationId",
                principalTable: "TherapistLocations",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
            // Only the two cities explicitly present in the existing demo data are introduced.
            // Unknown or contradictory legacy locations keep their original text and a null FK.
            migrationBuilder.Sql("""
                INSERT INTO TherapistLocations (Name, Country, Region, IsActive, CreatedAtUtc, IsDeleted)
                VALUES (N'Sarajevo', N'Bosnia and Herzegovina', N'', 1, SYSUTCDATETIME(), 0),
                       (N'Mostar', N'Bosnia and Herzegovina', N'', 1, SYSUTCDATETIME(), 0);
                UPDATE t SET LocationId = l.Id
                FROM Therapists t
                JOIN TherapistLocations l ON LOWER(LTRIM(RTRIM(t.City))) = LOWER(l.Name)
                    AND LOWER(LTRIM(RTRIM(t.Country))) = LOWER(l.Country)
                WHERE t.LocationId IS NULL AND (
                    NULLIF(LTRIM(RTRIM(t.Location)), N'') IS NULL
                    OR LOWER(LTRIM(RTRIM(t.Location))) = LOWER(l.Name)
                    OR LOWER(LTRIM(RTRIM(t.Location))) = LOWER(l.Name + N', ' + l.Country));
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Therapists_TherapistLocations_LocationId",
                table: "Therapists");

            migrationBuilder.DropTable(
                name: "TherapistLocations");

            migrationBuilder.DropIndex(
                name: "IX_Therapists_LocationId",
                table: "Therapists");

            migrationBuilder.DropColumn(
                name: "LocationId",
                table: "Therapists");

            migrationBuilder.DropColumn(
                name: "WorksWithChildren",
                table: "Therapists");
        }
    }
}
