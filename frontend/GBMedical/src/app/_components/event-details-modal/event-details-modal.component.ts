import { Component, Inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon';
import { AppointmentService } from '../../_services/appointments.service';
import Swal from 'sweetalert2';
import { CommonModule } from '@angular/common';
import { AuthService } from '../../_services/auth.service';

export interface EventDetailsData {
  title: string;
  start: string;
  end: string;
  status: string;
  doctorId: number;
  patientId: number;
  serviceName: string;
  doctorName: string;
  allowCancellation: boolean;
  appointmentId: number;
}

@Component({
  selector: 'app-event-details-modal',
  imports: [MatIconModule, CommonModule],
  templateUrl: './event-details-modal.component.html',
  styleUrl: './event-details-modal.component.css'
})
export class EventDetailsModalComponent {
  currentUserId: number | null = null; // Jelenlegi felhasználó ID-ja
  isProcessing = false;

  constructor(
    public dialogRef: MatDialogRef<EventDetailsModalComponent>,
    @Inject(MAT_DIALOG_DATA) public data: EventDetailsData,
    private appointmentService: AppointmentService,
    private authService: AuthService
  ) {
    this.currentUserId = this.authService.getUserId(); // Felhasználó ID lekérése
  }

  onClose(): void {
    if (this.isProcessing) {
      return;
    }
    this.dialogRef.close();
  }

  // Az időpontfoglalás gomb kattintásának kezelése
  onBookingClick(): void {
    if (this.isProcessing) {
      return;
    }
    this.isProcessing = true;
    console.log('Időpontfoglalás indítása...');

    // Az időpontfoglaláshoz szükséges adatok
    const appointment = {
      doctorId: this.data.doctorId,
      patientId: this.data.patientId,
      startTime: this.data.start,
      endTime: this.data.end,
      status: 'booked'
    };

    // Foglalás elküldése a szervernek
    this.appointmentService.addAppointmentWithNotification(appointment).subscribe({
      next: response => {
        console.log('Foglalás sikeres:', response);
        Swal.fire({
          title: 'Sikeres foglalás!',
          text: 'Az időpontot sikeresen lefoglaltad.',
          icon: 'success',
          timer: 3000
        });
        this.dialogRef.close({ refresh: true });
      },
      error: error => {
        this.isProcessing = false;
        console.error('Foglalás hiba:', error);
        Swal.fire({
          title: 'Hiba!',
          text: 'Nem sikerült a foglalás. Próbáld újra később!',
          icon: 'error',
          timer: 3000
        });
      }
    });
  }

  onCancelClick(): void {
    if (this.isProcessing) {
      return;
    }
    if (this.data.patientId !== this.currentUserId) {
      return;
    }

    // Ellenőrzés, hogy léteznek-e érvényes adatok
    if (!this.data.appointmentId || !this.data.patientId) {
      console.error('Nincs érvényes appointmentId vagy patientId.');
      return;
    }

    this.isProcessing = true;
    // Hívjuk a cancelAppointment metódust appointmentId és patientId-val
    this.appointmentService.cancelAppointment(this.data.appointmentId, this.data.patientId).subscribe({
      next: response => {
        Swal.fire({
          title: 'Sikeres lemondás!',
          text: 'Az időpontot sikeresen törölted.',
          icon: 'success',
          timer: 3000
        });
        this.dialogRef.close({ refresh: true });
      },
      error: error => {
        this.isProcessing = false;
        Swal.fire({
          title: 'Hiba!',
          text: 'Nem sikerült a lemondás. Próbáld újra később!',
          icon: 'error',
          timer: 3000
        });
      }
    });
  }
}
