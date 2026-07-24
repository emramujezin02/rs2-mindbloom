using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class CompleteMoodEmotionTracker : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_MoodEntries_Clients_ClientId",
                table: "MoodEntries");

            migrationBuilder.DropIndex(
                name: "IX_MoodEntries_ClientId",
                table: "MoodEntries");

            migrationBuilder.AlterColumn<string>(
                name: "Notes",
                table: "MoodEntries",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "Emotion",
                table: "MoodEntries",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.CreateIndex(
                name: "IX_MoodEntries_ClientId_CreatedAtUtc_IsDeleted",
                table: "MoodEntries",
                columns: new[] { "ClientId", "CreatedAtUtc", "IsDeleted" });

            migrationBuilder.AddForeignKey(
                name: "FK_MoodEntries_Clients_ClientId",
                table: "MoodEntries",
                column: "ClientId",
                principalTable: "Clients",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_MoodEntries_Clients_ClientId",
                table: "MoodEntries");

            migrationBuilder.DropIndex(
                name: "IX_MoodEntries_ClientId_CreatedAtUtc_IsDeleted",
                table: "MoodEntries");

            migrationBuilder.AlterColumn<string>(
                name: "Notes",
                table: "MoodEntries",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(500)",
                oldMaxLength: 500);

            migrationBuilder.AlterColumn<string>(
                name: "Emotion",
                table: "MoodEntries",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(500)",
                oldMaxLength: 500);

            migrationBuilder.CreateIndex(
                name: "IX_MoodEntries_ClientId",
                table: "MoodEntries",
                column: "ClientId");

            migrationBuilder.AddForeignKey(
                name: "FK_MoodEntries_Clients_ClientId",
                table: "MoodEntries",
                column: "ClientId",
                principalTable: "Clients",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
