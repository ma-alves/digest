package com.example.digest.models.request;

import lombok.*;

@Getter
@Setter
@RequiredArgsConstructor
public class NewsAPIRequest {

    @NonNull
    private String country;

    @NonNull
    private String category;

    private String sources;
    private String q;

    @NonNull
    private Integer pageSize;

    private Integer page;
}