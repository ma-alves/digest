package com.example.digest.config;

import io.github.cdimascio.dotenv.Dotenv;
import org.springframework.context.annotation.Configuration;

import java.nio.file.Files;
import java.nio.file.Paths;

/**
 * Loads environment variables from .env file at application startup.
 * This runs before Spring context initialization, making .env vars available
 * to application.properties property resolution.
 */
@Configuration
public class DotenvConfig {

    static {
        // Load .env file if it exists
        String envPath = ".env";
        if (Files.exists(Paths.get(envPath))) {
            Dotenv dotenv = Dotenv.configure()
                    .ignoreIfMissing()
                    .load();
            
            // Set all variables from .env as system properties
            dotenv.entries().forEach(entry -> {
                if (System.getProperty(entry.getKey()) == null) {
                    System.setProperty(entry.getKey(), entry.getValue());
                }
            });
        }
    }
}
