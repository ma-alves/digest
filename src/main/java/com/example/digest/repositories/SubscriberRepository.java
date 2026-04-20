package com.example.digest.repositories;

import com.example.digest.models.Subscriber;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.List;

@Repository
public interface SubscriberRepository extends  JpaRepository<Subscriber, Long> {
    // Optional permite .orElse()
    Optional<Subscriber> findByEmail(String email);

    List<Subscriber> findAllByOrderByCreatedAtAsc();

    List<Subscriber> findAllByOrderByCreatedAtDesc();

    boolean existsByEmail(String email);
}
