using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindBloom.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddAppointmentBookingConcurrency : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Appointments_TherapistId",
                table: "Appointments");

            migrationBuilder.CreateIndex(
                name: "IX_Appointments_Therapist_SlotLookup",
                table: "Appointments",
                columns: new[] { "TherapistId", "StartUtc", "EndUtc", "Status" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Appointments_Therapist_SlotLookup",
                table: "Appointments");

            migrationBuilder.CreateIndex(
                name: "IX_Appointments_TherapistId",
                table: "Appointments",
                column: "TherapistId");
        }
    }
}
