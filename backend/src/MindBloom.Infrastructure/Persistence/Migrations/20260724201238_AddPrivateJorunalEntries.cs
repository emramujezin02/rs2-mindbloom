using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPrivateJorunalEntries : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PrivateJournalEntries",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ClientId = table.Column<int>(type: "int", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    Content = table.Column<string>(type: "nvarchar(max)", maxLength: 10000, nullable: false),
                    EntryDateUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    MoodEntryId = table.Column<int>(type: "int", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PrivateJournalEntries", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PrivateJournalEntries_Clients_ClientId",
                        column: x => x.ClientId,
                        principalTable: "Clients",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PrivateJournalEntries_MoodEntries_MoodEntryId",
                        column: x => x.MoodEntryId,
                        principalTable: "MoodEntries",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PrivateJournalEntries_ClientId_EntryDateUtc",
                table: "PrivateJournalEntries",
                columns: new[] { "ClientId", "EntryDateUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_PrivateJournalEntries_ClientId_IsDeleted",
                table: "PrivateJournalEntries",
                columns: new[] { "ClientId", "IsDeleted" });

            migrationBuilder.CreateIndex(
                name: "IX_PrivateJournalEntries_MoodEntryId",
                table: "PrivateJournalEntries",
                column: "MoodEntryId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PrivateJournalEntries");
        }
    }
}
