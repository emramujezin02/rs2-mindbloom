using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class HardenPasswordResetTokens : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "Code",
                table: "PasswordResetCodes",
                newName: "TokenHash");

            migrationBuilder.AddColumn<DateTime>(
                name: "UsedAtUtc",
                table: "PasswordResetCodes",
                type: "datetime2",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "UsedAtUtc",
                table: "PasswordResetCodes");

            migrationBuilder.RenameColumn(
                name: "TokenHash",
                table: "PasswordResetCodes",
                newName: "Code");
        }
    }
}
