package com.example.digest;

import com.example.digest.client.NewsAPIClient;
import com.example.digest.client.request.EverythingRequest;
import com.example.digest.client.request.TopHeadlinesRequest;
import com.example.digest.client.response.NewsAPIResponse;
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

//			TopHeadlinesRequest request = TopHeadlinesRequest.builder()
//					.country("us")
//					.category("technology")
//					.pageSize(10)
//					.build();
//
//			try {
//				NewsAPIResponse response = newsAPIClient.getTopHeadlines(request);
//
//				System.out.println("Status       : " + response.getStatus());
//				System.out.println("Total Results: " + response.getTotalResults());
//				System.out.println("--------------------------");
//
//				response.getArticles().forEach(article ->
//						System.out.printf("[%s] %s%n",
//								article.getSource() != null ? article.getSource().getName() : "N/A",
//								article.getTitle())
//				);
//
//			} catch (Exception e) {
//				System.err.println("ERROR: " + e.getMessage());
//				e.printStackTrace();
//			}

		EverythingRequest eRequest = EverythingRequest.builder()
				.q("ia")
				.searchIn("content,description")
				.language("pt")
				.from("2026-04-25")
//				.sortBy("relevancy")
				.pageSize(10)
				.build();

		try {
			NewsAPIResponse eResponse = newsAPIClient.getEverything(eRequest);

			System.out.println("\n=== Everything Endpoint Test ===");
			System.out.println("Status       : " + eResponse.getStatus());
			System.out.println("Total Results: " + eResponse.getTotalResults());
			System.out.println("--------------------------");

			eResponse.getArticles().forEach(article ->
					System.out.printf("[%s] - %s%n - %s%n",
							article.getSource() != null ? article.getSource().getName() : "N/A",
							article.getPublishedAt() != null ? article.getPublishedAt() : "N/A",
							article.getTitle())
			);

		} catch (Exception e) {
			System.err.println("ERROR: " + e.getMessage());
			e.printStackTrace();
		}

		System.out.println("=== Test Complete ===");
			System.exit(1);
		};
	}
}