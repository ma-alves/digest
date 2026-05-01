package com.example.digest.services;

import java.util.List;

public interface EmailService {
    void sendEmail(String toEmail, String subject, String htmlContent) throws Exception;

    void sendBulkEmails(List<String> toEmails, String subject, String htmlContent) throws Exception;
}
