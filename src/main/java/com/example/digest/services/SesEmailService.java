package com.example.digest.services;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.ses.SesClient;
import software.amazon.awssdk.services.ses.model.*;

import java.util.List;

@Service
public class SesEmailService implements EmailService {

    private final SesClient sesClient;

    @Value("${aws.ses.from-email:noreply@digest.local}")
    private String fromEmail;

    @Value("${aws.ses.max-retries:3}")
    private Integer maxRetries;

    public SesEmailService(SesClient sesClient) {
        this.sesClient = sesClient;
    }

    @Override
    public void sendEmail(String toEmail, String subject, String htmlContent) throws Exception {
        sendWithRetry(List.of(toEmail), subject, htmlContent, 0);
    }

    @Override
    public void sendBulkEmails(List<String> toEmails, String subject, String htmlContent) throws Exception {
        int batchSize = 50; // SES batch limit
        for (int i = 0; i < toEmails.size(); i += batchSize) {
            int end = Math.min(i + batchSize, toEmails.size());
            List<String> batch = toEmails.subList(i, end);
            sendWithRetry(batch, subject, htmlContent, 0);
        }
    }

    private void sendWithRetry(List<String> toEmails, String subject, String htmlContent, int attempt) throws Exception {
        try {
            SendEmailRequest request = SendEmailRequest.builder()
                    .source(fromEmail)
                    .destination(Destination.builder()
                            .toAddresses(toEmails)
                            .build())
                    .message(Message.builder()
                            .subject(Content.builder()
                                    .data(subject)
                                    .charset("UTF-8")
                                    .build())
                            .body(Body.builder()
                                    .html(Content.builder()
                                            .data(htmlContent)
                                            .charset("UTF-8")
                                            .build())
                                    .build())
                            .build())
                    .build();

            sesClient.sendEmail(request);
            System.out.println("✓ Email sent to " + toEmails.size() + " recipient(s)");

        } catch (SesException e) {
            if (attempt < maxRetries) {
                System.out.println("⚠ Retry " + (attempt + 1) + "/" + maxRetries + " - " + e.getMessage());
                Thread.sleep(1000 * (long) Math.pow(2, attempt)); // Exponential backoff
                sendWithRetry(toEmails, subject, htmlContent, attempt + 1);
            } else {
                System.err.println("✗ Failed to send email after " + maxRetries + " retries: " + e.getMessage());
                throw new RuntimeException("Failed to send email", e);
            }
        }
    }
}
