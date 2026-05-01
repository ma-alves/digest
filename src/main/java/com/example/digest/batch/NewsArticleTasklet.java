package com.example.digest.batch;

import com.example.digest.client.NewsAPIClient;
import com.example.digest.client.request.EverythingRequest;
import com.example.digest.client.response.NewsAPIResponse;
import org.springframework.batch.core.step.StepContribution;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.infrastructure.repeat.RepeatStatus;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@Component
public class NewsArticleTasklet implements Tasklet {

    private final NewsAPIClient newsAPIClient;

    @Value("${newsletter.search-query:technology}")
    private String searchQuery;

    @Value("${newsletter.language:en}")
    private String language;

    @Value("${newsletter.article-count:10}")
    private Integer articleCount;

    public NewsArticleTasklet(NewsAPIClient newsAPIClient) {
        this.newsAPIClient = newsAPIClient;
    }

    @Override
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
        try {
            // Calculate date for yesterday (to get fresh articles daily)
            LocalDate yesterday = LocalDate.now().minusDays(1);
            String fromDate = yesterday.format(DateTimeFormatter.ISO_DATE);

            // Build request with configuration values
            EverythingRequest request = EverythingRequest.builder()
                    .q(searchQuery)
                    .language(language)
                    .from(fromDate)
                    .pageSize(articleCount)
                    .sortBy("publishedAt")
                    .build();

            // Fetch articles from NewsAPI
            NewsAPIResponse response = newsAPIClient.getEverything(request);

            // Store response in execution context for next step
            chunkContext.getStepContext()
                    .getStepExecution()
                    .getJobExecution()
                    .getExecutionContext()
                    .put("newsApiResponse", response);

            // Log success
            System.out.println("✓ Fetched " + response.getArticles().size() + " articles from NewsAPI");
            contribution.incrementReadCount();

            return RepeatStatus.FINISHED;
        } catch (Exception e) {
            System.err.println("✗ Error fetching articles: " + e.getMessage());
            e.printStackTrace();
            throw new RuntimeException("Failed to fetch articles from NewsAPI", e);
        }
    }
}
