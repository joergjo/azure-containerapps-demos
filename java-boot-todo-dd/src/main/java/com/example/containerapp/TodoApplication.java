package com.example.containerapp;

import java.util.Arrays;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Profile;

@SpringBootApplication
public class TodoApplication {
    private static Logger logger = LoggerFactory.getLogger(TodoApplication.class);

    public static void main(String[] args) {
        SpringApplication.run(TodoApplication.class, args);
    }

    // This is a convenience feature to seed some test data. This obviously might
    // lead to duplicte data depending on the numbers of replicas starting up at the
    // same time if the database is etill empty.
    // Disable this feature by activating the "prod" profile.
    @Profile("!prod")
    @Bean
    public CommandLineRunner init(TodoRepository repository) {
        return args -> {
            if (repository.count() == 0) {
                logger.info("Seeding database");
                var entities = Arrays.asList(
                        new Todo("configuration",
                                "congratulations, you have set up your Azure Container App correctly!",
                                false),
                        new Todo("test", "check if this is working", false),
                        new Todo("demo", "show to friends and family", false));
                repository.saveAll(entities);
            } else {
                logger.info("Database already seeded");
            }
        };
    }
}
