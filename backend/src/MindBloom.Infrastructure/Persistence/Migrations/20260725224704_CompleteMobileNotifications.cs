using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class CompleteMobileNotifications : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Notifications_Appointments_AppointmentId",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_UserId",
                table: "Notifications");

            migrationBuilder.AlterColumn<string>(
                name: "Title",
                table: "Notifications",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "Message",
                table: "Notifications",
                type: "nvarchar(2000)",
                maxLength: 2000,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AddColumn<int>(
                name: "ActionType",
                table: "Notifications",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "AppointmentId1",
                table: "Notifications",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ResourceId",
                table: "Notifications",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_AppointmentId1",
                table: "Notifications",
                column: "AppointmentId1");

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_ResourceId",
                table: "Notifications",
                column: "ResourceId");

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_UserId_CreatedAtUtc",
                table: "Notifications",
                columns: new[] { "UserId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_UserId_IsRead_CreatedAtUtc",
                table: "Notifications",
                columns: new[] { "UserId", "IsRead", "CreatedAtUtc" });

            migrationBuilder.AddForeignKey(
                name: "FK_Notifications_Appointments_AppointmentId",
                table: "Notifications",
                column: "AppointmentId",
                principalTable: "Appointments",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_Notifications_Appointments_AppointmentId1",
                table: "Notifications",
                column: "AppointmentId1",
                principalTable: "Appointments",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Notifications_Appointments_AppointmentId",
                table: "Notifications");

            migrationBuilder.DropForeignKey(
                name: "FK_Notifications_Appointments_AppointmentId1",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_AppointmentId1",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_ResourceId",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_UserId_CreatedAtUtc",
                table: "Notifications");

            migrationBuilder.DropIndex(
                name: "IX_Notifications_UserId_IsRead_CreatedAtUtc",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "ActionType",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "AppointmentId1",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "ResourceId",
                table: "Notifications");

            migrationBuilder.AlterColumn<string>(
                name: "Title",
                table: "Notifications",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(200)",
                oldMaxLength: 200);

            migrationBuilder.AlterColumn<string>(
                name: "Message",
                table: "Notifications",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(2000)",
                oldMaxLength: 2000);

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_UserId",
                table: "Notifications",
                column: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_Notifications_Appointments_AppointmentId",
                table: "Notifications",
                column: "AppointmentId",
                principalTable: "Appointments",
                principalColumn: "Id");
        }
    }
}
