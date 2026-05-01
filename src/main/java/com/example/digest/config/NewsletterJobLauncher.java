package com.example.digest.config;

import org.quartz.Job;
import org.quartz.JobExecutionContext;
import org.quartz.JobExecutionException;
import org.springframework.batch.core.job.parameters.JobParameters;
import org.springframework.batch.core.job.parameters.JobParametersBuilder;
import org.springframework.batch.core.launch.JobLauncher;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

@Component
public class NewsletterJobLauncher implements Job {

    @Autowired
    private JobLauncher jobLauncher;

    @Autowired
    private org.springframework.batch.core.job.Job newsletterJob;

    @Override
    public void execute(JobExecutionContext context) throws JobExecutionException {
        try {
            // Create unique job parameters to allow multiple executions
            JobParameters jobParameters = new JobParametersBuilder()
                    .addLong("executionTime", System.currentTimeMillis())
                    .toJobParameters();

            System.out.println("🚀 Starting newsletter job at " + LocalDateTime.now());
            jobLauncher.run(newsletterJob, jobParameters);
            System.out.println("✅ Newsletter job completed successfully");

        } catch (Exception e) {
            System.err.println("❌ Newsletter job failed: " + e.getMessage());
            e.printStackTrace();
            throw new JobExecutionException("Newsletter job execution failed", e);
        }
    }
}
