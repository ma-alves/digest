package com.example.digest.batch;

import com.example.digest.models.Mail;
import com.example.digest.models.Newsletter;
import com.example.digest.repositories.MailRepository;
import com.example.digest.repositories.SubscriberRepository;
import com.example.digest.services.EmailService;
import org.springframework.batch.core.step.StepContribution;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.infrastructure.repeat.RepeatStatus;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.List;

@Component
public class EmailSendingTasklet implements Tasklet {

    private final EmailService emailService;
    private final SubscriberRepository subscriberRepository;
    private final MailRepository mailRepository;

    public EmailSendingTasklet(EmailService emailService, SubscriberRepository subscriberRepository,
                              MailRepository mailRepository) {
        this.emailService = emailService;
        this.subscriberRepository = subscriberRepository;
        this.mailRepository = mailRepository;
    }

    @Override
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
        try {
            // Get newsletter and HTML content from execution context
            Newsletter newsletter = (Newsletter) chunkContext.getStepContext()
                    .getStepExecution()
                    .getJobExecution()
                    .getExecutionContext()
                    .get("newsletter");

            String htmlContent = (String) chunkContext.getStepContext()
                    .getStepExecution()
                    .getJobExecution()
                    .getExecutionContext()
                    .get("htmlContent");

            if (newsletter == null || htmlContent == null) {
                throw new RuntimeException("Missing newsletter or HTML content from previous steps");
            }

            // Fetch all subscriber emails
            List<String> subscriberEmails = subscriberRepository.findAll()
                    .stream()
                    .map(subscriber -> subscriber.getEmail())
                    .toList();

            if (subscriberEmails.isEmpty()) {
                System.out.println("⚠ No subscribers found. Skipping email sending.");
                newsletter.setStatus("SENT");
                newsletter.setSentAt(LocalDateTime.now());
                return RepeatStatus.FINISHED;
            }

            // Send bulk emails
            String subject = "Your Daily Newsletter - " + LocalDateTime.now().toLocalDate();
            try {
                emailService.sendBulkEmails(subscriberEmails, subject, htmlContent);

                // Log successful sends
                for (String email : subscriberEmails) {
                    Mail mail = Mail.builder()
                            .subject(subject)
                            .recipientEmail(email)
                            .status("SENT")
                            .sentAt(LocalDateTime.now())
                            .newsletter(newsletter)
                            .build();
                    mailRepository.save(mail);
                }

                // Update newsletter status
                newsletter.setStatus("SENT");
                newsletter.setSentAt(LocalDateTime.now());

                System.out.println("✓ Newsletter sent to " + subscriberEmails.size() + " subscribers");
                contribution.incrementWriteCount(subscriberEmails.size());

            } catch (Exception e) {
                System.err.println("✗ Error sending emails: " + e.getMessage());

                // Log failed sends
                for (String email : subscriberEmails) {
                    Mail mail = Mail.builder()
                            .subject(subject)
                            .recipientEmail(email)
                            .status("FAILED")
                            .errorMessage(e.getMessage())
                            .newsletter(newsletter)
                            .build();
                    mailRepository.save(mail);
                }

                // Update newsletter status
                newsletter.setStatus("FAILED");
                throw new RuntimeException("Failed to send newsletters", e);
            }

            return RepeatStatus.FINISHED;
        } catch (Exception e) {
            System.err.println("✗ Error in email sending tasklet: " + e.getMessage());
            e.printStackTrace();
            throw new RuntimeException("Email sending tasklet failed", e);
        }
    }
}
