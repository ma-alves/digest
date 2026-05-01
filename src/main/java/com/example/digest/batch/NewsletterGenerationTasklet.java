package com.example.digest.batch;

import com.example.digest.client.response.NewsAPIResponse;
import com.example.digest.models.Newsletter;
import com.example.digest.repositories.NewsletterRepository;
import org.springframework.batch.core.step.StepContribution;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.infrastructure.repeat.RepeatStatus;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.view.freemarker.FreeMarkerConfigurer;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;

import java.time.LocalDateTime;

@Component
public class NewsletterGenerationTasklet implements Tasklet {

    private final NewsletterRepository newsletterRepository;
    private final TemplateEngine templateEngine;

    public NewsletterGenerationTasklet(NewsletterRepository newsletterRepository, TemplateEngine templateEngine) {
        this.newsletterRepository = newsletterRepository;
        this.templateEngine = templateEngine;
    }

    @Override
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
        try {
            // Get articles from previous step
            NewsAPIResponse response = (NewsAPIResponse) chunkContext.getStepContext()
                    .getStepExecution()
                    .getJobExecution()
                    .getExecutionContext()
                    .get("newsApiResponse");

            if (response == null || response.getArticles().isEmpty()) {
                throw new RuntimeException("No articles available for newsletter generation");
            }

            // Prepare Thymeleaf context
            Context context = new Context();
            context.setVariable("articles", response.getArticles());
            context.setVariable("generatedAt", LocalDateTime.now());
            context.setVariable("articleCount", response.getArticles().size());

            // Generate HTML content from template
            String htmlContent = templateEngine.process("newsletter-email", context);

            // Create and save Newsletter entity
            Newsletter newsletter = Newsletter.builder()
                    .title("Daily Newsletter - " + LocalDateTime.now().toLocalDate())
                    .articleCount(response.getArticles().size())
                    .status("GENERATED")
                    .generatedAt(LocalDateTime.now())
                    .build();

            Newsletter savedNewsletter = newsletterRepository.save(newsletter);

            // Store newsletter in execution context for next step
            chunkContext.getStepContext()
                    .getStepExecution()
                    .getJobExecution()
                    .getExecutionContext()
                    .put("newsletter", savedNewsletter);

            chunkContext.getStepContext()
                    .getStepExecution()
                    .getJobExecution()
                    .getExecutionContext()
                    .put("htmlContent", htmlContent);

            System.out.println("✓ Generated newsletter with " + response.getArticles().size() + " articles");
            contribution.incrementWriteCount(1);

            return RepeatStatus.FINISHED;
        } catch (Exception e) {
            System.err.println("✗ Error generating newsletter: " + e.getMessage());
            e.printStackTrace();
            throw new RuntimeException("Failed to generate newsletter", e);
        }
    }
}
