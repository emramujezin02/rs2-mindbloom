using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddTherapistVerification : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsVerified",
                table: "Therapists");

            migrationBuilder.AddColumn<string>(
                name: "VerificationNotes",
                table: "Therapists",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "VerificationStatus",
                table: "Therapists",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "VerificationNotes",
                table: "Therapists");

            migrationBuilder.DropColumn(
                name: "VerificationStatus",
                table: "Therapists");

            migrationBuilder.AddColumn<bool>(
                name: "IsVerified",
                table: "Therapists",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }
    }
}
