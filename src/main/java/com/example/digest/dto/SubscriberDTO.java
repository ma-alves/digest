package com.example.digest.dto;

import com.example.digest.models.Subscriber;
import jakarta.validation.constraints.*;

import java.time.LocalDateTime;

public record SubscriberDTO(

    @NotBlank(message = "Formato do e-mail inválido.")
    @Email(message = "Formato do e-mail inválido")
    String email

) { // pesquisar que porra é essa
    public Subscriber toEntity() {
        return Subscriber.builder()
                .email(this.email)
                .createdAt(LocalDateTime.now())
                .build();
    }

    public static SubscriberDTO toDTO(Subscriber subscriber) {
        return new SubscriberDTO(subscriber.getEmail());
    }
}