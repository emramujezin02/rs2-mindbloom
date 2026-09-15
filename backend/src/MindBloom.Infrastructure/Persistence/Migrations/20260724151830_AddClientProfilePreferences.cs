using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddClientProfilePreferences : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Location",
                table: "Clients",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "MaximumPricePerSession",
                table: "Clients",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "MinimumPricePerSession",
                table: "Clients",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PreferredLanguages",
                table: "Clients",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PreferredSessionType",
                table: "Clients",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PreferredTherapistGender",
                table: "Clients",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Location",
                table: "Clients");

            migrationBuilder.DropColumn(
                name: "MaximumPricePerSession",
                table: "Clients");

            migrationBuilder.DropColumn(
                name: "MinimumPricePerSession",
                table: "Clients");

            migrationBuilder.DropColumn(
                name: "PreferredLanguages",
                table: "Clients");

            migrationBuilder.DropColumn(
                name: "PreferredSessionType",
                table: "Clients");

            migrationBuilder.DropColumn(
                name: "PreferredTherapistGender",
                table: "Clients");
        }
    }
}
