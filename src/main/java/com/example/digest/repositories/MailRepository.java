package com.example.digest.repositories;

import com.example.digest.models.Mail;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface MailRepository extends JpaRepository<Mail, Long> {
    List<Mail> findByStatus(String status);
    List<Mail> findByRecipientEmailAndStatus(String recipientEmail, String status);
    List<Mail> findBySentAtAfter(LocalDateTime dateTime);
}
