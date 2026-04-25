package com.example.digest.client;

import com.example.digest.models.request.NewsAPIRequest;
import com.example.digest.models.response.NewsAPIResponse;
import io.netty.channel.ChannelOption;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;
import reactor.netty.http.client.HttpClient;

import java.time.Duration;
import java.util.Optional;

@Service
public class NewsAPIClient {

    private static final String BASE_URL = "https://newsapi.org/v2";

    private final WebClient webClient;

    public NewsAPIClient(@Value("${newsapi.api-key}") String apiKey) {
        HttpClient httpClient = HttpClient.create()
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 10000)
                .responseTimeout(Duration.ofSeconds(5));
        this.webClient = WebClient.builder()
                .baseUrl(BASE_URL)
                .defaultHeader("X-Api-Key", apiKey)
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .build();
    }

    public NewsAPIResponse getTopHeadlines(NewsAPIRequest newsAPIRequest) {
        return webClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/top-headlines")
                        .queryParam("country", newsAPIRequest.getCountry())
                        .queryParam("category", newsAPIRequest.getCategory())
                        .queryParam("pageSize", newsAPIRequest.getPageSize())
                        .queryParamIfPresent("sources", Optional.ofNullable(newsAPIRequest.getSources()))
                        .queryParamIfPresent("q", Optional.ofNullable(newsAPIRequest.getQ()))
                        .queryParamIfPresent("page", Optional.ofNullable(newsAPIRequest.getPage()))
                        .build())
                .retrieve()
                .onStatus(HttpStatusCode::is4xxClientError, response ->
                        Mono.error(new RuntimeException("NewsAPI client error: " + response.statusCode())))
                .onStatus(HttpStatusCode::is5xxServerError, response ->
                        Mono.error(new RuntimeException("NewsAPI server error: " + response.statusCode())))
                .bodyToMono(NewsAPIResponse.class)
                .timeout(Duration.ofSeconds(5))
                .block();
    }
}