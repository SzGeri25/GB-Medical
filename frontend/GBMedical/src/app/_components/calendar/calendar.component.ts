import { Component, OnInit, ViewChild, HostListener } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { FullCalendarModule } from '@fullcalendar/angular';
import { FullCalendarComponent } from '@fullcalendar/angular';
import { CalendarOptions } from '@fullcalendar/core';
import dayGridPlugin from '@fullcalendar/daygrid';
import { NavbarComponent } from '../navbar/navbar.component';
import { lastValueFrom } from 'rxjs';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { EventDetailsModalComponent, EventDetailsData } from '../event-details-modal/event-details-modal.component';
import { AppointmentService } from '../../_services/appointments.service';
import { ServicesComponent } from '../services/services.component';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { FooterComponent } from "../footer/footer.component";
import { AuthService } from '../../_services/auth.service';
import Swal from 'sweetalert2';
import { ChevronUpComponent } from "../chevron-up/chevron-up.component";

interface Service {
  id: number;
  name: string;
  description: string;
  doctor_names: string[];
  price: number;
  duration: number;
}

@Component({
  selector: 'app-calendar',
  standalone: true,
  imports: [FullCalendarModule, NavbarComponent, MatDialogModule, FormsModule, CommonModule, FooterComponent, ChevronUpComponent],
  templateUrl: './calendar.component.html',
  styleUrls: ['./calendar.component.css']
})
export class CalendarComponent implements OnInit {
  @ViewChild('calendar') calendarComponent!: FullCalendarComponent;
  private resizeTimeout: any;

  @HostListener('window:resize', ['$event'])
  onResize(event: Event) {
    // Debounce a túl gyors újrarajzolások elkerüléséhez
    clearTimeout(this.resizeTimeout);
    this.resizeTimeout = setTimeout(() => {
      this.adjustHeaderTools();
      this.calendarComponent.getApi().updateSize();
    }, 150);
  }

  bookedEvents: any[] = [];
  availableEvents: any[] = [];
  doctorId: number | null = null;
  serviceId: number | null = null; // Új property a service ID tárolására
  showAllSlots: boolean = false;

  calendarOptions: CalendarOptions = {
    initialView: 'dayGridMonth',
    locale: 'hu',
    headerToolbar: {
      left: 'prev,next today',
      center: 'title',
      right: 'dayGridMonth,dayGridWeek,dayGridDay'
    },
    buttonText: {
      today: 'Ma',
      month: 'Hónap',
      week: 'Hét',
      day: 'Nap'
    },
    plugins: [dayGridPlugin],
    events: [],
    eventClick: this.handleEventClick.bind(this),
    contentHeight: 'auto',
    fixedWeekCount: false, // Ne mutasson mindig 6 hetet
    aspectRatio: 1.5,     // Optimalizált arány
    eventTimeFormat: {    // Időformátum
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    }
  };

  private bookedApiUrl = 'http://127.0.0.1:8080/GBMedicalBackend-1.0-SNAPSHOT/webresources/appointments/getBookedAppointments';


  constructor(
    private http: HttpClient,
    private dialog: MatDialog,
    private appointmentService: AppointmentService,
    private route: ActivatedRoute,
    private authService: AuthService,
    private router: Router
  ) { }

  ngOnInit(): void {
    // Kezdeti méretezés
    this.adjustHeaderTools();
    this.route.queryParamMap.subscribe(params => {
      this.doctorId = params.has('doctorId') ? Number(params.get('doctorId')) : null;
      this.serviceId = params.has('serviceId') ? Number(params.get('serviceId')) : null;
      this.showAllSlots = params.get('allSlots') === 'true'; // allSlots kezelése

      // Adatok újratöltése paraméterváltozás esetén
      this.fetchBookedAppointments().then(() => {
        this.loadAvailableAppointments().then(() => {
          this.updateCalendarEvents();
        });
      });
    });
  }

  ngOnDestroy(): void {
    clearTimeout(this.resizeTimeout);
  }

  private adjustHeaderTools() {
    const calendarApi = this.calendarComponent?.getApi();
    if (!calendarApi) return;

    if (window.innerWidth < 768) {
      calendarApi.setOption('headerToolbar', {
        left: 'prev,next',
        center: 'title',
        right: ''
      });
    } else {
      calendarApi.setOption('headerToolbar', {
        left: 'prev,next today',
        center: 'title',
        right: 'dayGridMonth,dayGridWeek,dayGridDay'
      });
    }
  }

  async fetchBookedAppointments(): Promise<void> {
    this.bookedEvents = [];
    try {
      const response = await fetch(this.bookedApiUrl);
      if (!response.ok) {
        throw new Error(`Hálózati hiba: ${response.statusText}`);
      }
      const responseData = await response.json();

      console.log("Foglalt időpontok: ", responseData);

      if (responseData && responseData.status === 'success' && responseData.appointments) {
        this.bookedEvents = responseData.appointments.map((appointment: any) => ({
          id: appointment.id,
          title: `${appointment.doctorName} - ${appointment.serviceName}`,
          start: this.convertToLocalISOString(appointment.startTime),
          end: this.convertToLocalISOString(appointment.endTime),
          backgroundColor: 'red',
          borderColor: 'red',
          extendedProps: {
            status: appointment.status,
            doctorId: appointment.doctorId,
            patientId: appointment.patientId,
            serviceName: appointment.serviceName,
          }
        }));
      } else {
        console.error('Nem megfelelő API válasz (foglalások):', responseData);
      }
    } catch (error) {
      console.error('Hiba történt a foglalt időpontok lekérése során:', error);
    }
  }

