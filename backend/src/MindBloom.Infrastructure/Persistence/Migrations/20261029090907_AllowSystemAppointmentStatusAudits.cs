using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AllowSystemAppointmentStatusAudits : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<int>(
                name: "ChangedByUserId",
                table: "AppointmentStatusAudits",
                type: "int",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Never replace a system actor with a fabricated user ID during downgrade.
            migrationBuilder.Sql("""
                IF EXISTS (SELECT 1 FROM [AppointmentStatusAudits] WHERE [ChangedByUserId] IS NULL)
                    THROW 51012, 'Cannot downgrade while system appointment audit records exist.', 1;
                """);
            migrationBuilder.AlterColumn<int>(
                name: "ChangedByUserId",
                table: "AppointmentStatusAudits",
                type: "int",
                nullable: false,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);
        }
    }
}
