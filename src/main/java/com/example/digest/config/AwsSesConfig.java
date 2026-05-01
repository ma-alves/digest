package com.example.digest.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.ses.SesClient;

import java.net.URI;

@Configuration
public class AwsSesConfig {

    @Value("${aws.ses.endpoint:}")
    private String endpoint;

    @Value("${aws.ses.region:us-east-1}")
    private String region;

    @Value("${aws.ses.access-key:}")
    private String accessKey;

    @Value("${aws.ses.secret-key:}")
    private String secretKey;

    @Bean
    public SesClient sesClient() {
        var builder = SesClient.builder()
                .region(Region.of(region));

        // For LocalStack development
        if (endpoint != null && !endpoint.isBlank()) {
            builder.endpointOverride(URI.create(endpoint));

            // LocalStack credentials
            if ((accessKey != null && !accessKey.isBlank()) &&
                    (secretKey != null && !secretKey.isBlank())) {
                builder.credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKey, secretKey)
                ));
            }
        }

        return builder.build();
    }
}
