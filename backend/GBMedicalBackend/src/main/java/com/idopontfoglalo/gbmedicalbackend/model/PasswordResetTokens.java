/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.idopontfoglalo.gbmedicalbackend.model;

import javax.persistence.Basic;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.NamedQueries;
import javax.persistence.NamedQuery;
import javax.persistence.Table;
import javax.persistence.Temporal;
import javax.persistence.TemporalType;
import javax.xml.bind.annotation.XmlRootElement;
import java.io.Serializable;
import java.util.Date;
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Size;

/**
 *
 * @author szabo
 */
@Entity
@Table(name = "password_reset_tokens")
@XmlRootElement
@NamedQueries({
    @NamedQuery(name = "PasswordResetTokens.findAll", query = "SELECT p FROM PasswordResetTokens p"),
    @NamedQuery(name = "PasswordResetTokens.findById", query = "SELECT p FROM PasswordResetTokens p WHERE p.id = :id"),
    @NamedQuery(name = "PasswordResetTokens.findByEmail", query = "SELECT p FROM PasswordResetTokens p WHERE p.email = :email"),
    @NamedQuery(name = "PasswordResetTokens.findByToken", query = "SELECT p FROM PasswordResetTokens p WHERE p.token = :token"),
    @NamedQuery(name = "PasswordResetTokens.findByExpiresAt", query = "SELECT p FROM PasswordResetTokens p WHERE p.expiresAt = :expiresAt"),
    @NamedQuery(name = "PasswordResetTokens.findByUsed", query = "SELECT p FROM PasswordResetTokens p WHERE p.used = :used"),
    @NamedQuery(name = "PasswordResetTokens.findByCreatedAt", query = "SELECT p FROM PasswordResetTokens p WHERE p.createdAt = :createdAt")})
public class PasswordResetTokens implements Serializable {

    private static final long serialVersionUID = 1L;
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Basic(optional = false)
    @Column(name = "id")
    private Integer id;
    // @Pattern(regexp="[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?", message="Invalid email")//if the field contains email address consider using this annotation to enforce field validation
    @Basic(optional = false)
    @NotNull
    @Size(min = 1, max = 255)
    @Column(name = "email")
    private String email;
    @Basic(optional = false)
    @NotNull
    @Size(min = 1, max = 255)
    @Column(name = "token")
    private String token;
    @Basic(optional = false)
    @NotNull
    @Column(name = "expires_at")
    @Temporal(TemporalType.TIMESTAMP)
    private Date expiresAt;
    @Basic(optional = false)
    @NotNull
    @Column(name = "used")
    private boolean used;
    @Basic(optional = false)
    @NotNull
    @Column(name = "created_at")
    @Temporal(TemporalType.TIMESTAMP)
    private Date createdAt;

    public PasswordResetTokens() {
    }

    public PasswordResetTokens(Integer id) {
        this.id = id;
    }

    public PasswordResetTokens(Integer id, String email, String token, Date expiresAt, boolean used, Date createdAt) {
        this.id = id;
        this.email = email;
        this.token = token;
        this.expiresAt = expiresAt;
        this.used = used;
        this.createdAt = createdAt;
    }

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getToken() {
        return token;
    }

    public void setToken(String token) {
        this.token = token;
    }

    public Date getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(Date expiresAt) {
        this.expiresAt = expiresAt;
    }

    public boolean getUsed() {
        return used;
    }

    public void setUsed(boolean used) {
        this.used = used;
    }

    public Date getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Date createdAt) {
        this.createdAt = createdAt;
    }

    @Override
    public int hashCode() {
        int hash = 0;
        hash += (id != null ? id.hashCode() : 0);
        return hash;
    }

    @Override
    public boolean equals(Object object) {
        // TODO: Warning - this method won't work in the case the id fields are not set
        if (!(object instanceof PasswordResetTokens)) {
            return false;
        }
        PasswordResetTokens other = (PasswordResetTokens) object;
        if ((this.id == null && other.id != null) || (this.id != null && !this.id.equals(other.id))) {
            return false;
        }
        return true;
    }

    @Override
    public String toString() {
        return "com.idopontfoglalo.gbmedicalbackend.model.PasswordResetTokens[ id=" + id + " ]";
    }

}
