using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class ConfigureTherapyApproachRelations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_TherapistTherapyApproaches_TherapyApproaches_TherapyApproachId",
                table: "TherapistTherapyApproaches");

            migrationBuilder.AlterColumn<string>(
                name: "Name",
                table: "TherapyApproaches",
                type: "nvarchar(150)",
                maxLength: 150,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<bool>(
                name: "IsActive",
                table: "TherapyApproaches",
                type: "bit",
                nullable: false,
                defaultValue: true,
                oldClrType: typeof(bool),
                oldType: "bit");

            migrationBuilder.AlterColumn<string>(
                name: "Description",
                table: "TherapyApproaches",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_TherapyApproaches_IsActive_IsDeleted",
                table: "TherapyApproaches",
                columns: new[] { "IsActive", "IsDeleted" });

            migrationBuilder.CreateIndex(
                name: "IX_TherapyApproaches_Name",
                table: "TherapyApproaches",
                column: "Name",
                unique: true,
                filter: "[IsDeleted] = 0");

            migrationBuilder.CreateIndex(
                name: "IX_TherapistTherapyApproaches_TherapistId_IsDeleted",
                table: "TherapistTherapyApproaches",
                columns: new[] { "TherapistId", "IsDeleted" });

            migrationBuilder.AddForeignKey(
                name: "FK_TherapistTherapyApproaches_TherapyApproaches_TherapyApproachId",
                table: "TherapistTherapyApproaches",
                column: "TherapyApproachId",
                principalTable: "TherapyApproaches",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_TherapistTherapyApproaches_TherapyApproaches_TherapyApproachId",
                table: "TherapistTherapyApproaches");

            migrationBuilder.DropIndex(
                name: "IX_TherapyApproaches_IsActive_IsDeleted",
                table: "TherapyApproaches");

            migrationBuilder.DropIndex(
                name: "IX_TherapyApproaches_Name",
                table: "TherapyApproaches");

            migrationBuilder.DropIndex(
                name: "IX_TherapistTherapyApproaches_TherapistId_IsDeleted",
                table: "TherapistTherapyApproaches");

            migrationBuilder.AlterColumn<string>(
                name: "Name",
                table: "TherapyApproaches",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(150)",
                oldMaxLength: 150);

            migrationBuilder.AlterColumn<bool>(
                name: "IsActive",
                table: "TherapyApproaches",
                type: "bit",
                nullable: false,
                oldClrType: typeof(bool),
                oldType: "bit",
                oldDefaultValue: true);

            migrationBuilder.AlterColumn<string>(
                name: "Description",
                table: "TherapyApproaches",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(500)",
                oldMaxLength: 500,
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_TherapistTherapyApproaches_TherapyApproaches_TherapyApproachId",
                table: "TherapistTherapyApproaches",
                column: "TherapyApproachId",
                principalTable: "TherapyApproaches",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
