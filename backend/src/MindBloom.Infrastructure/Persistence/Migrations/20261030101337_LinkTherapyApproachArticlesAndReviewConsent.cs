using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class LinkTherapyApproachArticlesAndReviewConsent : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "FeaturedArticleId",
                table: "TherapyApproaches",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "ShareAuthorDemographics",
                table: "Reviews",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "SeedKey",
                table: "Articles",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_TherapyApproaches_FeaturedArticleId",
                table: "TherapyApproaches",
                column: "FeaturedArticleId");

            migrationBuilder.CreateIndex(
                name: "IX_Articles_SeedKey",
                table: "Articles",
                column: "SeedKey",
                unique: true,
                filter: "[SeedKey] IS NOT NULL");

            migrationBuilder.AddForeignKey(
                name: "FK_TherapyApproaches_Articles_FeaturedArticleId",
                table: "TherapyApproaches",
                column: "FeaturedArticleId",
                principalTable: "Articles",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_TherapyApproaches_Articles_FeaturedArticleId",
                table: "TherapyApproaches");

            migrationBuilder.DropIndex(
                name: "IX_TherapyApproaches_FeaturedArticleId",
                table: "TherapyApproaches");

            migrationBuilder.DropIndex(
                name: "IX_Articles_SeedKey",
                table: "Articles");

            migrationBuilder.DropColumn(
                name: "FeaturedArticleId",
                table: "TherapyApproaches");

            migrationBuilder.DropColumn(
                name: "ShareAuthorDemographics",
                table: "Reviews");

            migrationBuilder.DropColumn(
                name: "SeedKey",
                table: "Articles");
        }
    }
}
