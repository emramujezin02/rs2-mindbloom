using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class CompleteTherapistProfile : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Languages",
                table: "Therapists",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Location",
                table: "Therapists",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Languages",
                table: "Therapists");

            migrationBuilder.DropColumn(
                name: "Location",
                table: "Therapists");
        }
    }
}
