package com.example.digest.repositories;

import com.example.digest.models.Newsletter;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface NewsletterRepository extends JpaRepository<Newsletter, Long> {
    List<Newsletter> findByStatus(String status);
    List<Newsletter> findByGeneratedAtAfter(LocalDateTime dateTime);
}
