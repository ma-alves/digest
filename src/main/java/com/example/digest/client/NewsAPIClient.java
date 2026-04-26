package com.example.digest.client;

import com.example.digest.models.request.TopHeadlinesRequest;
import com.example.digest.models.request.EverythingRequest;
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

    public NewsAPIResponse getTopHeadlines(TopHeadlinesRequest topHeadlinesRequest) {
        return webClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/top-headlines")
                        .queryParam("country", topHeadlinesRequest.getCountry())
                        .queryParam("category", topHeadlinesRequest.getCategory())
                        .queryParam("pageSize", topHeadlinesRequest.getPageSize())
                        .queryParamIfPresent("sources", Optional.ofNullable(topHeadlinesRequest.getSources()))
                        .queryParamIfPresent("q", Optional.ofNullable(topHeadlinesRequest.getQ()))
                        .queryParamIfPresent("page", Optional.ofNullable(topHeadlinesRequest.getPage()))
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

    public NewsAPIResponse getEverything(EverythingRequest everythingRequest) {
        return webClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/everything")
                        .queryParamIfPresent("q", Optional.ofNullable(everythingRequest.getQ()))
                        .queryParamIfPresent("sources", Optional.ofNullable(everythingRequest.getSources()))
                        .queryParamIfPresent("domains", Optional.ofNullable(everythingRequest.getDomains()))
                        .queryParamIfPresent("excludeDomains", Optional.ofNullable(everythingRequest.getExcludeDomains()))
                        .queryParamIfPresent("from", Optional.ofNullable(everythingRequest.getFrom()))
                        .queryParamIfPresent("to", Optional.ofNullable(everythingRequest.getTo()))
                        .queryParamIfPresent("language", Optional.ofNullable(everythingRequest.getLanguage()))
                        .queryParamIfPresent("sortBy", Optional.ofNullable(everythingRequest.getSortBy()))
                        .queryParamIfPresent("pageSize", Optional.ofNullable(everythingRequest.getPageSize()))
                        .queryParamIfPresent("page", Optional.ofNullable(everythingRequest.getPage()))
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