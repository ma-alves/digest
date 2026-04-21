package com.example.digest.controllers;

import com.example.digest.dto.SubscriberDTO;
import com.example.digest.services.SubscriberService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class SubscriberController {

    private final SubscriberService subscriberService;

    public SubscriberController(SubscriberService subscriberService) {
        this.subscriberService = subscriberService;
    }

    @PostMapping
    public ResponseEntity<SubscriberDTO> createSubscriber(@Valid @RequestBody SubscriberDTO subscriberDTO) {
        SubscriberDTO createdSubscriber = subscriberService.createSubscriber(subscriberDTO);
        return ResponseEntity.status(HttpStatus.CREATED).body(createdSubscriber);
    }
}
