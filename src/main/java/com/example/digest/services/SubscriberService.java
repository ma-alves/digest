package com.example.digest.services;

import com.example.digest.dto.SubscriberDTO;
import com.example.digest.exceptions.DuplicateEmailException;
import com.example.digest.exceptions.UserNotFoundException;
import com.example.digest.models.Subscriber;
import com.example.digest.repositories.SubscriberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Locale;

@Service
@RequiredArgsConstructor
public class SubscriberService {

    private final SubscriberRepository subscriberRepository;

    public SubscriberDTO insertSubscriber(SubscriberDTO subscriberDTO) {
        String emailSanitized = subscriberDTO.email().toLowerCase(Locale.ROOT);

        if (subscriberRepository.existsByEmail(emailSanitized)) {
            throw new DuplicateEmailException();
        }

        Subscriber subscriber = subscriberDTO.toEntity();
        subscriber.setEmail(emailSanitized);
        subscriberRepository.save(subscriber);

        return SubscriberDTO.toDTO(subscriber);
    }

    public List<Subscriber> getSubscribers() {
        return subscriberRepository.findAll();
    }

    public Subscriber getSubscriberByEmail(Long email) {
        return subscriberRepository.findById(email)
                .orElseThrow(UserNotFoundException::new);
    }
}
