package com.example.digest;

import com.example.digest.client.NewsAPIClient;
import com.example.digest.models.request.NewsAPIRequest;
import com.example.digest.models.response.NewsAPIResponse;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class DigestApplication {

	public static void main(String[] args) {
		SpringApplication.run(DigestApplication.class, args);
	}

	@Bean
	public CommandLineRunner run(NewsAPIClient newsAPIClient) {
		return args -> {
			System.out.println("=== NewsAPI Client Test ===");

			NewsAPIRequest request = new NewsAPIRequest("us", "technology", 10);

			try {
				NewsAPIResponse response = newsAPIClient.getTopHeadlines(request);

				System.out.println("Status       : " + response.getStatus());
				System.out.println("Total Results: " + response.getTotalResults());
				System.out.println("--------------------------");

				response.getArticles().forEach(article ->
						System.out.printf("[%s] %s%n",
								article.getSource() != null ? article.getSource().getName() : "N/A",
								article.getTitle())
				);

			} catch (Exception e) {
				System.err.println("ERROR: " + e.getMessage());
				e.printStackTrace();
			}

			System.out.println("=== Test Complete ===");
		};
	}
}