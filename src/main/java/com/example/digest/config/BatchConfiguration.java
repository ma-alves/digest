package com.example.digest.config;

import com.example.digest.batch.EmailSendingTasklet;
import com.example.digest.batch.NewsArticleTasklet;
import com.example.digest.batch.NewsletterGenerationTasklet;
import com.example.digest.batch.NewsletterJobExecutionListener;
import org.springframework.batch.core.job.Job;
import org.springframework.batch.core.step.Step;
import org.springframework.batch.core.configuration.annotation.EnableBatchProcessing;
import org.springframework.batch.core.job.builder.JobBuilder;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.core.step.builder.StepBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.transaction.PlatformTransactionManager;

@Configuration
@EnableBatchProcessing
public class BatchConfiguration {

    @Bean
    public Step fetchArticlesStep(JobRepository jobRepository, PlatformTransactionManager transactionManager,
                                   NewsArticleTasklet newsArticleTasklet) {
        return new StepBuilder("fetchArticlesStep", jobRepository)
                .tasklet(newsArticleTasklet, transactionManager)
                .build();
    }

    @Bean
    public Step generateNewsletterStep(JobRepository jobRepository, PlatformTransactionManager transactionManager,
                                        NewsletterGenerationTasklet newsletterGenerationTasklet) {
        return new StepBuilder("generateNewsletterStep", jobRepository)
                .tasklet(newsletterGenerationTasklet, transactionManager)
                .build();
    }

    @Bean
    public Step sendEmailsStep(JobRepository jobRepository, PlatformTransactionManager transactionManager,
                                EmailSendingTasklet emailSendingTasklet) {
        return new StepBuilder("sendEmailsStep", jobRepository)
                .tasklet(emailSendingTasklet, transactionManager)
                .build();
    }

    @Bean
    public Job newsletterJob(JobRepository jobRepository, Step fetchArticlesStep, Step generateNewsletterStep, 
                            Step sendEmailsStep, NewsletterJobExecutionListener jobExecutionListener) {
        return new JobBuilder("newsletterJob", jobRepository)
                .start(fetchArticlesStep)
                .next(generateNewsletterStep)
                .next(sendEmailsStep)
                .listener(jobExecutionListener)
                .build();
    }
}
