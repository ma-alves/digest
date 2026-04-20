package com.example.digest.client;

import com.example.digest.models.response.NewsAPIResponse;
import io.netty.channel.ChannelOption;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;

import java.time.Duration;

public class NewsAPIClient {

    private final WebClient webClient;

    public NewsAPIClient(@Value("${newsapi.key}") String newsApiKey, @Value("${newsapi.base-url}") String baseURL) {
        HttpClient httpClient = HttpClient.create()
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 10000)
                .responseTimeout(Duration.ofSeconds(5));
        this.webClient = WebClient.builder()
                .baseUrl(baseURL)
                .defaultHeader("X-Api-Key", newsApiKey)
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .build();
    }

    // decidir se haveram parametros ou hardcoded
    public NewsAPIResponse getTopHeadlines(String country, String category) {
        return webClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/top-headlines")
                        .queryParam("country", country)
                        .queryParam("category", category)
                        .queryParam("pageSize", 10)
                        .build())
                .retrieve()
                .bodyToMono(NewsAPIResponse.class)
                .block();
    }
}
