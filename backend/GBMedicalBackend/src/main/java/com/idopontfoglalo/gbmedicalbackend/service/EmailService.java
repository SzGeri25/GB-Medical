package com.idopontfoglalo.gbmedicalbackend.service;

import javax.mail.Authenticator;
import javax.mail.Message;
import javax.mail.PasswordAuthentication;
import javax.mail.Session;
import javax.mail.Transport;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeMessage;
import java.util.Properties;

public class EmailService {

    private static final String FROM_EMAIL = "szabo.gergely25@gmail.com";
    private static final String PASSWORD = "bequ fkqs xwto sprv";  // Biztonsági okokból ne tárold nyílt szövegként

    // Enum a különböző email típusokhoz
    public enum EmailType {
        REGISTRATION_CONFIRMATION,
        APPOINTMENT_CONFIRMATION,
        APPOINTMENT_CANCELLATION, // Új enum érték hozzáadva
        PASSWORD_RESET
    }

    // Küldés metódus, amely figyelembe veszi az email típusát
    public static boolean sendEmail(String to, EmailType emailType, String additionalContent) {
        try {
            // SMTP beállítások a Gmail esetében
            Properties properties = new Properties();
            properties.put("mail.smtp.host", "smtp.gmail.com");
            properties.put("mail.smtp.port", "465");
            properties.put("mail.smtp.ssl.enable", "true");
            properties.put("mail.smtp.auth", "true");

            Session session = Session.getInstance(properties, new Authenticator() {
                @Override
                protected PasswordAuthentication getPasswordAuthentication() {
                    return new PasswordAuthentication(FROM_EMAIL, PASSWORD);
                }
            });

            session.setDebug(true);

            MimeMessage message = new MimeMessage(session);
            message.setFrom(new InternetAddress(FROM_EMAIL));
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(to));

            // Téma és tartalom beállítása email típus alapján
            String subject = "";
            String content = "";

            switch (emailType) {
                case REGISTRATION_CONFIRMATION:
                    subject = "Regisztráció megerősítése";
                    content = "<p>Kattintson az alábbi linkre, hogy megerősítse a regisztrációját: <br>"
                            + "<a href=\"" + additionalContent + "\">Megerősítés</a></p>";
                    break;
                case APPOINTMENT_CONFIRMATION:
                    subject = "Időpontfoglalás megerősítése";
                    content = additionalContent;
                    break;
                case APPOINTMENT_CANCELLATION: // Új case ág a lemondáshoz
                    subject = "Időpont lemondás megerősítése";
                    content = additionalContent;
                    break;
                case PASSWORD_RESET:
                    subject = "Jelszó visszaállítás";
                    content = "<p>Kattintson az alábbi linkre, hogy visszaállítsa a jelszavát: <br>"
                            + "<a href=\"" + additionalContent + "\">Visszaállítás</a></p>";
                    break;
                default:
                    throw new IllegalArgumentException("Nem támogatott email típus: " + emailType);
            }

            message.setSubject(subject);
            message.setContent(content, "text/html;charset=utf-8");

            // Email küldése
            Transport.send(message);
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
}
