package com.example.digest.batch;

import org.springframework.batch.core.job.JobExecution;
import org.springframework.batch.core.listener.JobExecutionListener;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

@Component
public class NewsletterJobExecutionListener implements JobExecutionListener {

    @Override
    public void beforeJob(JobExecution jobExecution) {
        System.out.println("========================================");
        System.out.println("📬 Newsletter Job Starting");
        System.out.println("   Job Name: " + jobExecution.getJobInstance().getJobName());
        System.out.println("   Start Time: " + LocalDateTime.now());
        System.out.println("========================================");
    }

    @Override
    public void afterJob(JobExecution jobExecution) {
        System.out.println("========================================");
        System.out.println("📬 Newsletter Job Completed");
        System.out.println("   Status: " + jobExecution.getStatus());
        System.out.println("   Exit Status: " + jobExecution.getExitStatus().getExitCode());
        System.out.println("   End Time: " + LocalDateTime.now());

        if (jobExecution.getStatus().isUnsuccessful()) {
            System.out.println("   ❌ Failures:");
            jobExecution.getAllFailureExceptions().forEach(ex ->
                    System.out.println("      - " + ex.getMessage())
            );
        } else {
            System.out.println("   ✅ All steps completed successfully");
        }

        System.out.println("========================================");
    }
}
