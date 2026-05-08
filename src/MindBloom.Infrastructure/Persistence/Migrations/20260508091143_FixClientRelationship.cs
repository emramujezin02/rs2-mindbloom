using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class FixClientRelationship : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Appointments_AspNetUsers_ClientId",
                table: "Appointments");

            migrationBuilder.DropForeignKey(
                name: "FK_Appointments_Clients_ClientId1",
                table: "Appointments");

            migrationBuilder.DropIndex(
                name: "IX_Appointments_ClientId1",
                table: "Appointments");

            migrationBuilder.DropColumn(
                name: "ClientId1",
                table: "Appointments");

            migrationBuilder.AddColumn<int>(
                name: "ApplicationUserId1",
                table: "Appointments",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Appointments_ApplicationUserId1",
                table: "Appointments",
                column: "ApplicationUserId1");

            migrationBuilder.AddForeignKey(
                name: "FK_Appointments_AspNetUsers_ApplicationUserId1",
                table: "Appointments",
                column: "ApplicationUserId1",
                principalTable: "AspNetUsers",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Appointments_Clients_ClientId",
                table: "Appointments",
                column: "ClientId",
                principalTable: "Clients",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Appointments_AspNetUsers_ApplicationUserId1",
                table: "Appointments");

            migrationBuilder.DropForeignKey(
                name: "FK_Appointments_Clients_ClientId",
                table: "Appointments");

            migrationBuilder.DropIndex(
                name: "IX_Appointments_ApplicationUserId1",
                table: "Appointments");

            migrationBuilder.DropColumn(
                name: "ApplicationUserId1",
                table: "Appointments");

            migrationBuilder.AddColumn<int>(
                name: "ClientId1",
                table: "Appointments",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateIndex(
                name: "IX_Appointments_ClientId1",
                table: "Appointments",
                column: "ClientId1");

            migrationBuilder.AddForeignKey(
                name: "FK_Appointments_AspNetUsers_ClientId",
                table: "Appointments",
                column: "ClientId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Appointments_Clients_ClientId1",
                table: "Appointments",
                column: "ClientId1",
                principalTable: "Clients",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
