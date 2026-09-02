-- phpMyAdmin SQL Dump
-- version 5.1.2
-- https://www.phpmyadmin.net/
--
-- Gép: localhost:3306
-- Létrehozás ideje: 2025. Ápr 14. 12:35
-- Kiszolgáló verziója: 5.7.24
-- PHP verzió: 8.3.1

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Adatbázis: `gb_medical_idopontfoglalo`
--
CREATE DATABASE IF NOT EXISTS `gb_medical_idopontfoglalo` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
USE `gb_medical_idopontfoglalo`;

DELIMITER $$
--
-- Eljárások
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `addAppointment` (IN `doctor_idIN` INT, IN `patient_idIN` INT, IN `start_timeIN` DATETIME, IN `end_timeIN` DATETIME, IN `durationIN` INT, IN `statusIN` ENUM('booked','cancelled','completed'))   INSERT INTO `appointments` (
        `doctor_id`, 
        `patient_id`, 
        `start_time`, 
        `end_time`, 
        `duration`, 
        `status`, 
        `created_at`
)
VALUES (
        doctor_idIN, 
        patient_idIN, 
        start_timeIN, 
        end_timeIN, 
        durationIN, 
        statusIN, 
        NOW()
)$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `addAppointmentWithNotification` (IN `doctor_idIN` INT, IN `patient_idIN` INT, IN `start_timeIN` DATETIME, IN `end_timeIN` DATETIME)   BEGIN
    -- Alapértelmezett értékek: 30 perc időtartam, foglalt státusz
    DECLARE appointmentDuration INT DEFAULT 30;
    DECLARE appointmentStatus ENUM('booked','cancelled','completed') DEFAULT 'booked';

    -- Hiba esetén rollback és hibajelzés
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SELECT 'error' AS status, 'Hiba történt az időpont foglalása során.' AS message;
    END;

    START TRANSACTION;
    
    -- Ellenőrizzük, hogy az adott időintervallumban nincs-e már foglalás az orvosnál.
    IF EXISTS (
        SELECT 1 
        FROM appointments 
        WHERE doctor_id = doctor_idIN
          AND (start_timeIN < end_time AND end_timeIN > start_time)
    ) THEN
        SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Az adott időpont már foglalt.';
    END IF;

    -- Időpont hozzáadása
    INSERT INTO appointments (
        doctor_id, 
        patient_id, 
        start_time, 
        end_time, 
        duration, 
        status, 
        created_at
    ) VALUES (
        doctor_idIN, 
        patient_idIN, 
        start_timeIN, 
        end_timeIN, 
        appointmentDuration, 
        appointmentStatus, 
        NOW()
    );

    -- Új időpont ID lekérdezése
    SET @appointment_id = LAST_INSERT_ID();

    -- Értesítés hozzáadása
    INSERT INTO notifications (
        user_id, 
        message, 
        created_at
    ) VALUES (
        patient_idIN, 
        CONCAT('Időpont foglalva: ', start_timeIN, ' - ', end_timeIN),
        NOW()
    );

    -- Értesítés ID lekérdezése
    SET @notification_id = LAST_INSERT_ID();

    -- Kapcsolat hozzáadása az érintett felhasználóhoz
    INSERT INTO user_notifications (
        notification_id, 
        user_id
    ) VALUES (
        @notification_id, 
        patient_idIN
    );

    COMMIT;
    
    -- Sikeres művelet esetén visszaadunk egy üzenetet és az időpont azonosítóját
    SELECT 'success' AS status, @appointment_id AS appointment_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `addDoctor` (IN `nameIN` VARCHAR(100), IN `emailIN` VARCHAR(100), IN `phone_numberIN` VARCHAR(15), IN `passwordIN` VARCHAR(255), IN `bioIN` TEXT, IN `isAdminIN` INT)   INSERT INTO `doctors` (
        `doctors`.`name`,  
        `doctors`.`email`, 
        `doctors`.`phone_number`, 
        `doctors`.`password`, 
        `doctors`.`bio`,
    	`doctors`.`isAdmin`
)
VALUES(
        nameIN,
        emailIN, 
        phone_numberIN, 
        SHA1(passwordIN), 
        bioIN,
    	isAdminIN
)$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `addPatient` (IN `first_nameIN` VARCHAR(100), IN `last_nameIN` VARCHAR(100), IN `emailIN` VARCHAR(100), IN `phone_numberIN` VARCHAR(15), IN `passwordIN` VARCHAR(255), IN `isAdminIN` BOOLEAN)   INSERT INTO `patients` (
    `patients`.`first_name`, 
    `patients`.`last_name`,
    `patients`.`email`, 
    `patients`.`phone_number`, 
    `patients`.`password`, 
    `patients`.`isAdmin`
)
VALUES(
    first_nameIN,
    last_nameIN,
    emailIN,
    phone_numberIN,
    SHA1(passwordIN),
    isAdminIN
)$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `addPayment` (IN `appointment_idIN` INT, IN `amountIN` INT, IN `payment_methodIN` ENUM('online','in-person'), IN `payment_statusIN` ENUM('paid','pending','failed'))   BEGIN
    INSERT INTO `payments` (
        `appointment_id`, 
        `amount`, 
        `payment_method`, 
        `payment_status`, 
        `created_at`, 
        `updated_at`
    )
    VALUES (
        appointment_idIN, 
        amountIN, 
        payment_methodIN, 
        payment_statusIN, 
        NOW(), 
        NOW()
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `addReminder` (IN `appointment_idIN` INT, IN `reminder_timeIN` DATETIME, IN `reminder_methodIN` ENUM('email','SMS','push'))   BEGIN
    INSERT INTO `reminders` (`appointment_id`, `reminder_time`, `reminder_method`, `sent`, `is_deleted`, `created_at`, `updated_at`)
    VALUES (appointment_idIN, reminder_timeIN, reminder_methodIN, 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `addReview` (IN `doctorIdIN` INT, IN `patientIdIN` INT, IN `ratingIN` INT, IN `reviewTextIN` TEXT)   BEGIN
    -- Ellenőrizzük, hogy az értékelés 1 és 5 között van-e
    IF ratingIN < 1 OR ratingIN > 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid rating value. Must be between 1 and 5.';
    END IF;

    -- Ellenőrizzük, hogy a megadott orvos és páciens létezik-e
    IF NOT EXISTS (SELECT 1 FROM `doctors` WHERE `id` = doctorIdIN AND `is_deleted` = 0) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor not found or deleted.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM `patients` WHERE `id` = patientIdIN AND `is_deleted` = 0) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Patient not found or deleted.';
    END IF;

    -- Értékelés hozzáadása
    INSERT INTO `reviews` (
        `doctor_id`, 
        `patient_id`, 
        `rating`, 
        `review_text`, 
        `created_at`
    )
    VALUES (
        doctorIdIN, 
        patientIdIN, 
        ratingIN, 
        reviewTextIN, 
        CURRENT_TIMESTAMP
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `addSchedule` (IN `doctor_idIN` INT, IN `start_timeIN` DATETIME, IN `end_timeIN` DATETIME, IN `available_slotsIN` INT)   BEGIN
    INSERT INTO `schedules` (
        `doctor_id`, 
        `start_time`, 
        `end_time`, 
        `available_slots`, 
        `created_at`, 
        `updated_at`
    )
    VALUES (
        doctor_idIN, 
        start_timeIN, 
        end_timeIN, 
        available_slotsIN, 
        NOW(), 
        NOW()
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `addService` (IN `nameIN` VARCHAR(100), IN `descriptionIN` TEXT, IN `priceIN` INT, IN `durationIN` INT)   BEGIN
    INSERT INTO `services` (
        `name`, 
        `description`, 
        `price`, 
        `duration`, 
        `created_at`, 
        `updated_at`
    )
    VALUES (
        nameIN, 
        descriptionIN, 
        priceIN, 
        durationIN, 
        NOW(), 
        NOW()
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `cancelAppointment` (IN `idIN` INT, IN `patientIdIN` INT)   BEGIN
    DECLARE affectedRows INT;

    -- Időpont frissítése
    UPDATE `appointments` 
    SET 
        `is_deleted` = 1,
        `status` = 'cancelled',
        `deleted_at` = NOW()
    WHERE 
        `id` = idIN 
        AND `status` = 'booked'
        AND `patient_id` = patientIdIN;

    SET affectedRows = ROW_COUNT();

    IF affectedRows = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Nem található időpont vagy érvénytelen művelet.';
    ELSE
        -- Visszaadjuk a részleteket
        SELECT 
            a.id AS appointment_id,
            a.start_time,
            a.end_time,
            d.name AS doctor_name,
            p.email AS patient_email,
            p.first_name AS patient_first_name,
            p.last_name AS patient_last_name,
            GROUP_CONCAT(s.name SEPARATOR ', ') AS services
        FROM appointments a
        JOIN doctors d ON a.doctor_id = d.id
        JOIN patients p ON a.patient_id = p.id
        LEFT JOIN doctors_X_services ds ON d.id = ds.doctor_id
        LEFT JOIN services s ON ds.service_id = s.id
        WHERE a.id = idIN
        GROUP BY a.id;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `changePassword` (IN `patientIdIN` INT(11), IN `newPasswordIN` VARCHAR(255), IN `creatorIN` INT(11))   BEGIN

IF creatorIN = patientIdIN THEN
	UPDATE `patients`
    SET `patients`.`password` = SHA1(newPasswordIN),
    	`patients`.`updated_at` = NOW()
    WHERE `patients`.`id` = patientIdIN;
ELSE
	SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nincs jogosultságod ehhez!';
END IF;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CreatePasswordResetToken` (IN `p_email` VARCHAR(255), IN `p_token` VARCHAR(255), IN `p_expires_at` DATETIME)   BEGIN
    INSERT INTO password_reset_tokens (email, token, expires_at)
    VALUES (p_email, p_token, p_expires_at);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `deleteDoctor` (IN `idIN` INT)   BEGIN
    UPDATE `doctors` 
    SET 
        `doctors`.`is_deleted` = 1,
        `doctors`.`deleted_at` = NOW()
    WHERE `doctors`.`id` = idIN;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `deletePatient` (IN `patientIdIN` INT)   BEGIN
    UPDATE `patients`
    SET 
        `patients`.`is_deleted` = 1,             -- Megjelöli, hogy törölve lett
        `patients`.`deleted_at` = NOW(),         -- Beállítja a törlés dátumát
        `patients`.`updated_at` = NOW()          -- Frissíti az utolsó módosítás dátumát
    WHERE `patients`.`id` = patientIdIN;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `deletePayment` (IN `idIN` INT)   BEGIN
    UPDATE `payments` 
    SET 
        `is_deleted` = 1,
        `deleted_at` = NOW()
    WHERE `id` = idIN;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `deleteReminder` (IN `idIN` INT)   BEGIN
    UPDATE `reminders`
    SET `is_deleted` = 1,
        `deleted_at` = CURRENT_TIMESTAMP,
        `updated_at` = CURRENT_TIMESTAMP
    WHERE `id` = idIN;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `deleteReview` (IN `idIN` INT)   BEGIN
    UPDATE `reviews` 
    SET 
        `is_deleted` = 1,
        `deleted_at` = NOW()
    WHERE `id` = idIN;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `deleteSchedule` (IN `idIN` INT)   BEGIN
    UPDATE `schedules` 
    SET 
        `is_deleted` = 1,
        `deleted_at` = NOW()
    WHERE `id` = idIN;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `deleteService` (IN `idIN` INT)   BEGIN
    UPDATE `services` 
    SET 
        `is_deleted` = 1,
        `deleted_at` = NOW()
    WHERE `id` = idIN;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllAppointments` ()   SELECT * 
FROM `appointments` 
WHERE `appointments`.`is_deleted` = 0$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllDoctors` ()   BEGIN
    SELECT 
    `doctors`.`id`, 
    `doctors`.`name`,
    `doctors`.`email`, 
    `doctors`.`phone_number`,
    `doctors`.`bio` 
    FROM `doctors` 
    WHERE `doctors`.`is_deleted` = 0;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllPatients` ()   BEGIN
    SELECT * FROM `patients`;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllPayments` ()   SELECT * 
FROM `payments` 
WHERE `payments`.`is_deleted` = 0$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllReminders` ()   BEGIN
    SELECT * FROM `reminders`
    WHERE `is_deleted` = 0;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllReviews` ()   BEGIN
    SELECT * FROM `reviews`;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllSchedules` ()   BEGIN
    SELECT * 
    FROM `schedules` 
    WHERE `schedules`.`is_deleted` = 0;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllServices` ()   BEGIN
    SELECT 
        s.id,
        s.name,
        s.description,
        s.price,
        s.duration,
        -- Ha több orvos is kapcsolódik egy szolgáltatáshoz, a GROUP_CONCAT egy sorban összefűzi őket
        GROUP_CONCAT(d.name SEPARATOR ', ') AS doctor_names
    FROM services s
    LEFT JOIN doctors_x_services d_x_s ON s.id = d_x_s.service_id
    LEFT JOIN doctors d ON d_x_s.doctor_id = d.id
    WHERE s.is_deleted = 0
    GROUP BY s.id, s.name, s.description, s.price, s.duration;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getAppointmentById` (IN `idIN` INT)   BEGIN
    SELECT 
        a.id AS appointment_id,
        a.doctor_id,
        a.patient_id,
        a.start_time,
        a.end_time,
        a.status,
        d.name AS doctor_name,
        CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
        s.name AS service_name
    FROM 
        appointments a
    JOIN doctors d ON a.doctor_id = d.id
    JOIN patients p ON a.patient_id = p.id
    JOIN doctors_x_services dxs ON d.id = dxs.doctor_id
    JOIN services s ON dxs.service_id = s.id
    WHERE 
        a.is_deleted = 0 
        AND a.id = idIN;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getAvailableSlots` ()   BEGIN
    DROP TEMPORARY TABLE IF EXISTS TimeSlots;
    
    CREATE TEMPORARY TABLE TimeSlots AS
    SELECT 
        dwh.doctor_id,
        TIMESTAMP(CURDATE() + INTERVAL td.day_offset DAY, dwh.start_time) + INTERVAL (n.x * dwh.slot_duration) MINUTE AS slot_start,
        TIMESTAMP(CURDATE() + INTERVAL td.day_offset DAY, dwh.start_time) + INTERVAL ((n.x + 1) * dwh.slot_duration) MINUTE AS slot_end
    FROM doctor_working_hours dwh
    JOIN doctors d 
      ON dwh.doctor_id = d.id AND d.is_deleted = 0
    CROSS JOIN (
        SELECT a.n + b.n * 10 AS day_offset
        FROM (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
              UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
              UNION ALL SELECT 8 UNION ALL SELECT 9) a
        CROSS JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) b
        WHERE a.n + b.n * 10 <= 30
    ) td
    JOIN (
        SELECT 0 AS x UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
        UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
        UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
        UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
        UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
        UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
    ) n 
      ON TIMESTAMP(CURDATE() + INTERVAL td.day_offset DAY, dwh.start_time) + INTERVAL ((n.x + 1) * dwh.slot_duration) MINUTE 
         <= TIMESTAMP(CURDATE() + INTERVAL td.day_offset DAY, dwh.end_time)
    WHERE dwh.is_active = 1
      AND dwh.day_of_week = (WEEKDAY(CURDATE() + INTERVAL td.day_offset DAY) + 1);

    SELECT 
        ts.slot_start, 
        ts.slot_end, 
        ts.doctor_id, 
        d.name AS doctor_name,
        dxs.service_id,
        ser.name AS service_name
    FROM TimeSlots ts
    LEFT JOIN appointments a
      ON ts.doctor_id = a.doctor_id
      AND ts.slot_start < a.end_time
      AND ts.slot_end > a.start_time
      AND a.status <> 'cancelled'
      AND a.is_deleted = 0
    LEFT JOIN doctors_x_services dxs
      ON ts.doctor_id = dxs.doctor_id
    LEFT JOIN services ser
      ON dxs.service_id = ser.id AND ser.is_deleted = 0
    LEFT JOIN doctors d
      ON ts.doctor_id = d.id
    WHERE a.id IS NULL
      AND ts.slot_start > NOW()
    ORDER BY ts.slot_start, ts.doctor_id;
    
    DROP TEMPORARY TABLE IF EXISTS TimeSlots;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getAvailableSlotsByDoctor` (IN `doctorIdIN` INT)   BEGIN
    DROP TEMPORARY TABLE IF EXISTS TimeSlots;
    
    CREATE TEMPORARY TABLE TimeSlots AS
    SELECT 
        dwh.doctor_id,
        TIMESTAMP(CURDATE() + INTERVAL td.day_offset DAY, dwh.start_time) + INTERVAL (n.x * dwh.slot_duration) MINUTE AS slot_start,
        TIMESTAMP(CURDATE() + INTERVAL td.day_offset DAY, dwh.start_time) + INTERVAL ((n.x + 1) * dwh.slot_duration) MINUTE AS slot_end
    FROM doctor_working_hours dwh
    JOIN doctors d 
      ON dwh.doctor_id = d.id AND d.is_deleted = 0
    CROSS JOIN (
        SELECT a.n + b.n * 10 AS day_offset
        FROM (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
              UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
              UNION ALL SELECT 8 UNION ALL SELECT 9) a
        CROSS JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) b
        WHERE a.n + b.n * 10 <= 30
    ) td
    JOIN (
        SELECT 0 AS x UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
        UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
        UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
        UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
        UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
        UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
    ) n 
      ON TIMESTAMP(CURDATE() + INTERVAL td.day_offset DAY, dwh.start_time) + INTERVAL ((n.x + 1) * dwh.slot_duration) MINUTE 
         <= TIMESTAMP(CURDATE() + INTERVAL td.day_offset DAY, dwh.end_time)
    WHERE dwh.is_active = 1
      AND dwh.doctor_id = doctorIdIN
      AND dwh.day_of_week = (WEEKDAY(CURDATE() + INTERVAL td.day_offset DAY) + 1);

    SELECT 
        ts.slot_start, 
        ts.slot_end, 
        ts.doctor_id, 
        d.name AS doctor_name,
        dxs.service_id,
        ser.name AS service_name
    FROM TimeSlots ts
    LEFT JOIN appointments a
      ON ts.doctor_id = a.doctor_id
      AND ts.slot_start < a.end_time
      AND ts.slot_end > a.start_time
      AND a.status <> 'cancelled'
      AND a.is_deleted = 0
    LEFT JOIN doctors_x_services dxs
      ON ts.doctor_id = dxs.doctor_id
    LEFT JOIN services ser
      ON dxs.service_id = ser.id AND ser.is_deleted = 0
    LEFT JOIN doctors d
      ON ts.doctor_id = d.id
    WHERE a.id IS NULL
      AND ts.slot_start > NOW()
    ORDER BY ts.slot_start;
    
    DROP TEMPORARY TABLE IF EXISTS TimeSlots;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getAvailableSlotsByService` (IN `serviceIdIN` INT)   BEGIN
    DROP TEMPORARY TABLE IF EXISTS TimeSlots;
    
    CREATE TEMPORARY TABLE TimeSlots AS
    SELECT 
        dwh.doctor_id,
        TIMESTAMP(CURDATE() + INTERVAL td.day_offset DAY, dwh.start_time) + INTERVAL (n.x * dwh.slot_duration) MINUTE AS slot_start,
        TIMESTAMP(CURDATE() + INTERVAL td.day_offset DAY, dwh.start_time) + INTERVAL ((n.x + 1) * dwh.slot_duration) MINUTE AS slot_end
    FROM doctor_working_hours dwh
    JOIN doctors_x_services dxs_filter 
      ON dwh.doctor_id = dxs_filter.doctor_id AND dxs_filter.service_id = serviceIdIN
    JOIN doctors d 
      ON dwh.doctor_id = d.id AND d.is_deleted = 0
    CROSS JOIN (
        SELECT a.n + b.n * 10 AS day_offset
        FROM (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
              UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
              UNION ALL SELECT 8 UNION ALL SELECT 9) a
        CROSS JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) b
        WHERE a.n + b.n * 10 <= 30
    ) td
    JOIN (
        SELECT 0 AS x UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
        UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
        UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
        UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
        UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
        UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
    ) n 
      ON TIMESTAMP(CURDATE() + INTERVAL td.day_offset DAY, dwh.start_time) + INTERVAL ((n.x + 1) * dwh.slot_duration) MINUTE 
         <= TIMESTAMP(CURDATE() + INTERVAL td.day_offset DAY, dwh.end_time)
    WHERE dwh.is_active = 1
      AND dwh.day_of_week = (WEEKDAY(CURDATE() + INTERVAL td.day_offset DAY) + 1);

    SELECT 
        ts.slot_start, 
        ts.slot_end, 
        ts.doctor_id,
        d.name AS doctor_name,
        dxs.service_id,
        ser.name AS service_name
    FROM TimeSlots ts
    LEFT JOIN appointments a
      ON ts.doctor_id = a.doctor_id
      AND ts.slot_start < a.end_time
      AND ts.slot_end > a.start_time
      AND a.status <> 'cancelled'
      AND a.is_deleted = 0
    LEFT JOIN doctors d
      ON ts.doctor_id = d.id
    LEFT JOIN doctors_x_services dxs
      ON ts.doctor_id = dxs.doctor_id AND dxs.service_id = serviceIdIN
    LEFT JOIN services ser
      ON dxs.service_id = ser.id AND ser.is_deleted = 0
    WHERE a.id IS NULL
      AND ts.slot_start > NOW()
    ORDER BY ts.slot_start;
    
    DROP TEMPORARY TABLE IF EXISTS TimeSlots;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getBookedAppointments` ()   BEGIN
    SELECT 
        a.id AS appointment_id,
        a.doctor_id,
        a.patient_id,
        a.start_time,
        a.end_time,
        a.status,
        d.name AS doctor_name,
        CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
        s.name AS service_name
    FROM 
        appointments a
    JOIN doctors d ON a.doctor_id = d.id
    JOIN patients p ON a.patient_id = p.id
    JOIN doctors_x_services dxs ON d.id = dxs.doctor_id
    JOIN services s ON dxs.service_id = s.id
    WHERE 
        a.is_deleted = 0 
        AND a.status = 'booked';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getDoctorById` (IN `idIN` INT)   BEGIN
    SELECT * 
    FROM `doctors` 
    WHERE `doctors`.`id` = idIN AND `doctors`.`is_deleted` = 0;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getPatientById` (IN `patientIdIN` INT)   BEGIN
    SELECT * FROM `patients`
    WHERE `patients`.`id` = patientIdIN;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getPaymentById` (IN `idIN` INT)   BEGIN
    SELECT * FROM `payments`
    WHERE `id` = idIN AND `is_deleted` = 0;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getReminderById` (IN `idIN` INT)   BEGIN
    SELECT * FROM `reminders`
    WHERE `id` = idIN AND `is_deleted` = 0;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getReviewsByDoctorId` (IN `doctorIdIN` INT)   BEGIN
    SELECT 
        r.id,
        r.doctor_id,
        r.patient_id,
        r.rating,
        r.review_text,
        r.created_at,
        d.name AS doctor_name,
    	CONCAT(p.first_name, ' ', p.last_name) AS patient_name
    FROM 
        reviews r
	JOIN doctors d ON r.doctor_id = d.id
	JOIN patients p ON r.patient_id = p.id
    WHERE 
        r.doctor_id = doctorIdIN AND r.is_deleted = 0
    ORDER BY 
        r.created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getScheduleById` (IN `idIN` INT)   BEGIN
    SELECT * FROM `schedules`
    WHERE `id` = idIN AND `is_deleted` = 0;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getServiceById` (IN `idIN` INT)   BEGIN
    SELECT * FROM `services`
    WHERE `id` = idIN AND `is_deleted` = 0;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `isDoctorExists` (IN `emailIN` VARCHAR(100), OUT `resultOUT` BOOLEAN)   SET resultOUT = EXISTS(
    SELECT `doctors`.`id` 
    FROM `doctors`
    WHERE `doctors`.`email` = emailIN
)$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `isPatientExists` (IN `emailIN` VARCHAR(100), OUT `resultOUT` BOOLEAN)   SET resultOUT = EXISTS(
    SELECT `patients`.`id` 
    FROM `patients`
    WHERE `patients`.`email` = emailIN
)$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `login` (IN `emailIN` VARCHAR(100), IN `passwordIN` VARCHAR(255))   BEGIN
    SELECT 
        'patient' AS userType, 
        id, 
        email, 
        isAdmin 
    FROM Patients 
    WHERE email = emailIN AND password = SHA1(passwordIN)
    
    UNION ALL
    
    SELECT 
        'doctor' AS userType, 
        id, 
        email, 
        isAdmin 
    FROM Doctors 
    WHERE email = emailIN AND password = SHA1(passwordIN);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `loginDoctor` (IN `emailIN` VARCHAR(100), IN `passwordIN` VARCHAR(255))   select * from doctors where doctors.email = emailIN and doctors.password = SHA1(passwordIN)$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `loginPatient` (IN `emailIN` VARCHAR(100), IN `passwordIN` VARCHAR(255))   select * from patients where patients.email = emailIN and patients.password = SHA1(passwordIN)$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `registerDoctor` (IN `nameIN` VARCHAR(100), IN `emailIN` VARCHAR(100), IN `phoneNumberIN` VARCHAR(15), IN `passwordIN` TEXT, IN `bioIN` TEXT)   INSERT INTO `doctors` (
    `name`,
    `email`,
    `phone_number`,
    `password`,
    `bio`,
    `isAdmin`
) VALUES (
    nameIN,
    emailIN,
    phoneNumberIN,
    SHA1(passwordIN),
    bioIN,
    1
)$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `registerPatient` (IN `firstNameIN` VARCHAR(100), IN `lastNameIN` VARCHAR(100), IN `emailIN` VARCHAR(100), IN `phoneNumberIN` VARCHAR(15), IN `passwordIN` TEXT)   INSERT INTO `patients` (
	`patients`.`first_name`,
    `patients`.`last_name`,
    `patients`.`email`,
    `patients`.`phone_number`,
    `patients`.`password`,
    `patients`.`isAdmin`
) VALUES(
    firstNameIN,
    lastNameIN,
    emailIN,
    phoneNumberIN,
    SHA1(passwordIN),
    0
)$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `updateAppointment` (IN `appointmentIdIN` INT, IN `doctorIdIN` INT, IN `patientIdIN` INT, IN `startTimeIN` DATETIME, IN `endTimeIN` DATETIME, IN `statusIN` ENUM('booked','cancelled','completed',''), IN `durationIN` INT)   BEGIN
    IF (SELECT COUNT(*) FROM appointments WHERE id = appointmentIdIN AND is_deleted = 0) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment not found or already deleted';
    ELSE
        UPDATE appointments
        SET
            doctor_id = COALESCE(doctorIdIN, doctor_id),
            patient_id = COALESCE(patientIdIN, patient_id),
            start_time = COALESCE(startTimeIN, start_time),
            end_time = COALESCE(endTimeIN, end_time),
            status = COALESCE(statusIN, status),
            duration = COALESCE(durationIN, duration),
            updated_at = NOW()
        WHERE id = appointmentIdIN;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `updateDoctor` (IN `idIN` INT, IN `nameIN` VARCHAR(200), IN `emailIN` VARCHAR(100), IN `phone_numberIN` VARCHAR(15), IN `bioIN` TEXT, IN `passwordIN` VARCHAR(255))   BEGIN
    UPDATE `doctors` 
    SET 
        `doctors`.`name` = nameIN,
        `doctors`.`email` = emailIN,
        `doctors`.`phone_number` = phone_numberIN,
        `doctors`.`bio` = bioIN,
        `doctors`.`password` = SHA1(passwordIN),
        `doctors`.`updated_at` = NOW()
    WHERE `doctors`.`id` = idIN AND `doctors`.`is_deleted` = 0;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `updatePatient` (IN `patientIdIN` INT, IN `first_nameIN` VARCHAR(100), IN `last_nameIN` VARCHAR(100), IN `emailIN` VARCHAR(100), IN `phone_numberIN` VARCHAR(15), IN `passwordIN` VARCHAR(255), IN `isAdminIN` BOOLEAN)   BEGIN
    UPDATE `patients`
    SET 
        `patients`.`first_name` = first_nameIN, 
        `patients`.`last_name` = last_nameIN,
        `patients`.`email` = emailIN, 
        `patients`.`phone_number` = phone_numberIN,
        `patients`.`password` = SHA1(passwordIN), 
        `patients`.`isAdmin` = isAdminIN,
        `patients`.`updated_at` = NOW()
    WHERE `patients`.`id` = patientIdIN;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `updatePayment` (IN `idIN` INT, IN `appointment_idIN` INT, IN `amountIN` INT, IN `payment_methodIN` ENUM('online','in-person'), IN `payment_statusIN` ENUM('paid','pending','failed'))   BEGIN
    UPDATE `payments` 
    SET 
        `appointment_id` = appointment_idIN,
        `amount` = amountIN,
        `payment_method` = payment_methodIN,
        `payment_status` = payment_statusIN,
        `updated_at` = NOW()
    WHERE `id` = idIN AND `is_deleted` = 0;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `updateReminder` (IN `idIN` INT, IN `reminder_timeIN` DATETIME, IN `reminder_methodIN` ENUM('email','SMS','push'), IN `sentIN` TINYINT)   BEGIN
    UPDATE `reminders`
    SET `reminder_time` = reminder_timeIN,
        `reminder_method` = reminder_methodIN,
        `sent` = sentIN,
        `updated_at` = CURRENT_TIMESTAMP
    WHERE `id` = idIN AND `is_deleted` = 0;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `updateReview` (IN `idIN` INT, IN `ratingIN` TINYINT, IN `review_textIN` TEXT)   BEGIN
    UPDATE `reviews`
    SET `rating` = ratingIN,
        `review_text` = review_textIN,
        `updated_at` = CURRENT_TIMESTAMP
    WHERE `id` = idIN;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `updateSchedule` (IN `idIN` INT, IN `doctor_idIN` INT, IN `start_timeIN` DATETIME, IN `end_timeIN` DATETIME, IN `available_slotsIN` INT)   BEGIN
    UPDATE `schedules` 
    SET 
        `doctor_id` = doctor_idIN,
        `start_time` = start_timeIN,
        `end_time` = end_timeIN,
        `available_slots` = available_slotsIN,
        `updated_at` = NOW()
    WHERE `id` = idIN AND `is_deleted` = 0;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `updateService` (IN `idIN` INT, IN `nameIN` VARCHAR(100), IN `descriptionIN` TEXT, IN `priceIN` INT, IN `durationIN` INT)   BEGIN
    UPDATE `services` 
    SET 
        `name` = nameIN,
        `description` = descriptionIN,
        `price` = priceIN,
        `duration` = durationIN,
        `updated_at` = NOW()
    WHERE `id` = idIN AND `is_deleted` = 0;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `appointments`
--

CREATE TABLE `appointments` (
  `id` int(11) NOT NULL,
  `doctor_id` int(11) NOT NULL,
  `patient_id` int(11) NOT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  `duration` int(11) NOT NULL,
  `status` enum('booked','cancelled','completed','') NOT NULL,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  `doctorName` varchar(255) DEFAULT NULL,
  `patientName` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `appointments`
--

INSERT INTO `appointments` (`id`, `doctor_id`, `patient_id`, `start_time`, `end_time`, `duration`, `status`, `is_deleted`, `created_at`, `updated_at`, `deleted_at`, `doctorName`, `patientName`) VALUES
(1, 1, 1, '2025-01-22 10:00:00', '2025-01-22 11:00:00', 60, 'booked', 0, '2024-09-29 18:07:01', '2025-01-22 14:47:59', NULL, NULL, NULL),
(2, 2, 2, '2024-10-02 10:00:00', '2024-10-02 10:30:00', 30, 'booked', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(3, 3, 3, '2024-10-03 11:00:00', '2024-10-03 11:30:00', 30, 'cancelled', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(4, 4, 4, '2024-10-04 12:00:00', '2024-10-04 12:30:00', 30, 'completed', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(5, 5, 5, '2024-10-05 13:00:00', '2024-10-05 13:30:00', 30, 'cancelled', 1, '2024-09-29 18:07:01', '2024-09-29 18:07:01', '2025-01-21 17:17:46', NULL, NULL),
(6, 6, 6, '2024-10-06 14:00:00', '2024-10-06 14:30:00', 30, 'booked', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(7, 7, 7, '2024-10-07 15:00:00', '2024-10-07 15:30:00', 30, 'cancelled', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(8, 8, 8, '2024-10-08 16:00:00', '2024-10-08 16:30:00', 30, 'completed', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(9, 9, 9, '2024-10-09 17:00:00', '2024-10-09 17:30:00', 30, 'booked', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(10, 10, 10, '2024-10-10 18:00:00', '2024-10-10 18:30:00', 30, 'booked', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(11, 11, 11, '2024-10-11 09:00:00', '2024-10-11 09:30:00', 30, 'completed', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(12, 12, 12, '2024-10-12 10:00:00', '2024-10-12 10:30:00', 30, 'booked', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(13, 13, 13, '2024-10-13 11:00:00', '2024-10-13 11:30:00', 30, 'cancelled', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(14, 14, 14, '2024-10-14 12:00:00', '2024-10-14 12:30:00', 30, 'completed', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(15, 15, 15, '2024-10-15 13:00:00', '2024-10-15 13:30:00', 30, 'booked', 0, '2024-09-29 18:07:01', '2024-09-29 18:07:01', NULL, NULL, NULL),
(16, 10, 5, '2024-11-04 15:00:00', '2024-11-04 15:20:00', 20, 'cancelled', 1, '2024-11-04 11:45:06', '2024-11-04 11:50:35', '2024-11-04 11:52:17', NULL, NULL),
(17, 16, 5, '2024-11-04 15:00:00', '2024-11-04 16:20:00', 80, 'booked', 0, '2025-01-14 13:01:40', '2025-01-14 13:01:40', NULL, NULL, NULL),
(18, 1, 2, '2025-01-15 10:00:00', '2025-01-15 11:00:00', 60, 'cancelled', 1, '2025-01-14 14:39:56', '2025-01-14 14:39:56', '2025-01-21 15:15:13', NULL, NULL),
(19, 1, 2, '2025-01-15 10:00:00', '2025-01-15 11:00:00', 60, 'booked', 0, '2025-01-14 14:49:40', '2025-01-14 14:49:40', NULL, NULL, NULL),
(20, 5, 7, '2025-03-14 08:00:00', '2025-03-14 08:30:00', 30, 'booked', 0, '2025-03-06 10:42:54', '2025-03-06 10:42:54', NULL, NULL, NULL),
(21, 1, 11, '2024-10-01 10:00:00', '2024-10-01 10:30:00', 30, 'cancelled', 1, '2025-03-06 11:24:48', '2025-03-06 11:24:48', '2025-03-21 14:25:10', NULL, NULL),
(22, 1, 12, '2024-10-01 15:00:00', '2024-10-01 15:30:00', 30, 'booked', 0, '2025-03-06 11:30:38', '2025-03-06 11:30:38', NULL, NULL, NULL),
(23, 1, 12, '2024-10-01 15:30:00', '2024-10-01 16:00:00', 30, 'booked', 0, '2025-03-06 16:10:34', '2025-03-06 16:10:34', NULL, NULL, NULL),
(24, 16, 7, '2024-10-01 15:30:00', '2024-10-01 16:00:00', 30, 'booked', 1, '2025-03-06 16:12:55', '2025-03-06 16:12:55', NULL, NULL, NULL),
(25, 12, 9, '2025-02-28 09:00:00', '2025-02-28 09:30:00', 30, 'cancelled', 1, '2025-03-07 12:48:55', '2025-03-07 12:48:55', '2025-03-19 12:31:52', NULL, NULL),
(26, 12, 9, '2025-02-28 09:30:00', '2025-02-28 10:00:00', 30, 'booked', 0, '2025-03-07 12:59:56', '2025-03-07 12:59:56', NULL, NULL, NULL),
(27, 12, 9, '2025-02-28 10:30:00', '2025-02-28 11:00:00', 30, 'booked', 0, '2025-03-07 13:03:52', '2025-03-07 13:03:52', NULL, NULL, NULL),
(28, 12, 47, '2025-02-28 11:00:00', '2025-02-28 11:30:00', 30, 'cancelled', 1, '2025-03-07 15:39:00', '2025-03-07 15:39:00', '2025-03-19 12:28:58', NULL, NULL),
(29, 12, 47, '2025-02-28 13:00:00', '2025-02-28 13:30:00', 30, 'cancelled', 1, '2025-03-07 15:56:02', '2025-03-07 15:56:02', '2025-03-21 09:28:26', NULL, NULL),
(30, 12, 47, '2025-02-28 15:00:00', '2025-02-28 15:30:00', 30, 'cancelled', 1, '2025-03-10 14:03:15', '2025-03-10 14:03:15', '2025-03-21 12:33:22', NULL, NULL),
(31, 12, 47, '2025-02-28 15:30:00', '2025-02-28 16:00:00', 30, 'cancelled', 1, '2025-03-10 14:19:32', '2025-03-10 14:19:32', '2025-03-19 11:53:06', NULL, NULL),
(32, 14, 47, '2025-02-14 09:00:00', '2025-02-14 09:30:00', 30, 'cancelled', 1, '2025-03-10 14:21:07', '2025-03-10 14:21:07', '2025-03-19 14:35:08', NULL, NULL),
(33, 12, 47, '2025-02-12 07:00:00', '2025-02-12 07:30:00', 30, 'cancelled', 1, '2025-03-10 14:46:22', '2025-03-10 14:46:22', '2025-03-11 12:52:15', NULL, NULL),
(34, 12, 47, '2025-02-12 12:00:00', '2025-02-12 12:30:00', 30, 'cancelled', 1, '2025-03-11 12:53:15', '2025-03-11 12:53:15', '2025-03-19 14:25:19', NULL, NULL),
(36, 7, 47, '2025-02-23 16:00:00', '2025-02-23 16:30:00', 30, 'cancelled', 1, '2025-03-12 11:44:41', '2025-03-12 11:44:41', '2025-03-19 14:22:26', NULL, NULL),
(37, 13, 47, '2025-02-13 10:00:00', '2025-02-13 10:30:00', 30, 'booked', 0, '2025-03-13 12:23:58', '2025-03-13 12:23:58', NULL, NULL, NULL),
(38, 12, 47, '2025-02-12 11:00:00', '2025-02-12 11:30:00', 30, 'booked', 0, '2025-03-19 14:33:41', '2025-03-19 14:33:41', NULL, NULL, NULL),
(39, 12, 47, '2025-02-12 14:00:00', '2025-02-12 14:30:00', 30, 'cancelled', 1, '2025-03-19 14:34:14', '2025-03-19 14:34:14', '2025-03-21 12:39:59', NULL, NULL),
(40, 10, 47, '2025-02-26 15:30:00', '2025-02-26 16:00:00', 30, 'cancelled', 1, '2025-03-19 14:38:03', '2025-03-19 14:38:03', '2025-03-21 12:52:10', NULL, NULL),
(41, 9, 2, '2025-02-25 16:00:00', '2025-02-25 16:30:00', 30, 'cancelled', 1, '2025-03-19 14:47:28', '2025-03-19 14:47:28', '2025-03-19 14:47:54', NULL, NULL),
(42, 8, 47, '2025-02-24 14:00:00', '2025-02-24 14:30:00', 30, 'cancelled', 1, '2025-03-20 13:05:36', '2025-03-20 13:05:36', '2025-03-20 13:10:26', NULL, NULL),
(43, 8, 47, '2025-02-24 15:00:00', '2025-02-24 15:30:00', 30, 'cancelled', 1, '2025-03-21 09:34:21', '2025-03-21 09:34:21', '2025-03-21 11:34:00', NULL, NULL),
(44, 9, 1, '2025-02-25 12:00:00', '2025-02-25 12:30:00', 30, 'cancelled', 1, '2025-03-21 11:37:15', '2025-03-21 11:37:15', '2025-03-21 11:37:46', NULL, NULL),
(45, 9, 1, '2025-02-25 10:00:00', '2025-02-25 10:30:00', 30, 'cancelled', 1, '2025-03-21 11:43:21', '2025-03-21 11:43:21', '2025-03-21 11:44:37', NULL, NULL),
(46, 7, 1, '2025-02-23 16:30:00', '2025-02-23 17:00:00', 30, 'cancelled', 1, '2025-03-21 12:26:08', '2025-03-21 12:26:08', '2025-03-21 12:27:14', NULL, NULL),
(47, 12, 47, '2025-02-28 13:30:00', '2025-02-28 14:00:00', 30, 'cancelled', 1, '2025-03-21 12:28:45', '2025-03-21 12:28:45', '2025-03-21 12:30:31', NULL, NULL),
(48, 11, 47, '2025-02-27 15:00:00', '2025-02-27 15:30:00', 30, 'cancelled', 1, '2025-03-21 12:37:31', '2025-03-21 12:37:31', '2025-03-21 12:37:49', NULL, NULL),
(49, 10, 47, '2025-02-26 10:30:00', '2025-02-26 11:00:00', 30, 'cancelled', 1, '2025-03-21 12:50:41', '2025-03-21 12:50:41', '2025-03-21 12:51:22', NULL, NULL),
(50, 11, 47, '2025-02-27 11:00:00', '2025-02-27 11:30:00', 30, 'cancelled', 1, '2025-03-21 14:37:11', '2025-03-21 14:37:11', '2025-03-21 14:38:49', NULL, NULL),
(51, 6, 47, '2025-02-06 15:00:00', '2025-02-06 15:30:00', 30, 'cancelled', 1, '2025-03-21 14:40:50', '2025-03-21 14:40:50', '2025-03-21 14:41:16', NULL, NULL),
(52, 2, 47, '2025-02-02 15:00:00', '2025-02-02 15:30:00', 30, 'booked', 0, '2025-03-24 12:52:43', '2025-03-24 12:52:43', NULL, NULL, NULL),
(53, 9, 47, '2025-02-25 16:30:00', '2025-02-25 17:00:00', 30, 'cancelled', 1, '2025-03-24 13:31:49', '2025-03-24 13:31:49', '2025-03-24 13:32:17', NULL, NULL),
(54, 10, 47, '2025-02-26 16:30:00', '2025-02-26 17:00:00', 30, 'cancelled', 1, '2025-03-25 12:01:40', '2025-03-25 12:01:40', '2025-03-25 12:06:10', NULL, NULL),
(55, 14, 1, '2025-02-14 13:00:00', '2025-02-14 13:30:00', 30, 'cancelled', 1, '2025-03-31 17:02:11', '2025-03-31 17:02:11', '2025-03-31 17:05:42', NULL, NULL),
(56, 14, 47, '2025-02-14 16:30:00', '2025-02-14 17:00:00', 30, 'cancelled', 1, '2025-04-01 15:43:25', '2025-04-01 15:43:25', '2025-04-01 15:43:53', NULL, NULL),
(57, 11, 47, '2025-04-22 12:30:00', '2025-04-22 13:00:00', 30, 'cancelled', 1, '2025-04-03 10:00:17', '2025-04-03 10:00:17', '2025-04-03 10:00:56', NULL, NULL),
(58, 8, 47, '2025-04-16 18:00:00', '2025-04-16 18:30:00', 30, 'cancelled', 1, '2025-04-03 12:49:14', '2025-04-03 12:49:14', '2025-04-03 13:54:36', NULL, NULL),
(59, 14, 47, '2025-04-28 08:00:00', '2025-04-28 08:30:00', 30, 'cancelled', 1, '2025-04-06 18:46:49', '2025-04-06 18:46:49', '2025-04-06 18:47:32', NULL, NULL),
(60, 12, 47, '2025-04-24 15:00:00', '2025-04-24 15:30:00', 30, 'cancelled', 1, '2025-04-06 18:56:10', '2025-04-06 18:56:10', '2025-04-06 18:56:45', NULL, NULL),
(61, 5, 47, '2025-04-10 12:30:00', '2025-04-10 13:00:00', 30, 'booked', 0, '2025-04-07 10:06:54', '2025-04-07 10:06:54', NULL, NULL, NULL),
(62, 9, 47, '2025-04-18 11:00:00', '2025-04-18 11:30:00', 30, 'cancelled', 1, '2025-04-07 10:10:44', '2025-04-07 10:10:44', '2025-04-08 11:53:29', NULL, NULL),
(63, 12, 71, '2025-04-24 13:30:00', '2025-04-24 14:00:00', 30, 'cancelled', 1, '2025-04-14 13:32:20', '2025-04-14 13:32:20', '2025-04-14 13:32:35', NULL, NULL),
(64, 5, 71, '2025-05-11 08:00:00', '2025-05-11 08:30:00', 30, 'cancelled', 1, '2025-04-14 13:50:47', '2025-04-14 13:50:47', '2025-04-14 13:51:47', NULL, NULL),
(65, 5, 73, '2025-05-11 09:30:00', '2025-05-11 10:00:00', 30, 'booked', 0, '2025-04-14 13:58:05', '2025-04-14 13:58:05', NULL, NULL, NULL);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `doctors`
--

CREATE TABLE `doctors` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL,
  `phone_number` varchar(15) NOT NULL,
  `password` varchar(255) NOT NULL,
  `bio` text,
  `isAdmin` tinyint(1) NOT NULL,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `doctors`
--

INSERT INTO `doctors` (`id`, `name`, `email`, `phone_number`, `password`, `bio`, `isAdmin`, `is_deleted`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 'Dr. Szabó Ferenc', 'ferenc.szabo@example.com', '06301110000', 'drferenc123', 'Ortopéd specialista, 20 év tapasztalattal.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(2, 'Dr. Nagy István', 'istvan.nagy@example.com', '06302221111', 'dristvan123', 'Kardiológus, szívbetegségek kezelése.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(3, 'Dr. Kiss Béla', 'bela.kiss@example.com', '06303332222', 'drbela123', 'Sebész, általános sebészeti beavatkozások.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(4, 'Dr. Tóth Eszter', 'eszter.toth@example.com', '06304443333', 'dreszter123', 'Bőrgyógyász, bőrbetegségek és allergiák.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(5, 'Dr. Horváth Gyula', 'gyula.horvath@example.com', '06305554444', 'drgyula123', 'Urológus, vesebetegségek kezelése.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(6, 'Dr. Varga Ádám', 'adam.varga@example.com', '06306665555', 'dradam123', 'Szemész, látásproblémák és szürkehályog kezelése.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(7, 'Dr. Kovács Tamás', 'tamas.kovacs@example.com', '06307776666', 'drtamas123', 'Reumatológus, mozgásszervi problémák kezelése.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(8, 'Dr. Farkas Mária', 'maria.farkas@example.com', '06308887777', 'drmaria123', 'Nőgyógyász, terhesgondozás és szülészet.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(9, 'Dr. Simon Péter', 'peter.simon@example.com', '06309998888', 'drpeter123', 'Gasztroenterológus, emésztési problémák kezelése.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(10, 'Dr. Takács Zoltán', 'zoltan.takacs@example.com', '06301112345', 'drzoltan123', 'Fogorvos, fogászati kezelések.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(11, 'Dr. Szűcs Judit', 'judit.szucs@example.com', '06302222345', 'drjudit123', 'Neurológus, idegrendszeri betegségek kezelése.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(12, 'Dr. Kelemen László', 'laszlo.kelemen@example.com', '06303332345', 'drlaszlo123', 'Fül-orr-gégész, fül-orr-gégészeti beavatkozások.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(13, 'Dr. Balogh Anikó', 'aniko.balogh@example.com', '06304442345', 'draniko123', 'Endokrinológus, hormonális problémák kezelése.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(14, 'Dr. Molnár László', 'laszlo.molnar@example.com', '06305552345', 'drlaszlo123', 'Gyermekorvos, gyermekkori betegségek kezelése.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(15, 'Dr. Papp Éva', 'eva.papp@example.com', '06306662345', 'dreva123', 'Klinikai pszichológus, mentális egészség és terápia.', 0, 0, '2024-09-29 18:05:43', '2024-09-29 18:05:43', NULL),
(16, 'Dr. Szabó Gergely', 'lofasz@gmail.com', '06725269787', 'e984d4dff4b8bb01b404f650282ccc2d0afa48fc', 'Seggluktágítás', 0, 1, '2024-10-22 12:58:45', '2024-10-22 13:06:43', '2024-11-04 11:31:23'),
(17, 'Dr. Test Doctor', 'testregisterDoctor@gmail.com', '06305461327', '9a6fed200ac6d8c22e7e12c7629a01593ee535a0', '', 1, 1, '2025-01-10 10:02:53', '2025-01-10 10:02:53', '2025-03-24 13:38:21'),
(18, 'Dr. Test Doctor2', 'testregisterDoctor2@gmail.com', '06305461328', '9a6fed200ac6d8c22e7e12c7629a01593ee535a0', 'Szia én egy jó doki vagyok', 1, 1, '2025-01-10 10:16:11', '2025-01-10 10:16:11', '2025-03-24 13:38:27'),
(19, 'Dr. Máté Hermann', 'peter.nagy@example.com', '06704088704', '5e1f587249665d7f50c30e84e1dd85342e1db3d5', 'Intim masszázs', 1, 1, '2025-03-04 14:06:08', '2025-03-04 14:06:08', '2025-03-24 13:38:31');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `doctors_x_services`
--

CREATE TABLE `doctors_x_services` (
  `doctor_id` int(11) NOT NULL,
  `service_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `doctors_x_services`
--

INSERT INTO `doctors_x_services` (`doctor_id`, `service_id`) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 4),
(5, 5),
(6, 6),
(7, 7),
(8, 8),
(9, 9),
(10, 10),
(11, 11),
(12, 12),
(13, 13),
(14, 14),
(15, 15);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `notifications`
--

CREATE TABLE `notifications` (
  `id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `message` text,
  `sent_at` datetime DEFAULT NULL,
  `is_sent` tinyint(1) DEFAULT '0',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `notifications`
--

INSERT INTO `notifications` (`id`, `user_id`, `message`, `sent_at`, `is_sent`, `created_at`) VALUES
(1, 5, 'Időpont foglalva: 2024-11-04 15:00:00 - 2024-11-04 16:20:00', NULL, 0, '2025-01-14 13:01:40'),
(2, 2, 'Időpont foglalva: 2025-01-15 10:00:00 - 2025-01-15 11:00:00', NULL, 0, '2025-01-14 14:39:56'),
(3, 2, 'Időpont foglalva: 2025-01-15 10:00:00 - 2025-01-15 11:00:00', NULL, 0, '2025-01-14 14:49:40'),
(4, 7, 'Időpont foglalva: 2025-03-14 08:00:00 - 2025-03-14 08:30:00', NULL, 0, '2025-03-06 10:42:54'),
(5, 11, 'Időpont foglalva: 2024-10-01 10:00:00 - 2024-10-01 10:30:00', NULL, 0, '2025-03-06 11:24:48'),
(6, 12, 'Időpont foglalva: 2024-10-01 15:00:00 - 2024-10-01 15:30:00', NULL, 0, '2025-03-06 11:30:38'),
(7, 12, 'Időpont foglalva: 2024-10-01 15:30:00 - 2024-10-01 16:00:00', NULL, 0, '2025-03-06 16:10:34'),
(8, 7, 'Időpont foglalva: 2024-10-01 15:30:00 - 2024-10-01 16:00:00', NULL, 0, '2025-03-06 16:12:55'),
(9, 9, 'Időpont foglalva: 2025-02-28 09:00:00 - 2025-02-28 09:30:00', NULL, 0, '2025-03-07 12:48:55'),
(10, 9, 'Időpont foglalva: 2025-02-28 09:30:00 - 2025-02-28 10:00:00', NULL, 0, '2025-03-07 12:59:56'),
(11, 9, 'Időpont foglalva: 2025-02-28 10:30:00 - 2025-02-28 11:00:00', NULL, 0, '2025-03-07 13:03:52'),
(12, 47, 'Időpont foglalva: 2025-02-28 11:00:00 - 2025-02-28 11:30:00', NULL, 0, '2025-03-07 15:39:00'),
(13, 47, 'Időpont foglalva: 2025-02-28 13:00:00 - 2025-02-28 13:30:00', NULL, 0, '2025-03-07 15:56:02'),
(14, 47, 'Időpont foglalva: 2025-02-28 15:00:00 - 2025-02-28 15:30:00', NULL, 0, '2025-03-10 14:03:15'),
(15, 47, 'Időpont foglalva: 2025-02-28 15:30:00 - 2025-02-28 16:00:00', NULL, 0, '2025-03-10 14:19:32'),
(16, 47, 'Időpont foglalva: 2025-02-14 09:00:00 - 2025-02-14 09:30:00', NULL, 0, '2025-03-10 14:21:07'),
(17, 47, 'Időpont foglalva: 2025-02-12 07:00:00 - 2025-02-12 07:30:00', NULL, 0, '2025-03-10 14:46:22'),
(18, 47, 'Időpont foglalva: 2025-02-12 12:00:00 - 2025-02-12 12:30:00', NULL, 0, '2025-03-11 12:53:15'),
(19, 47, 'Időpont foglalva: 2025-02-23 16:00:00 - 2025-02-23 16:30:00', NULL, 0, '2025-03-12 11:44:41'),
(20, 47, 'Időpont foglalva: 2025-02-13 10:00:00 - 2025-02-13 10:30:00', NULL, 0, '2025-03-13 12:23:58'),
(21, 47, 'Időpont foglalva: 2025-02-12 11:00:00 - 2025-02-12 11:30:00', NULL, 0, '2025-03-19 14:33:41'),
(22, 47, 'Időpont foglalva: 2025-02-12 14:00:00 - 2025-02-12 14:30:00', NULL, 0, '2025-03-19 14:34:14'),
(23, 47, 'Időpont foglalva: 2025-02-26 15:30:00 - 2025-02-26 16:00:00', NULL, 0, '2025-03-19 14:38:03'),
(24, 2, 'Időpont foglalva: 2025-02-25 16:00:00 - 2025-02-25 16:30:00', NULL, 0, '2025-03-19 14:47:28'),
(25, 47, 'Időpont foglalva: 2025-02-24 14:00:00 - 2025-02-24 14:30:00', NULL, 0, '2025-03-20 13:05:36'),
(26, 47, 'Időpont foglalva: 2025-02-24 15:00:00 - 2025-02-24 15:30:00', NULL, 0, '2025-03-21 09:34:21'),
(27, 1, 'Időpont foglalva: 2025-02-25 12:00:00 - 2025-02-25 12:30:00', NULL, 0, '2025-03-21 11:37:15'),
(28, 1, 'Időpont foglalva: 2025-02-25 10:00:00 - 2025-02-25 10:30:00', NULL, 0, '2025-03-21 11:43:21'),
(29, 1, 'Időpont foglalva: 2025-02-23 16:30:00 - 2025-02-23 17:00:00', NULL, 0, '2025-03-21 12:26:08'),
(30, 47, 'Időpont foglalva: 2025-02-28 13:30:00 - 2025-02-28 14:00:00', NULL, 0, '2025-03-21 12:28:45'),
(31, 47, 'Időpont foglalva: 2025-02-27 15:00:00 - 2025-02-27 15:30:00', NULL, 0, '2025-03-21 12:37:31'),
(32, 47, 'Időpont foglalva: 2025-02-26 10:30:00 - 2025-02-26 11:00:00', NULL, 0, '2025-03-21 12:50:41'),
(33, 47, 'Időpont foglalva: 2025-02-27 11:00:00 - 2025-02-27 11:30:00', NULL, 0, '2025-03-21 14:37:11'),
(34, 47, 'Időpont foglalva: 2025-02-06 15:00:00 - 2025-02-06 15:30:00', NULL, 0, '2025-03-21 14:40:50'),
(35, 47, 'Időpont foglalva: 2025-02-02 15:00:00 - 2025-02-02 15:30:00', NULL, 0, '2025-03-24 12:52:43'),
(36, 47, 'Időpont foglalva: 2025-02-25 16:30:00 - 2025-02-25 17:00:00', NULL, 0, '2025-03-24 13:31:49'),
(37, 47, 'Időpont foglalva: 2025-02-26 16:30:00 - 2025-02-26 17:00:00', NULL, 0, '2025-03-25 12:01:40'),
(38, 1, 'Időpont foglalva: 2025-02-14 13:00:00 - 2025-02-14 13:30:00', NULL, 0, '2025-03-31 17:02:11'),
(39, 47, 'Időpont foglalva: 2025-02-14 16:30:00 - 2025-02-14 17:00:00', NULL, 0, '2025-04-01 15:43:25'),
(40, 47, 'Időpont foglalva: 2025-04-22 12:30:00 - 2025-04-22 13:00:00', NULL, 0, '2025-04-03 10:00:17'),
(41, 47, 'Időpont foglalva: 2025-04-16 18:00:00 - 2025-04-16 18:30:00', NULL, 0, '2025-04-03 12:49:14'),
(42, 47, 'Időpont foglalva: 2025-04-28 08:00:00 - 2025-04-28 08:30:00', NULL, 0, '2025-04-06 18:46:49'),
(43, 47, 'Időpont foglalva: 2025-04-24 15:00:00 - 2025-04-24 15:30:00', NULL, 0, '2025-04-06 18:56:10'),
(44, 47, 'Időpont foglalva: 2025-04-10 12:30:00 - 2025-04-10 13:00:00', NULL, 0, '2025-04-07 10:06:54'),
(45, 47, 'Időpont foglalva: 2025-04-18 11:00:00 - 2025-04-18 11:30:00', NULL, 0, '2025-04-07 10:10:44'),
(46, 71, 'Időpont foglalva: 2025-04-24 13:30:00 - 2025-04-24 14:00:00', NULL, 0, '2025-04-14 13:32:20'),
(47, 71, 'Időpont foglalva: 2025-05-11 08:00:00 - 2025-05-11 08:30:00', NULL, 0, '2025-04-14 13:50:47'),
(48, 73, 'Időpont foglalva: 2025-05-11 09:30:00 - 2025-05-11 10:00:00', NULL, 0, '2025-04-14 13:58:05');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `password_reset_tokens`
--

CREATE TABLE `password_reset_tokens` (
  `id` int(11) NOT NULL,
  `email` varchar(255) NOT NULL,
  `token` varchar(255) NOT NULL,
  `expires_at` datetime NOT NULL,
  `used` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `password_reset_tokens`
--

INSERT INTO `password_reset_tokens` (`id`, `email`, `token`, `expires_at`, `used`, `created_at`) VALUES
(1, 'szabo.gergely2@simonyiszki.org', '88ce6306-0bf2-4dc3-aa28-ed73cb29324c', '2025-02-20 11:32:44', 0, '2025-02-20 09:32:44'),
(2, 'szabo.gergely2@simonyiszki.org', '11b36f46-8307-44d9-8e74-ba0ccbbd5d09', '2025-02-20 11:34:22', 1, '2025-02-20 09:34:22'),
(3, 'edit.horvath@example.com', '22429de3-f99a-4225-89a5-216810b1907c', '2025-02-20 12:34:02', 1, '2025-02-20 10:34:02'),
(4, 'karoly.varga@example.com', '9d349787-95c1-4d5d-88d1-e75366f7fba7', '2025-02-20 12:35:24', 1, '2025-02-20 10:35:24'),
(5, 'szabo.gergely2@simonyiszki.org', 'c2ba3516-e820-40b0-b942-f811a86bfcc2', '2025-02-20 13:23:47', 0, '2025-02-20 11:23:47'),
(6, 'szabo.gergely2@simonyiszki.org', '6ceb298d-c717-47e0-931d-527a52b000a4', '2025-02-20 14:08:13', 1, '2025-02-20 12:08:13'),
(7, 'andi.stroban@gmail.com', '0c685cde-a25d-4412-9404-c7784bc99669', '2025-02-20 16:05:42', 1, '2025-02-20 14:05:42'),
(8, 'szabo.gergely2@simonyiszki.org', '1162b8d7-f7c5-4889-b536-5f89a82d9d1c', '2025-02-21 11:00:27', 1, '2025-02-21 09:00:27'),
(9, 'szabo.gergely2@simonyiszki.org', 'a31ef830-5d72-44fc-b446-4aef28a24cc3', '2025-02-21 11:09:57', 0, '2025-02-21 09:09:57'),
(10, 'szabo.gergely2@simonyiszki.org', '5ae1cde8-32c9-4b60-b1ff-d4d62aef89f2', '2025-02-21 13:19:18', 0, '2025-02-21 11:19:18'),
(11, 'admin@gmail.com', 'd5326e70-c989-489f-86da-648578aed018', '2025-02-21 14:22:29', 0, '2025-02-21 12:22:29'),
(12, 'sara.kis@example.com', 'ed717480-89a4-4b73-8f15-b93b4c2f7bac', '2025-02-21 14:26:51', 0, '2025-02-21 12:26:51'),
(13, 'sara.kis@example.com', '7c5279c3-300f-403d-84ec-9d0a8ce73b0e', '2025-02-21 14:26:57', 0, '2025-02-21 12:26:57'),
(14, 'szabo.gergely2@simonyiszki.org', 'ec19058f-6c76-4341-8ddd-ea20caf54ccf', '2025-02-22 19:59:35', 1, '2025-02-22 17:59:35'),
(15, 'szabo.gergely2@simonyiszki.org', 'ea9c2156-b830-4172-b809-127c63435866', '2025-02-24 14:33:48', 1, '2025-02-24 12:33:48'),
(16, 'szabo.gergely2@simonyiszki.org', '29e8d3e1-f5cf-449f-a9b7-f0faf23d9ff4', '2025-02-26 14:03:52', 0, '2025-02-26 12:03:52'),
(17, 'mate.hermann@gmail.com', '85c4d1ff-da36-445c-aa2e-7e913e84c77e', '2025-03-04 15:11:42', 0, '2025-03-04 13:11:42'),
(18, 'szabo.gergely2@simonyiszki.org', 'bc141137-3336-4063-a90d-5ff9f30c49b3', '2025-03-04 15:14:33', 1, '2025-03-04 13:14:33'),
(19, 'szabo.gergely2@simonyiszki.org', '79a5d90a-301c-4894-bd2d-8ab22952db46', '2025-03-05 14:58:16', 1, '2025-03-05 12:58:16'),
(20, 'asd@gmail.com', '17e84810-dabd-48b7-9a5f-4906e09d3dfb', '2025-03-31 21:35:43', 0, '2025-03-31 18:35:43'),
(21, 'teszt1@pelda.hu', '96f67054-b1d9-437b-afb9-766c1603c51f', '2025-03-31 21:36:40', 0, '2025-03-31 18:36:40'),
(22, 'teszt1@pelda.hu', 'a2e31703-9811-47d8-b9cf-60874907e5fb', '2025-03-31 21:37:12', 1, '2025-03-31 18:37:12'),
(23, 'teszt2@pelda.hu', 'f1f21d1a-e42b-45ed-87fd-b6da35088a80', '2025-03-31 21:42:29', 0, '2025-03-31 18:42:29'),
(24, 'teszt2@pelda.hu', 'e811baeb-ea3b-4845-95e7-67cc41642b50', '2025-03-31 21:44:08', 1, '2025-03-31 18:44:08'),
(25, 'andi.stroban@gmail.com', '6e2935a5-eb71-4043-b440-1774b5af5c6e', '2025-04-06 19:53:49', 0, '2025-04-06 16:53:49'),
(26, 'szabo.gergely25@gmail.com', '89e86f40-b8c4-43fe-b6e6-b3806e281a1e', '2025-04-14 14:28:24', 1, '2025-04-14 11:28:24');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `patients`
--

CREATE TABLE `patients` (
  `id` int(11) NOT NULL,
  `first_name` varchar(100) NOT NULL,
  `last_name` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL,
  `phone_number` varchar(15) NOT NULL,
  `password` varchar(255) NOT NULL,
  `isAdmin` tinyint(1) NOT NULL DEFAULT '0',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `patients`
--

INSERT INTO `patients` (`id`, `first_name`, `last_name`, `email`, `phone_number`, `password`, `isAdmin`, `is_deleted`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 'Gergely', 'Szabó', 'admin@gmail.com', '06307565980', 'c73a7f94d6b94e6b0d70e2decdbbcd48f7974168', 1, 0, '2024-09-29 18:01:45', '2025-02-24 13:50:21', NULL),
(2, 'Balázs', 'Bogdán', 'admin1@gmail.com', '06204567894', 'c73a7f94d6b94e6b0d70e2decdbbcd48f7974168', 1, 0, '2024-09-29 18:01:45', '2025-02-24 13:51:54', NULL),
(3, 'Anna', 'Kovács', 'anna.kovacs@example.com', '06305552233', 'c0004cdb0b0ec7ab800f8e3bbc515995b4263206', 0, 1, '2024-09-29 18:01:45', '2025-02-15 19:00:24', '2025-02-15 19:00:24'),
(4, 'Péter', 'Nagy', 'peter.nagy@example.com', '06306667788', 'a9135b81a069ad0c43395739a61d95a8514115b5', 0, 0, '2024-09-29 18:01:45', '2024-10-22 12:32:27', NULL),
(5, 'Martin', 'Tóth', 'marton.toth@example.com', '06301112233', 'ba721dc0e2083242062e0085d8d25932abe1171d', 0, 0, '2024-09-29 18:01:45', '2024-10-22 12:33:06', NULL),
(6, 'Edit', 'Horváth', 'edit.horvath@example.com', '06303334455', 'a240a1757ef2e0abf3f252dccec6895fc90d6385', 0, 0, '2024-09-29 18:01:45', '2024-09-29 18:01:45', NULL),
(7, 'Károly', 'Varga', 'karoly.varga@example.com', '06302223344', 'a240a1757ef2e0abf3f252dccec6895fc90d6385', 0, 0, '2024-09-29 18:01:45', '2024-09-29 18:01:45', NULL),
(8, 'Sára', 'Kis', 'sara.kis@example.com', '06304445566', 'sarajelszo', 0, 0, '2024-09-29 18:01:45', '2024-09-29 18:01:45', NULL),
(9, 'Zoltán', 'Molnár', 'zoltan.molnar@example.com', '06301112299', 'zoltanjelszo', 0, 0, '2024-09-29 18:01:45', '2024-09-29 18:01:45', NULL),
(10, 'László', 'Farkas', 'laszlo.farkas@example.com', '06307778899', 'laszlojelszo', 0, 0, '2024-09-29 18:01:45', '2024-09-29 18:01:45', NULL),
(11, 'Katalin', 'Szilágyi', 'katalin.szilagyi@example.com', '06305556677', 'katalinjelszo', 0, 0, '2024-09-29 18:01:45', '2024-09-29 18:01:45', NULL),
(12, 'Júlia', 'Németh', 'julia.nemeth@example.com', '06308889900', 'juliajelszo', 0, 0, '2024-09-29 18:01:45', '2024-09-29 18:01:45', NULL),
(13, 'Tamás', 'Lukács', 'tamas.lukacs@example.com', '06301117788', 'tamasjelszo', 0, 0, '2024-09-29 18:01:45', '2024-09-29 18:01:45', NULL),
(14, 'Erika', 'Fehér', 'erika.feher@example.com', '06302229988', 'erikajelszo', 0, 0, '2024-09-29 18:01:45', '2024-09-29 18:01:45', NULL),
(15, 'Gábor', 'Simon', 'gabor.simon@example.com', '06303334499', 'gaborjelszo', 0, 0, '2024-09-29 18:01:45', '2024-09-29 18:01:45', NULL),
(16, 'Béla', 'Kiss', 'bela.kiss@example.com', '06301111234', 'kisbelapass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(17, 'Anna', 'Nagy', 'anna.nagy@example.com', '06302222345', 'nagyanapass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(18, 'Gábor', 'Tóth', 'gabor.toth@example.com', '06303333456', 'tothgaborpass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(19, 'Péter', 'Horváth', 'peter.horvath@example.com', '06304444567', 'horvathpeterpass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(20, 'Katalin', 'Szabó', 'katalin.szabo@example.com', '06305555678', 'szabokatalinpass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(21, 'Tamás', 'Varga', 'tamas.varga@example.com', '06306666789', 'vargatamaspass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(22, 'Zoltán', 'Farkas', 'zoltan.farkas@example.com', '06307777890', 'farkaszoltanpass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(23, 'Ádám', 'Kovács', 'adam.kovacs@example.com', '06308888901', 'kovacsadampass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(24, 'Judit', 'Balogh', 'judit.balogh@example.com', '06309999012', 'baloghjuditpass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(25, 'András', 'Takács', 'andras.takacs@example.com', '06301112123', 'takacsandraspass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(26, 'László', 'Papp', 'laszlo.papp@example.com', '06302223234', 'papplaszlopass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(27, 'Éva', 'Molnár', 'eva.molnar@example.com', '06303334345', 'molnarevapass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(28, 'István', 'Simon', 'istvan.simon@example.com', '06304445456', 'simonistvanpass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(29, 'Tamás', 'Szűcs', 'tamas.szucs@example.com', '06305556567', 'szucstamaspass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(30, 'Péter', 'Oláh', 'peter.olah@example.com', '06306667678', 'olahpeterpass', 0, 0, '2024-10-22 11:53:27', '2024-10-22 11:53:27', NULL),
(31, 'Test', 'Patient', 'registerPatientTest@gmail.com', '06301111122', 'b6448649bbb6f6d480f26b51655d36035bd42bfe', 0, 0, '2024-11-26 13:24:46', '2024-11-26 13:24:46', NULL),
(33, 'Test', 'Patient2', 'registerPatientTest2@gmail.com', '06301111123', 'b6448649bbb6f6d480f26b51655d36035bd42bfe', 0, 0, '2024-11-26 13:29:33', '2025-02-18 12:40:06', NULL),
(34, 'Test', 'Patient3', 'registerPatientTest3@gmail.com', '06301111124', 'a4da6c7cd92130566aa5ac4d08ac67b12ac17393', 0, 0, '2024-12-01 15:28:33', '2025-02-19 11:57:52', NULL),
(35, 'Test', 'Patient4', 'registerPatientTest4@gmail.com', '06301111125', '016675736f893111828bc13acf462f5145af91c1', 0, 0, '2025-01-10 12:59:10', '2025-01-10 12:59:10', NULL),
(36, 'Andrea', 'Strobán', 'andi.stroban@gmail.com', '06205269787', '15be1c08c1047cf4281fd2a04312505cd6028c9e', 0, 0, '2025-02-20 15:02:31', '2025-02-20 15:02:31', NULL),
(37, 'Teszt', 'Páciens', 'teszt@example.com', '123456789', '3bfffef580029e7052869f4569442cc3180a1289', 0, 0, '2025-02-22 17:08:00', '2025-02-22 17:08:00', NULL),
(39, 'Teszt', 'Páciens', 'teszt1@example.com', '123456780', '3bfffef580029e7052869f4569442cc3180a1289', 0, 0, '2025-02-22 17:18:29', '2025-02-22 17:18:29', NULL),
(41, 'Teszt', 'Páciens2', 'teszt2@example.com', '1234567808', '3bfffef580029e7052869f4569442cc3180a1289', 0, 0, '2025-02-22 17:21:29', '2025-02-22 17:21:29', NULL),
(42, 'Teszt', 'Páciens3', 'teszt3@example.com', '123456799', '3bfffef580029e7052869f4569442cc3180a1289', 0, 0, '2025-02-22 17:33:58', '2025-02-22 17:33:58', NULL),
(44, 'Teszt', 'Páciens4', 'teszt4@example.com', '123456790', '3bfffef580029e7052869f4569442cc3180a1289', 0, 0, '2025-02-22 17:48:52', '2025-02-22 17:48:52', NULL),
(45, 'Teszt', 'Páciens5', 'teszt5@example.com', '123456791', '3bfffef580029e7052869f4569442cc3180a1289', 0, 0, '2025-02-22 17:54:18', '2025-02-22 17:54:18', NULL),
(47, 'Gergely', 'Szabó', 'szabo.gergely2@simonyiszki.org', '06307565981', 'b0541812754eba498b8c2cf2ba3eb2a778d5f750', 0, 0, '2025-02-22 18:59:24', '2025-03-07 15:44:09', NULL),
(48, 'Test', 'Patient6', 'teszt6@example.com', '06302211125', '016675736f893111828bc13acf462f5145af91c1', 0, 0, '2025-02-24 13:02:00', '2025-02-24 13:02:00', NULL),
(49, 'regisz', 'tráció', 'registerPatientTest8@gmail.com', '064444444', '0878982365e2d678bb8789988fda26e64506be8d', 0, 0, '2025-03-03 17:15:16', '2025-03-03 17:15:16', NULL),
(50, 're', 'gi', 'registerPatientTest12@gmail.com', '063088888', '28082a42235120245ed4c983e2caed729cca1275', 0, 0, '2025-03-03 17:20:03', '2025-03-03 17:20:03', NULL),
(51, 'Máté', 'Hermann', 'mate.hermann@gmail.com', '0645451674', '067b33986262d5090ca8780db7395a792964bfff', 0, 0, '2025-03-04 14:10:19', '2025-03-04 14:10:19', NULL),
(52, 'Próba', 'Vizsga', 'proba.vizsga@gmail.com', '06111111111', 'b0541812754eba498b8c2cf2ba3eb2a778d5f750', 0, 0, '2025-03-04 14:48:52', '2025-03-04 14:48:52', NULL),
(55, 'Próba', 'Vizsga', 'probavizsga@gmail.com', '0611111112', 'b0541812754eba498b8c2cf2ba3eb2a778d5f750', 0, 0, '2025-03-05 13:57:19', '2025-03-05 13:57:19', NULL),
(56, 'Test', 'register2', 'testreg2@gmail.com', '5555898941', '40e869a48a074b408e76df9a735e53e71f0ba16b', 0, 0, '2025-03-12 13:04:40', '2025-03-12 13:04:40', NULL),
(59, 'Test', 'register2', 'testreg3@gmail.com', '0678954623', '40e869a48a074b408e76df9a735e53e71f0ba16b', 0, 0, '2025-03-12 13:07:21', '2025-03-12 13:07:21', NULL),
(60, 'Test', 'register4', 'testreg4@gmail.com', '0678954628', '40e869a48a074b408e76df9a735e53e71f0ba16b', 0, 1, '2025-03-12 13:08:38', '2025-03-14 09:45:27', '2025-03-14 09:45:27'),
(61, 'Teszt', 'Felhasználó', 'teszt@pelda.hu', '06201234567', '9bde3453d74ad925bcc1a07d782709fbb94e60d8', 0, 0, '2025-03-13 10:01:35', '2025-03-13 10:01:35', NULL),
(62, 'Teszt', 'Felhasználó', 'teszt1@pelda.hu', '06301234567', 'ac401131f575a6499fcfcef912509279369bd708', 0, 0, '2025-03-13 12:00:38', '2025-03-13 12:00:38', NULL),
(64, 'Teszt', 'Felhasználó', 'teszt2@pelda.hu', '06301234568', 'ecbdd642b5b751deab706968c1e8a9026a380b6e', 0, 0, '2025-03-13 18:05:08', '2025-03-13 18:05:08', NULL),
(65, 'Teszt', 'Felhasználó', 'teszt3@pelda.hu', '06307544480', '9bde3453d74ad925bcc1a07d782709fbb94e60d8', 0, 0, '2025-03-13 18:28:41', '2025-03-13 18:28:41', NULL),
(68, 'Gergely', 'Szabó', 'szabo.gergely25@simonyiszki.org', '06307565988', '37baf9c9b2ff4290db86bee6ab6758a235a63f05', 0, 0, '2025-03-24 12:47:49', '2025-03-24 12:47:49', NULL),
(71, 'Gergely', 'Szabó', 'szabo.gergely25@gmail.com', '06207565980', '306ddaf09785c8ecc2d3ddaf3825132a74adfea1', 0, 0, '2025-03-25 12:08:52', '2025-03-25 12:08:52', NULL),
(72, 'x', 'd', 'asd@gmail.com', '06888888888', 'c54a1951f72088816b4dd8ff66f0d43813abf098', 0, 0, '2025-03-31 16:29:17', '2025-03-31 16:29:17', NULL),
(73, 'Camalas', 'Adrianno Di', 'ferenczkristof74@gmail.com', '0669420444', '13cc4d5f78d68d31b90eff13f770c945e6be374c', 0, 0, '2025-04-14 13:56:56', '2025-04-14 13:56:56', NULL);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `patient_verifications`
--

CREATE TABLE `patient_verifications` (
  `id` int(11) NOT NULL,
  `patient_id` int(11) NOT NULL,
  `token` varchar(255) NOT NULL,
  `verified` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` datetime NOT NULL,
  `verified_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `patient_verifications`
--

INSERT INTO `patient_verifications` (`id`, `patient_id`, `token`, `verified`, `created_at`, `expires_at`, `verified_at`) VALUES
(1, 61, 'c36dbad3-a17e-40d9-87f8-f4c0359f89bb', 1, '2025-03-13 09:01:35', '2025-03-14 10:01:36', '2025-03-13 11:45:30'),
(2, 62, 'abb5a943-92e4-44bf-9b76-ae95ccc04425', 1, '2025-03-13 11:00:38', '2025-03-14 12:00:38', '2025-03-13 12:06:29'),
(3, 64, 'e0ce11c4-5d10-4e36-b7c7-9af4112f87d1', 1, '2025-03-13 17:05:08', '2025-03-14 18:05:09', '2025-03-13 18:06:40'),
(4, 65, '0eb68480-f5e0-4c53-b9c5-c53cdf2278b9', 1, '2025-03-13 17:28:41', '2025-03-14 18:28:42', '2025-03-13 18:29:10'),
(5, 68, '29355816-58e3-4e03-80a2-6f4a77f4e1d7', 0, '2025-03-24 11:47:49', '2025-03-25 12:47:50', NULL),
(6, 71, '632cd9ba-da2a-4d74-a0b1-34d566401dce', 1, '2025-03-25 11:08:52', '2025-03-26 12:08:53', '2025-03-25 12:09:36'),
(7, 72, 'db28c8a7-67fb-47cc-beed-53892daf4614', 1, '2025-03-31 14:29:17', '2025-04-01 16:29:17', '2025-03-31 16:34:17'),
(8, 73, '356769d3-98cc-44b9-816d-54ed3fce9b9d', 0, '2025-04-14 11:56:56', '2025-04-15 13:56:56', NULL);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `payments`
--

CREATE TABLE `payments` (
  `id` int(11) NOT NULL,
  `appointment_id` int(11) NOT NULL,
  `amount` int(10) NOT NULL,
  `payment_method` enum('online','in-person') NOT NULL,
  `payment_status` enum('paid','pending','failed') NOT NULL,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `payments`
--

INSERT INTO `payments` (`id`, `appointment_id`, `amount`, `payment_method`, `payment_status`, `is_deleted`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 1, 15000, 'online', 'paid', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(2, 2, 16000, 'in-person', 'paid', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(3, 3, 17000, 'online', 'pending', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(4, 4, 18000, 'in-person', 'failed', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(5, 5, 15000, 'online', 'paid', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(6, 6, 16000, 'in-person', 'paid', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(7, 7, 17000, 'online', 'pending', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(8, 8, 18000, 'in-person', 'failed', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(9, 9, 15000, 'online', 'paid', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(10, 10, 16000, 'in-person', 'paid', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(11, 11, 17000, 'online', 'pending', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(12, 12, 18000, 'in-person', 'failed', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(13, 13, 15000, 'online', 'paid', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(14, 14, 16000, 'in-person', 'paid', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(15, 15, 17000, 'online', 'pending', 0, '2024-09-29 18:07:40', '2024-09-29 18:07:40', NULL),
(16, 16, 20000, 'in-person', 'pending', 1, '2024-11-04 12:03:16', '2024-11-04 12:07:11', '2024-11-04 12:07:44');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `reminders`
--

CREATE TABLE `reminders` (
  `id` int(11) NOT NULL,
  `appointment_id` int(11) NOT NULL,
  `reminder_time` datetime NOT NULL,
  `reminder_method` enum('email','SMS','push') NOT NULL,
  `sent` tinyint(1) NOT NULL DEFAULT '0',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `reminders`
--

INSERT INTO `reminders` (`id`, `appointment_id`, `reminder_time`, `reminder_method`, `sent`, `is_deleted`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 1, '2024-09-30 08:00:00', 'email', 1, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(2, 2, '2024-09-30 09:00:00', 'SMS', 0, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(3, 3, '2024-09-30 10:00:00', 'push', 1, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(4, 4, '2024-09-30 11:00:00', 'email', 1, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(5, 5, '2024-09-30 12:00:00', 'SMS', 0, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(6, 6, '2024-09-30 13:00:00', 'push', 1, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(7, 7, '2024-09-30 14:00:00', 'email', 1, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(8, 8, '2024-09-30 15:00:00', 'SMS', 0, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(9, 9, '2024-09-30 16:00:00', 'push', 1, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(10, 10, '2024-09-30 17:00:00', 'email', 1, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(11, 11, '2024-09-30 18:00:00', 'SMS', 0, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(12, 12, '2024-09-30 19:00:00', 'push', 1, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(13, 13, '2024-09-30 20:00:00', 'email', 1, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(14, 14, '2024-09-30 21:00:00', 'SMS', 0, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(15, 15, '2024-09-30 22:00:00', 'push', 1, 0, '2024-09-29 18:08:23', '2024-09-29 18:08:23', NULL),
(16, 16, '2024-11-04 15:30:00', 'SMS', 1, 1, '2024-11-04 16:16:19', '2024-11-04 16:20:04', '2024-11-04 16:20:04');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `reviews`
--

CREATE TABLE `reviews` (
  `id` int(11) NOT NULL,
  `doctor_id` int(11) NOT NULL,
  `patient_id` int(11) NOT NULL,
  `rating` int(1) NOT NULL,
  `review_text` text NOT NULL,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `reviews`
--

INSERT INTO `reviews` (`id`, `doctor_id`, `patient_id`, `rating`, `review_text`, `is_deleted`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 1, 1, 5, 'Nagyon kedves és alapos orvos.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(2, 2, 2, 4, 'Gyors és professzionális ellátás.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(3, 3, 3, 5, 'Minden kérdésre választ kaptam.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(4, 4, 4, 3, 'Kicsit hosszú volt a várakozási idő.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(5, 5, 5, 4, 'Tiszta rendelő és barátságos személyzet.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(6, 6, 6, 5, 'Remek szakember, szívesen ajánlom.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(7, 7, 7, 5, 'Nagyon elégedett vagyok az ellátással.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(8, 8, 8, 3, 'Nem volt annyira részletes a vizsgálat.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(9, 9, 9, 4, 'Megbízható és segítőkész orvos.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(10, 10, 10, 5, 'Teljesen elégedett voltam a kezeléssel.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(11, 11, 11, 5, 'Rendkívül kedves és alapos.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(12, 12, 12, 4, 'A kezelés megfelelő volt, de lehetett volna gyorsabb.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(13, 13, 13, 3, 'Nem kaptam elég információt.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(14, 14, 14, 5, 'Kedves orvos és jó ellátás.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(15, 15, 15, 5, 'Szuper, mindenkinek ajánlom.', 0, '2024-09-29 18:09:38', '2024-11-04 16:41:59', '2024-11-04 16:41:59'),
(16, 10, 5, 3, 'kaki', 1, '2024-11-04 16:39:17', '2024-11-04 16:46:46', '2024-11-04 16:48:35'),
(17, 15, 3, 4, '', 0, '2025-01-27 12:08:37', '2025-01-27 12:08:37', NULL),
(18, 5, 9, 5, 'Teszt értékelés', 0, '2025-01-27 12:10:47', '2025-01-27 12:10:47', NULL),
(19, 8, 12, 4, 'Nagyon figyelmes volt a vizsgálat során.', 0, '2025-01-27 12:22:18', '2025-01-27 12:22:18', NULL),
(20, 10, 37, 5, '', 0, '2025-02-24 18:39:44', '2025-02-24 18:39:44', NULL),
(21, 14, 12, 5, 'Nagyon figyelmes volt a vizsgálat során.', 0, '2025-02-24 18:45:32', '2025-02-24 18:45:32', NULL),
(22, 5, 18, 5, '', 0, '2025-02-24 18:52:53', '2025-02-24 18:52:53', NULL),
(23, 3, 18, 4, 'Jó', 0, '2025-02-25 13:33:28', '2025-02-25 13:33:28', NULL),
(24, 6, 18, 3, 'Nem jó', 0, '2025-02-25 13:42:30', '2025-02-25 13:42:30', NULL),
(25, 4, 18, 3, '', 0, '2025-02-25 13:51:53', '2025-02-25 13:51:53', NULL),
(26, 16, 47, 5, 'Nagyon jól éreztem magam! :)', 0, '2025-02-25 14:34:49', '2025-02-25 14:34:49', NULL),
(27, 2, 47, 3, '', 0, '2025-02-25 14:59:04', '2025-02-25 14:59:04', NULL),
(28, 2, 47, 5, '', 0, '2025-02-26 10:58:17', '2025-02-26 10:58:17', NULL),
(29, 2, 47, 3, '', 0, '2025-03-04 12:40:09', '2025-03-04 12:40:09', NULL),
(30, 19, 47, 5, 'Nagyon elégedett voltam. Kielégülten :)', 0, '2025-03-04 14:07:53', '2025-03-04 14:07:53', NULL),
(31, 19, 51, 5, 'HMMMM...', 0, '2025-03-04 14:10:51', '2025-03-04 14:10:51', NULL),
(32, 2, 52, 3, 'Szuper', 0, '2025-03-04 14:50:22', '2025-03-04 14:50:22', NULL),
(33, 11, 52, 4, 'Jó', 0, '2025-03-04 15:28:03', '2025-03-04 15:28:03', NULL),
(34, 7, 55, 5, 'Szuper volt', 0, '2025-03-05 13:57:57', '2025-03-05 13:57:57', NULL),
(35, 1, 47, 1, '', 0, '2025-03-25 12:41:47', '2025-03-25 12:41:47', NULL),
(36, 7, 1, 5, 'Elégedett voltam a szolgáltatással!', 0, '2025-03-31 17:12:40', '2025-03-31 17:12:40', NULL),
(37, 5, 47, 5, 'Ő Gyula', 0, '2025-04-06 18:45:43', '2025-04-06 18:45:43', NULL),
(38, 10, 47, 4, '', 0, '2025-04-06 18:55:02', '2025-04-06 18:55:02', NULL);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `schedules`
--

CREATE TABLE `schedules` (
  `id` int(11) NOT NULL,
  `doctor_id` int(11) NOT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  `available_slots` int(11) NOT NULL,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `schedules`
--

INSERT INTO `schedules` (`id`, `doctor_id`, `start_time`, `end_time`, `available_slots`, `is_deleted`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 1, '2024-10-01 09:00:00', '2024-10-01 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(2, 2, '2024-10-02 09:00:00', '2024-10-02 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(3, 3, '2024-10-03 09:00:00', '2024-10-03 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(4, 4, '2024-10-04 09:00:00', '2024-10-04 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(5, 5, '2024-10-05 09:00:00', '2024-10-05 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(6, 6, '2024-10-06 09:00:00', '2024-10-06 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(7, 7, '2024-10-07 09:00:00', '2024-10-07 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(8, 8, '2024-10-08 09:00:00', '2024-10-08 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(9, 9, '2024-10-09 09:00:00', '2024-10-09 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(10, 10, '2024-10-10 09:00:00', '2024-10-10 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(11, 11, '2024-10-11 09:00:00', '2024-10-11 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(12, 12, '2024-10-12 09:00:00', '2024-10-12 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(13, 13, '2024-10-13 09:00:00', '2024-10-13 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(14, 14, '2024-10-14 09:00:00', '2024-10-14 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(15, 15, '2024-10-15 09:00:00', '2024-10-15 17:00:00', 8, 0, '2024-09-29 18:09:21', '2024-09-29 18:09:21', NULL),
(16, 16, '2024-11-04 10:00:00', '2024-11-04 15:00:00', 5, 1, '2024-11-04 12:12:11', '2024-11-04 12:19:30', '2024-11-04 12:20:14'),
(17, 1, '2025-01-01 08:00:00', '2025-01-01 18:00:00', 20, 0, '2025-01-20 17:28:50', '2025-01-20 17:28:50', NULL),
(46, 1, '2025-02-01 09:00:00', '2025-02-01 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(47, 2, '2025-02-02 09:00:00', '2025-02-02 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(48, 3, '2025-02-03 09:00:00', '2025-02-03 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(49, 4, '2025-02-04 09:00:00', '2025-02-04 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(50, 5, '2025-02-05 09:00:00', '2025-02-05 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(51, 6, '2025-02-06 09:00:00', '2025-02-06 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(52, 7, '2025-02-07 09:00:00', '2025-02-07 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(53, 8, '2025-02-08 09:00:00', '2025-02-08 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(54, 9, '2025-02-09 09:00:00', '2025-02-09 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(55, 10, '2025-02-10 09:00:00', '2025-02-10 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(56, 11, '2025-02-11 09:00:00', '2025-02-11 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(57, 12, '2025-02-12 09:00:00', '2025-02-12 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(58, 13, '2025-02-13 09:00:00', '2025-02-13 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(59, 14, '2025-02-14 09:00:00', '2025-02-14 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(60, 15, '2025-02-15 09:00:00', '2025-02-15 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(61, 16, '2025-02-16 09:00:00', '2025-02-16 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(62, 1, '2025-02-17 09:00:00', '2025-02-17 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(63, 2, '2025-02-18 09:00:00', '2025-02-18 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(64, 3, '2025-02-19 09:00:00', '2025-02-19 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(65, 4, '2025-02-20 09:00:00', '2025-02-20 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(66, 5, '2025-02-21 09:00:00', '2025-02-21 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(67, 6, '2025-02-22 09:00:00', '2025-02-22 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(68, 7, '2025-02-23 09:00:00', '2025-02-23 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(69, 8, '2025-02-24 09:00:00', '2025-02-24 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(70, 9, '2025-02-25 09:00:00', '2025-02-25 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(71, 10, '2025-02-26 09:00:00', '2025-02-26 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(72, 11, '2025-02-27 09:00:00', '2025-02-27 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(73, 12, '2025-02-28 09:00:00', '2025-02-28 17:00:00', 8, 0, '2025-02-17 15:53:34', '2025-02-17 15:53:34', NULL),
(74, 1, '2025-04-02 09:00:00', '2025-04-02 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(75, 2, '2025-04-04 10:00:00', '2025-04-04 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(76, 3, '2025-04-06 12:00:00', '2025-04-06 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(77, 4, '2025-04-08 08:00:00', '2025-04-08 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(78, 5, '2025-04-10 08:00:00', '2025-04-10 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(79, 6, '2025-04-12 09:00:00', '2025-04-12 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(80, 7, '2025-04-14 10:00:00', '2025-04-14 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(81, 8, '2025-04-16 12:00:00', '2025-04-16 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(82, 9, '2025-04-18 08:00:00', '2025-04-18 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(83, 10, '2025-04-20 08:00:00', '2025-04-20 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(84, 11, '2025-04-22 09:00:00', '2025-04-22 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(85, 12, '2025-04-24 10:00:00', '2025-04-24 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(86, 13, '2025-04-26 12:00:00', '2025-04-26 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(87, 14, '2025-04-28 08:00:00', '2025-04-28 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(88, 15, '2025-04-30 08:00:00', '2025-04-30 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(89, 1, '2025-05-03 09:00:00', '2025-05-03 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(90, 2, '2025-05-05 10:00:00', '2025-05-05 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(91, 3, '2025-05-07 12:00:00', '2025-05-07 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(92, 4, '2025-05-09 08:00:00', '2025-05-09 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(93, 5, '2025-05-11 08:00:00', '2025-05-11 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(94, 6, '2025-05-13 09:00:00', '2025-05-13 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(95, 7, '2025-05-15 10:00:00', '2025-05-15 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(96, 8, '2025-05-17 12:00:00', '2025-05-17 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(97, 9, '2025-05-19 08:00:00', '2025-05-19 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(98, 10, '2025-05-21 08:00:00', '2025-05-21 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(99, 11, '2025-05-23 09:00:00', '2025-05-23 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(100, 12, '2025-05-25 10:00:00', '2025-05-25 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(101, 13, '2025-05-27 12:00:00', '2025-05-27 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(102, 14, '2025-05-29 08:00:00', '2025-05-29 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(103, 15, '2025-05-31 08:00:00', '2025-05-31 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(104, 1, '2025-06-02 09:00:00', '2025-06-02 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(105, 2, '2025-06-04 10:00:00', '2025-06-04 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(106, 3, '2025-06-06 12:00:00', '2025-06-06 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(107, 4, '2025-06-08 08:00:00', '2025-06-08 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(108, 5, '2025-06-10 08:00:00', '2025-06-10 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(109, 6, '2025-06-12 09:00:00', '2025-06-12 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(110, 7, '2025-06-14 10:00:00', '2025-06-14 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(111, 8, '2025-06-16 12:00:00', '2025-06-16 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(112, 9, '2025-06-18 08:00:00', '2025-06-18 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(113, 10, '2025-06-20 08:00:00', '2025-06-20 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(114, 11, '2025-06-22 09:00:00', '2025-06-22 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(115, 12, '2025-06-24 10:00:00', '2025-06-24 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(116, 13, '2025-06-26 12:00:00', '2025-06-26 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(117, 14, '2025-06-28 08:00:00', '2025-06-28 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(118, 15, '2025-06-30 08:00:00', '2025-06-30 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(119, 1, '2025-07-02 09:00:00', '2025-07-02 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(120, 2, '2025-07-04 10:00:00', '2025-07-04 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(121, 3, '2025-07-06 12:00:00', '2025-07-06 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(122, 4, '2025-07-08 08:00:00', '2025-07-08 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(123, 5, '2025-07-10 08:00:00', '2025-07-10 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(124, 6, '2025-07-12 09:00:00', '2025-07-12 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(125, 7, '2025-07-14 10:00:00', '2025-07-14 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(126, 8, '2025-07-16 12:00:00', '2025-07-16 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(127, 9, '2025-07-18 08:00:00', '2025-07-18 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(128, 10, '2025-07-20 08:00:00', '2025-07-20 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(129, 11, '2025-07-22 09:00:00', '2025-07-22 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(130, 12, '2025-07-24 10:00:00', '2025-07-24 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(131, 13, '2025-07-26 12:00:00', '2025-07-26 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(132, 14, '2025-07-28 08:00:00', '2025-07-28 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(133, 15, '2025-07-30 08:00:00', '2025-07-30 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(134, 1, '2025-08-03 09:00:00', '2025-08-03 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(135, 2, '2025-08-05 10:00:00', '2025-08-05 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(136, 3, '2025-08-07 12:00:00', '2025-08-07 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(137, 4, '2025-08-09 08:00:00', '2025-08-09 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(138, 5, '2025-08-11 08:00:00', '2025-08-11 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(139, 6, '2025-08-13 09:00:00', '2025-08-13 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(140, 7, '2025-08-15 10:00:00', '2025-08-15 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(141, 8, '2025-08-17 12:00:00', '2025-08-17 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(142, 9, '2025-08-19 08:00:00', '2025-08-19 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(143, 10, '2025-08-21 08:00:00', '2025-08-21 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(144, 11, '2025-08-23 09:00:00', '2025-08-23 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(145, 12, '2025-08-25 10:00:00', '2025-08-25 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(146, 13, '2025-08-27 12:00:00', '2025-08-27 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(147, 14, '2025-08-29 08:00:00', '2025-08-29 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(148, 15, '2025-08-31 08:00:00', '2025-08-31 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(149, 1, '2025-09-02 09:00:00', '2025-09-02 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(150, 2, '2025-09-04 10:00:00', '2025-09-04 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(151, 3, '2025-09-06 12:00:00', '2025-09-06 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(152, 4, '2025-09-08 08:00:00', '2025-09-08 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(153, 5, '2025-09-10 08:00:00', '2025-09-10 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(154, 6, '2025-09-12 09:00:00', '2025-09-12 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(155, 7, '2025-09-14 10:00:00', '2025-09-14 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(156, 8, '2025-09-16 12:00:00', '2025-09-16 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(157, 9, '2025-09-18 08:00:00', '2025-09-18 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(158, 10, '2025-09-20 08:00:00', '2025-09-20 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(159, 11, '2025-09-22 09:00:00', '2025-09-22 17:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(160, 12, '2025-09-24 10:00:00', '2025-09-24 18:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(161, 13, '2025-09-26 12:00:00', '2025-09-26 20:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(162, 14, '2025-09-28 08:00:00', '2025-09-28 12:00:00', 4, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL),
(163, 15, '2025-09-30 08:00:00', '2025-09-30 16:00:00', 8, 0, '2025-03-15 10:00:00', '2025-03-15 10:00:00', NULL);

-- --------------------------------------------------------

--
-- Tábla szerkezet: `doctor_working_hours`
--
CREATE TABLE `doctor_working_hours` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `doctor_id` int(11) NOT NULL,
  `day_of_week` tinyint(1) NOT NULL COMMENT '1 = Hetfo, ..., 7 = Vasarnap',
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `slot_duration` int(11) NOT NULL DEFAULT '30',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dwh_doctor_day` (`doctor_id`,`day_of_week`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Alapértelmezett heti sablon betöltése az 1-15-ös azonosítójú orvosokhoz (Hétfő-Péntek: 08:00 - 16:00)
INSERT INTO `doctor_working_hours` (`doctor_id`, `day_of_week`, `start_time`, `end_time`, `slot_duration`, `is_active`)
SELECT 
    d.id AS doctor_id,
    w.day_num AS day_of_week,
    '08:00:00' AS start_time,
    '16:00:00' AS end_time,
    30 AS slot_duration,
    1 AS is_active
FROM doctors d
CROSS JOIN (
    SELECT 1 AS day_num UNION ALL  -- Hétfő
    SELECT 2 UNION ALL             -- Kedd
    SELECT 3 UNION ALL             -- Szerda
    SELECT 4 UNION ALL             -- Csütörtök
    SELECT 5                       -- Péntek
) w
WHERE d.is_deleted = 0 AND d.id BETWEEN 1 AND 15;

--
-- Tábla szerkezet ehhez a táblához `services`
--

CREATE TABLE `services` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` text NOT NULL,
  `price` int(10) NOT NULL,
  `duration` int(3) NOT NULL,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  `doctorId` tinyblob,
  `doctorNames` tinyblob
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `services`
--

INSERT INTO `services` (`id`, `name`, `description`, `price`, `duration`, `is_deleted`, `created_at`, `updated_at`, `deleted_at`, `doctorId`, `doctorNames`) VALUES
(1, 'Ortopédiai vizsgálat', 'Ortopédiai vizsgálatok és kezelések', 20000, 30, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(2, 'Kardiológiai vizsgálat', 'Szív- és érrendszeri vizsgálatok', 25000, 45, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(3, 'Sebészeti konzultáció', 'Sebészeti vizsgálatok és tanácsadás', 15000, 30, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(4, 'Bőrgyógyászati vizsgálat', 'Bőrproblémák kezelése és tanácsadás', 18000, 30, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(5, 'Urológiai vizsgálat', 'Vesebetegségek és urológiai kezelések', 22000, 30, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(6, 'Szemészeti vizsgálat', 'Látásproblémák és szürkehályog kezelése', 20000, 30, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(7, 'Reumatológiai kezelés', 'Mozgásszervi problémák kezelése', 19000, 40, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(8, 'Nőgyógyászati konzultáció', 'Terhesgondozás és szülészeti tanácsadás', 25000, 45, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(9, 'Gasztroenterológiai vizsgálat', 'Emésztési problémák és kezelések', 23000, 40, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(10, 'Fogászati ellenőrzés', 'Általános fogászati vizsgálatok', 17000, 30, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(11, 'Neurológiai konzultáció', 'Idegrendszeri betegségek kezelése', 21000, 45, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(12, 'Fül-orr-gégészeti vizsgálat', 'Fül-orr-gégészeti problémák kezelése', 18000, 30, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(13, 'Endokrinológiai vizsgálat', 'Hormonális problémák kezelése', 22000, 45, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(14, 'Gyermekorvosi vizsgálat', 'Gyermekkori betegségek kezelése', 15000, 30, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(15, 'Pszichológiai konzultáció', 'Mentális egészség és terápia', 20000, 60, 0, '2024-09-29 18:09:57', '2024-09-29 18:09:57', NULL, NULL, NULL),
(16, 'Ánusztágítás', 'hihihi', 50000, 30, 1, '2024-11-04 15:56:54', '2024-11-04 16:01:56', '2024-11-04 16:02:35', NULL, NULL);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `user_notifications`
--

CREATE TABLE `user_notifications` (
  `id` int(11) NOT NULL,
  `notification_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `user_notifications`
--

INSERT INTO `user_notifications` (`id`, `notification_id`, `user_id`) VALUES
(1, 1, 5),
(2, 2, 2),
(3, 3, 2),
(4, 4, 7),
(5, 5, 11),
(6, 6, 12),
(7, 7, 12),
(8, 8, 7),
(9, 9, 9),
(10, 10, 9),
(11, 11, 9),
(12, 12, 47),
(13, 13, 47),
(14, 14, 47),
(15, 15, 47),
(16, 16, 47),
(17, 17, 47),
(18, 18, 47),
(19, 19, 47),
(20, 20, 47),
(21, 21, 47),
(22, 22, 47),
(23, 23, 47),
(24, 24, 2),
(25, 25, 47),
(26, 26, 47),
(27, 27, 1),
(28, 28, 1),
(29, 29, 1),
(30, 30, 47),
(31, 31, 47),
(32, 32, 47),
(33, 33, 47),
(34, 34, 47),
(35, 35, 47),
(36, 36, 47),
(37, 37, 47),
(38, 38, 1),
(39, 39, 47),
(40, 40, 47),
(41, 41, 47),
(42, 42, 47),
(43, 43, 47),
(44, 44, 47),
(45, 45, 47),
(46, 46, 71),
(47, 47, 71),
(48, 48, 73);

--
-- Indexek a kiírt táblákhoz
--

--
-- A tábla indexei `appointments`
--
ALTER TABLE `appointments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `doctor_id` (`doctor_id`),
  ADD KEY `patient_id` (`patient_id`);

--
-- A tábla indexei `doctors`
--
ALTER TABLE `doctors`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `phone_number` (`phone_number`);

--
-- A tábla indexei `doctors_x_services`
--
ALTER TABLE `doctors_x_services`
  ADD PRIMARY KEY (`doctor_id`,`service_id`),
  ADD KEY `service_id` (`service_id`);

--
-- A tábla indexei `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`id`);

--
-- A tábla indexei `password_reset_tokens`
--
ALTER TABLE `password_reset_tokens`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_email` (`email`),
  ADD KEY `idx_token` (`token`);

--
-- A tábla indexei `patients`
--
ALTER TABLE `patients`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `id` (`phone_number`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `phone_number` (`phone_number`);

--
-- A tábla indexei `patient_verifications`
--
ALTER TABLE `patient_verifications`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `token` (`token`),
  ADD KEY `fk_patient_id` (`patient_id`);

--
-- A tábla indexei `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `appointment_id` (`appointment_id`);

--
-- A tábla indexei `reminders`
--
ALTER TABLE `reminders`
  ADD PRIMARY KEY (`id`),
  ADD KEY `appointment_id` (`appointment_id`);

--
-- A tábla indexei `reviews`
--
ALTER TABLE `reviews`
  ADD PRIMARY KEY (`id`),
  ADD KEY `doctor_id` (`doctor_id`),
  ADD KEY `patient_id` (`patient_id`);

--
-- A tábla indexei `schedules`
--
ALTER TABLE `schedules`
  ADD PRIMARY KEY (`id`),
  ADD KEY `doctor_id` (`doctor_id`);

--
-- A tábla indexei `services`
--
ALTER TABLE `services`
  ADD PRIMARY KEY (`id`);

--
-- A tábla indexei `user_notifications`
--
ALTER TABLE `user_notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `notification_id` (`notification_id`),
  ADD KEY `user_id` (`user_id`);

--
-- A kiírt táblák AUTO_INCREMENT értéke
--

--
-- AUTO_INCREMENT a táblához `appointments`
--
ALTER TABLE `appointments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=66;

--
-- AUTO_INCREMENT a táblához `doctors`
--
ALTER TABLE `doctors`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT a táblához `notifications`
--
ALTER TABLE `notifications`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=49;

--
-- AUTO_INCREMENT a táblához `password_reset_tokens`
--
ALTER TABLE `password_reset_tokens`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=27;

--
-- AUTO_INCREMENT a táblához `patients`
--
ALTER TABLE `patients`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=74;

--
-- AUTO_INCREMENT a táblához `patient_verifications`
--
ALTER TABLE `patient_verifications`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT a táblához `payments`
--
ALTER TABLE `payments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT a táblához `reminders`
--
ALTER TABLE `reminders`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT a táblához `reviews`
--
ALTER TABLE `reviews`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=39;

--
-- AUTO_INCREMENT a táblához `schedules`
--
ALTER TABLE `schedules`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=164;

--
-- AUTO_INCREMENT a táblához `services`
--
ALTER TABLE `services`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT a táblához `user_notifications`
--
ALTER TABLE `user_notifications`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=49;

--
-- Megkötések a kiírt táblákhoz
--

--
-- Megkötések a táblához `appointments`
--
ALTER TABLE `appointments`
  ADD CONSTRAINT `appointments_ibfk_1` FOREIGN KEY (`doctor_id`) REFERENCES `doctors` (`id`),
  ADD CONSTRAINT `appointments_ibfk_2` FOREIGN KEY (`patient_id`) REFERENCES `patients` (`id`);

--
-- Megkötések a táblához `doctors_x_services`
--
ALTER TABLE `doctors_x_services`
  ADD CONSTRAINT `doctors_x_services_ibfk_1` FOREIGN KEY (`doctor_id`) REFERENCES `doctors` (`id`),
  ADD CONSTRAINT `doctors_x_services_ibfk_2` FOREIGN KEY (`service_id`) REFERENCES `services` (`id`);

--
-- Megkötések a táblához `patient_verifications`
--
ALTER TABLE `patient_verifications`
  ADD CONSTRAINT `fk_patient_id` FOREIGN KEY (`patient_id`) REFERENCES `patients` (`id`) ON DELETE CASCADE;

--
-- Megkötések a táblához `payments`
--
ALTER TABLE `payments`
  ADD CONSTRAINT `payments_ibfk_1` FOREIGN KEY (`appointment_id`) REFERENCES `appointments` (`id`);

--
-- Megkötések a táblához `reminders`
--
ALTER TABLE `reminders`
  ADD CONSTRAINT `reminders_ibfk_1` FOREIGN KEY (`appointment_id`) REFERENCES `appointments` (`id`);

--
-- Megkötések a táblához `reviews`
--
ALTER TABLE `reviews`
  ADD CONSTRAINT `reviews_ibfk_1` FOREIGN KEY (`doctor_id`) REFERENCES `doctors` (`id`),
  ADD CONSTRAINT `reviews_ibfk_2` FOREIGN KEY (`patient_id`) REFERENCES `patients` (`id`);

--
-- Megkötések a táblához `schedules`
--
ALTER TABLE `schedules`
  ADD CONSTRAINT `schedules_ibfk_1` FOREIGN KEY (`doctor_id`) REFERENCES `doctors` (`id`);

--
-- Megkötések a táblához `user_notifications`
--
ALTER TABLE `user_notifications`
  ADD CONSTRAINT `user_notifications_ibfk_1` FOREIGN KEY (`notification_id`) REFERENCES `notifications` (`id`),
  ADD CONSTRAINT `user_notifications_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `patients` (`id`);
COMMIT;

ALTER TABLE `doctor_working_hours`
  ADD CONSTRAINT `fk_dwh_doctor` FOREIGN KEY (`doctor_id`) REFERENCES `doctors` (`id`) ON DELETE CASCADE;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;