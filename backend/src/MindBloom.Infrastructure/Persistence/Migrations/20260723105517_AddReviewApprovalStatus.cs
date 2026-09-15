using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddReviewApprovalStatus : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Reviews_IsDeleted_Rating_CreatedAtUtc",
                table: "Reviews");

            migrationBuilder.AddColumn<bool>(
                name: "IsApproved",
                table: "Reviews",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_Reviews_IsApproved_IsDeleted_CreatedAtUtc",
                table: "Reviews",
                columns: new[] { "IsApproved", "IsDeleted", "CreatedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Reviews_IsApproved_IsDeleted_CreatedAtUtc",
                table: "Reviews");

            migrationBuilder.DropColumn(
                name: "IsApproved",
                table: "Reviews");

            migrationBuilder.CreateIndex(
                name: "IX_Reviews_IsDeleted_Rating_CreatedAtUtc",
                table: "Reviews",
                columns: new[] { "IsDeleted", "Rating", "CreatedAtUtc" });
        }
    }
}
