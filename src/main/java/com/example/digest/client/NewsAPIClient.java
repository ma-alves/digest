package com.example.digest.client;

import com.example.digest.models.request.NewsAPIRequest;
import com.example.digest.models.response.NewsAPIResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.util.UriComponentsBuilder;

import java.util.List;

/**
 * Spring Boot client for NewsAPI.org
 * Set your key in application.properties: newsapi.api-key=your_key_here
 */
@Service
public class NewsAPIClient {

    private static final String BASE_URL = "https://newsapi.org/v2";

    private final WebClient webClient;

    public NewsAPIClient(@Value("${newsapi.api-key}") String apiKey) {
        this.webClient = WebClient.builder()
                .baseUrl(BASE_URL)
                .defaultHeader("X-Api-Key", apiKey)
                .build();
    }

    // ──────────────────────────────────────────────
    // /v2/top-headlines
    // ──────────────────────────────────────────────

    public NewsAPIResponse getTopHeadlines(NewsAPIRequest request) {
        UriComponentsBuilder uri = UriComponentsBuilder.fromPath("/top-headlines");
        if (request.getCountry()  != null) uri.queryParam("country",  request.getCountry());
        if (request.getCategory() != null) uri.queryParam("category", request.getCategory());
        if (request.getSources()  != null) uri.queryParam("sources",  request.getSources());
        if (request.getQ()        != null) uri.queryParam("q",        request.getQ());
        if (request.getPageSize() != null) uri.queryParam("pageSize", request.getPageSize());
        if (request.getPage()     != null) uri.queryParam("page",     request.getPage());

        return fetch(uri.toUriString());
    }

    // ──────────────────────────────────────────────
    // /v2/everything
    // ──────────────────────────────────────────────

    public NewsAPIResponse getEverything(NewsAPIRequest request) {
        UriComponentsBuilder uri = UriComponentsBuilder.fromPath("/everything");
        if (request.getCountry()  != null) uri.queryParam("country",  request.getCountry());
        if (request.getCategory() != null) uri.queryParam("category", request.getCategory());
        if (request.getSources()  != null) uri.queryParam("sources",  request.getSources());
        if (request.getQ()        != null) uri.queryParam("q",        request.getQ());
        if (request.getPageSize() != null) uri.queryParam("pageSize", request.getPageSize());
        if (request.getPage()     != null) uri.queryParam("page",     request.getPage());

        return fetch(uri.toUriString());
    }

    // ──────────────────────────────────────────────
    // /v2/sources
    // ──────────────────────────────────────────────

    public NewsAPIResponse getSources(NewsAPIRequest request) {
        UriComponentsBuilder uri = UriComponentsBuilder.fromPath("/top-headlines/sources");
        if (request.getCountry()  != null) uri.queryParam("country",  request.getCountry());
        if (request.getCategory() != null) uri.queryParam("category", request.getCategory());

        return fetch(uri.toUriString());
    }

    // ──────────────────────────────────────────────
    // Convenience helpers
    // ──────────────────────────────────────────────

    /** Quick shortcut: top US headlines */
    public NewsAPIResponse getUsHeadlines() {
        return getTopHeadlines(new NewsAPIRequest("us", "general", 10));
    }

    /** Quick shortcut: search everything by keyword */
    public NewsAPIResponse searchEverything(String keyword) {
        NewsAPIRequest request = new NewsAPIRequest("us", "general", 20);
        request.setQ(keyword);
        return getEverything(request);
    }

    /** Extract the articles list from a response for convenience */
    public List<com.example.digest.models.response.Article> extractArticles(NewsAPIResponse response) {
        return response.getArticles() != null ? response.getArticles() : List.of();
    }

    // ──────────────────────────────────────────────
    // Internal
    // ──────────────────────────────────────────────

    private NewsAPIResponse fetch(String uri) {
        return webClient.get()
                .uri(uri)
                .retrieve()
                .bodyToMono(NewsAPIResponse.class)
                .block();
    }
}