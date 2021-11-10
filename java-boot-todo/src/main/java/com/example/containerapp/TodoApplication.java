package com.example.containerapp;

import java.util.Arrays;

import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Profile;

@SpringBootApplication
public class TodoApplication {

    public static void main(String[] args) {
        SpringApplication.run(TodoApplication.class, args);
    }

    @Profile("dev")
    @Bean
    public CommandLineRunner init(TodoRepository repository) {
        return args -> {
            var entities = Arrays.asList(
                    new Todo("configuration", "congratulations, you have set up your Azure Container App correctly!",
                            false),
                    new Todo("test", "check if this is working", false),
                    new Todo("demo", "show to friends and family", false));
            repository.deleteAll();
            repository.saveAll(entities);
        };
    }
}