  async loadAvailableAppointments(): Promise<void> {
    this.availableEvents = [];
    try {
      let response: any;

      if (this.showAllSlots) {
        // Összes szabad időpont lekérése
        response = await lastValueFrom(this.appointmentService.getAvailableSlots());
      } else if (this.serviceId) {
        response = await lastValueFrom(this.appointmentService.getAvailableSlotsByService(this.serviceId));
      } else if (this.doctorId) {
        response = await lastValueFrom(this.appointmentService.getAvailableSlotsByDoctor(this.doctorId));
      } else {
        console.error('Nincs paraméter megadva!');
        return;
      }

      if (response.status === 'success') {
        this.availableEvents = response.slots.map((slot: any) => ({
          title: this.showAllSlots
            ? `${slot.doctorName} - ${slot.serviceName}`
            : this.serviceId
              ? `${slot.doctorName}`  // Csak orvos neve, ha service választva
              : this.doctorId
                ? `${slot.serviceName}`  // Csak szolgáltatás neve, ha orvos választva
                : `${slot.doctorName} - ${slot.serviceName}`, // Alapesetben mindkettő
          start: this.convertToLocalISOString(slot.slotStart),
          end: this.convertToLocalISOString(slot.slotEnd),
          backgroundColor: 'lightgreen',
          borderColor: 'lightgreen',
          extendedProps: {
            doctorId: slot.doctorId,
            serviceName: slot.serviceName,
            doctorName: slot.doctorName
          }
        }));
      } else {
        console.error('Hiba történt:', response);
      }
    } catch (error) {
      console.error('Hiba a szabad időpontok lekérésekor:', error);
    }
  }
  updateCalendarEvents() {
    const combinedEvents = [...this.bookedEvents, ...this.availableEvents];
    this.calendarOptions = {
      ...this.calendarOptions,
      events: combinedEvents
    };

    setTimeout(() => {
      this.calendarOptions = { ...this.calendarOptions };
    }, 100);
  }

  /**
   * Átalakítja a bejövő időpontot úgy, hogy a helyi időt tükrözze.
   */
  convertToLocalISOString(dateInput: string | Date): string {
    if (typeof dateInput === 'string') {
      const wallClockMatch = dateInput.match(/^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})/);
      if (wallClockMatch) {
        return `${wallClockMatch[1]} ${wallClockMatch[2]}`;
      }
    }

    const date = typeof dateInput === 'string' ? new Date(dateInput) : dateInput;

    if (isNaN(date.getTime())) {
      console.error("Hibás dátumformátum:", dateInput);
      return "";
    }

    const pad = (value: number): string => value.toString().padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} `
      + `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
  }

  handleEventClick(info: any): void {
    if (!this.showAllSlots && this.doctorId === null && this.serviceId === null) {
      console.error('Nincs orvos vagy szolgáltatás ID elérhető!');
      return;
    }


    const startTime: string = info.event.start ? this.convertToLocalISOString(info.event.start) : '';
    const endTime: string = info.event.end ? this.convertToLocalISOString(info.event.end) : '';

    // Itt a változás: serviceId alapján is kezeljük a foglalást
    const doctorId: number | null = info.event.extendedProps?.doctorId || this.doctorId;
    const patientId: number | null = this.authService.getUserId();

    if (!patientId) {
      Swal.fire({
        title: 'Jelentkezz be a foglaláshoz!',
        icon: 'warning',
        showConfirmButton: true,
        showCancelButton: true,
        confirmButtonText: 'Bejelentkezés!',
        cancelButtonText: 'Mégsem',
        customClass: {
          actions: 'my-actions',
          cancelButton: 'order-1 right-gap',
          confirmButton: 'order-2',
          denyButton: 'order-3',
        },
      }).then((result) => {
        if (result.isConfirmed) {
          this.router.navigate(['/login']);
        } else if (result.isDenied) {
          Swal.fire('Changes are not saved', '', 'info')
        }
      });

      return;
    }

    const isOwner = patientId === info.event.extendedProps?.patientId;
    const isBooked = info.event.extendedProps?.status === 'booked';

    if (isBooked) {
      const currentUrl = new URL(window.location.href);
      currentUrl.searchParams.set('appointmentId', info.event.id.toString());
      currentUrl.searchParams.set('patientId', patientId.toString());
      window.history.pushState(null, '', currentUrl.toString());
    }

    const data: EventDetailsData = {
      title: info.event.title,
      start: startTime,
      end: endTime,
      status: info.event.extendedProps?.status,
      doctorId: doctorId!,
      patientId: patientId,
      serviceName: info.event.extendedProps?.serviceName || 'Nincs megadva',
      doctorName: info.event.extendedProps?.doctorName || 'Nincs megadva',
      allowCancellation: isOwner,
      appointmentId: info.event.id
    };

    const dialogRef = this.dialog.open(EventDetailsModalComponent, {
      data,
      width: '400px'
    });

    dialogRef.afterClosed().subscribe((result: { refresh?: boolean } | undefined) => {
      if (result?.refresh) {
        Promise.all([
          this.fetchBookedAppointments(),
          this.loadAvailableAppointments()
        ]).then(() => this.updateCalendarEvents());
      }
    });
  }
}
