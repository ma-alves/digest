package com.example.digest.models.request;

import lombok.*;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EverythingRequest {

    private String q;

    private String sources;

    private String domains;

    private String excludeDomains;

    private String from;

    private String to;

    private String language;

    private String sortBy;

    private Integer pageSize;

    private Integer page;
}
