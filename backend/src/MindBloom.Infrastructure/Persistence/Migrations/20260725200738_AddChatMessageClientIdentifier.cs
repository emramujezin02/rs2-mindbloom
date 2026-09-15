using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddChatMessageClientIdentifier : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ClientMessageId",
                table: "ChatMessages",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_ConversationId_ClientMessageId",
                table: "ChatMessages",
                columns: new[] { "ConversationId", "ClientMessageId" },
                unique: true,
                filter: "[ClientMessageId] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ChatMessages_ConversationId_ClientMessageId",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "ClientMessageId",
                table: "ChatMessages");
        }
    }
}
