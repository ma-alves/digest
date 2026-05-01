package com.example.digest.config;

import org.quartz.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.quartz.CronTriggerFactoryBean;
import org.springframework.scheduling.quartz.JobDetailFactoryBean;
import org.springframework.scheduling.quartz.SchedulerFactoryBean;

@Configuration
public class QuartzSchedulerConfig {

    @Value("${newsletter.schedule.cron:0 0 8 * * ?}")
    private String cronExpression;

    @Bean
    public JobDetailFactoryBean newsletterJobDetail() {
        JobDetailFactoryBean jobDetail = new JobDetailFactoryBean();
        jobDetail.setJobClass(NewsletterJobLauncher.class);
        jobDetail.setName("newsletterJob");
        jobDetail.setGroup("digest");
        jobDetail.setDurability(true);
        return jobDetail;
    }

    @Bean
    public CronTriggerFactoryBean newsletterTrigger(JobDetail newsletterJobDetail) {
        CronTriggerFactoryBean trigger = new CronTriggerFactoryBean();
        trigger.setJobDetail(newsletterJobDetail);
        trigger.setName("newsletterTrigger");
        trigger.setGroup("digest");
        trigger.setCronExpression(cronExpression);
        return trigger;
    }

    @Bean
    public SchedulerFactoryBean schedulerFactory(CronTriggerFactoryBean newsletterTrigger,
                                                  JobDetail newsletterJobDetail) {
        SchedulerFactoryBean schedulerFactory = new SchedulerFactoryBean();
        schedulerFactory.setJobDetails(newsletterJobDetail);
        schedulerFactory.setTriggers(newsletterTrigger.getObject());
        schedulerFactory.setSchedulerName("digestScheduler");
        schedulerFactory.setAutoStartup(true);
        schedulerFactory.setWaitForJobsToCompleteOnShutdown(true);
        return schedulerFactory;
    }
}
