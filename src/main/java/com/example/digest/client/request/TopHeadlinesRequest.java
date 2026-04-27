package com.example.digest.client.request;

import lombok.*;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TopHeadlinesRequest {

    private String country;

    private String category;

    private String sources;

    private String q;

    private Integer pageSize;

    private Integer page;
}