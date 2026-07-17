using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddTherapistSpecializations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Specialization",
                table: "Therapists",
                type: "nvarchar(150)",
                maxLength: 150,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AddColumn<int>(
                name: "SpecializationId",
                table: "Therapists",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "TherapistSpecializations",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TherapistSpecializations", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Therapists_SpecializationId",
                table: "Therapists",
                column: "SpecializationId");

            migrationBuilder.CreateIndex(
                name: "IX_TherapistSpecializations_IsActive_IsDeleted",
                table: "TherapistSpecializations",
                columns: new[] { "IsActive", "IsDeleted" });

            migrationBuilder.CreateIndex(
                name: "IX_TherapistSpecializations_Name",
                table: "TherapistSpecializations",
                column: "Name",
                unique: true,
                filter: "[IsDeleted] = 0");

            migrationBuilder.AddForeignKey(
                name: "FK_Therapists_TherapistSpecializations_SpecializationId",
                table: "Therapists",
                column: "SpecializationId",
                principalTable: "TherapistSpecializations",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Therapists_TherapistSpecializations_SpecializationId",
                table: "Therapists");

            migrationBuilder.DropTable(
                name: "TherapistSpecializations");

            migrationBuilder.DropIndex(
                name: "IX_Therapists_SpecializationId",
                table: "Therapists");

            migrationBuilder.DropColumn(
                name: "SpecializationId",
                table: "Therapists");

            migrationBuilder.AlterColumn<string>(
                name: "Specialization",
                table: "Therapists",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(150)",
                oldMaxLength: 150);
        }
    }
}
