package com.example.digest.models.request;

import lombok.*;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NewsAPIRequest {

    private String country;

    private String category;

    private String sources;

    private String q;

    private Integer pageSize;

    private Integer page;
}