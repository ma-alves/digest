package com.example.digest.models;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;

import java.time.LocalDateTime;

@Entity
@Table(name = "mails")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Mail {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "subject", nullable = false)
    private String subject;

    @Column(name = "recipient_email", nullable = false)
    private String recipientEmail;

    @Column(name = "status", nullable = false)
    private String status; // PENDING, SENT, FAILED

    @Column(name = "error_message")
    private String errorMessage;

    @CreatedDate
    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "sent_at")
    private LocalDateTime sentAt;

    @ManyToOne
    @JoinColumn(name = "newsletter_id")
    private Newsletter newsletter;
}
