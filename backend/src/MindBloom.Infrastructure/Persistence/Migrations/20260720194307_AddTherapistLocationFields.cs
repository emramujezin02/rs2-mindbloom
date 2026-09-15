using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    public partial class AddTherapistLocationFields : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Address",
                table: "Therapists",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "City",
                table: "Therapists",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "Country",
                table: "Therapists",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<bool>(
                name: "OffersInPerson",
                table: "Therapists",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "OffersOnline",
                table: "Therapists",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Address",
                table: "Therapists");

            migrationBuilder.DropColumn(
                name: "City",
                table: "Therapists");

            migrationBuilder.DropColumn(
                name: "Country",
                table: "Therapists");

            migrationBuilder.DropColumn(
                name: "OffersInPerson",
                table: "Therapists");

            migrationBuilder.DropColumn(
                name: "OffersOnline",
                table: "Therapists");
        }
    }
}
