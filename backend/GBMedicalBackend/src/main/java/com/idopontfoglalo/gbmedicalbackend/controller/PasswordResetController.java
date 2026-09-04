package com.idopontfoglalo.gbmedicalbackend.controller;

import com.idopontfoglalo.gbmedicalbackend.model.PasswordResetTokens;
import com.idopontfoglalo.gbmedicalbackend.model.Patients;
import com.idopontfoglalo.gbmedicalbackend.service.EmailService;
import com.idopontfoglalo.gbmedicalbackend.service.PasswordResetService;
import javax.inject.Inject;
import javax.ws.rs.Consumes;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import org.json.JSONObject;
import java.net.URLEncoder;

@Path("password")
public class PasswordResetController {

    @Inject
    private PasswordResetService passwordResetService;

    /**
     * Endpoint a jelszó-visszaállítási kérelemhez. Várja az email címet
     * JSON-ben, majd létrehozza a token-t és elküldi a reset linket.
     */
    @POST
    @Path("forgotPassword")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response forgotPassword(String body) {
        try {
            JSONObject json = new JSONObject(body);
            String email = json.getString("email");

            // Ellenőrizzük, hogy létezik-e a felhasználó
            if (!Patients.isPatientExists(email)) {
                JSONObject responseJson = new JSONObject();
                responseJson.put("message", "Az email cím nem található. Biztos regisztráltál már?");
                responseJson.put("statusCode", Response.Status.NOT_FOUND.getStatusCode());
                return Response.status(Response.Status.NOT_FOUND).entity(responseJson.toString()).build();
            }

            // Token generálása és adatbázisba mentése
            PasswordResetTokens tokenEntity = passwordResetService.createPasswordResetToken(email);

            // Összeállítjuk a visszaállító linket
            String resetLink = "http://localhost:4200/newPassword?token="
                    + tokenEntity.getToken() + "&email=" + URLEncoder.encode(email, "UTF-8");

            // Email küldése a visszaállító linkkel
            boolean emailSent = passwordResetService.sendEmail(email, resetLink, EmailService.EmailType.PASSWORD_RESET);

            JSONObject responseJson = new JSONObject();
            responseJson.put("message", emailSent ? "A visszaállító email elküldve." : "Hiba történt az email küldése során.");
            responseJson.put("statusCode", Response.Status.OK.getStatusCode());
            return Response.ok(responseJson.toString()).build();
        } catch (Exception ex) {
            ex.printStackTrace();
            JSONObject responseJson = new JSONObject();
            responseJson.put("message", "Belső hiba történt a jelszó visszaállítás kérése során.");
            responseJson.put("statusCode", Response.Status.INTERNAL_SERVER_ERROR.getStatusCode());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR).entity(responseJson.toString()).build();
        }
    }

    /**
     * Jelszó visszaállító endpoint. A felhasználónak meg kell adnia az email
     * címét, a kapott tokent és az új jelszót.
     */
    @POST
    @Path("resetPassword")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response resetPassword(String body) {
        try {
            JSONObject json = new JSONObject(body);
            String email = json.getString("email");
            String token = json.getString("token");
            String newPassword = json.getString("newPassword");

            // Ellenőrizzük a tokent az adatbázisban
            boolean isValidToken = passwordResetService.validateToken(email, token);

            if (!isValidToken) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(new JSONObject().put("message", "Érvénytelen vagy lejárt token!").toString())
                        .build();
            }

            // Jelszó hash-elése és frissítése
            passwordResetService.updatePatientPassword(email, newPassword);

            return Response.ok(new JSONObject().put("message", "A jelszavad sikeresen frissült!").toString()).build();
        } catch (Exception ex) {
            ex.printStackTrace();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(new JSONObject().put("message", "Hiba történt a jelszó visszaállítása során.").toString())
                    .build();
        }
    }
}
