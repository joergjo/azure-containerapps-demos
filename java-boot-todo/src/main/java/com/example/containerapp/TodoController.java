package com.example.containerapp;

import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/")
public class TodoController {
    private final TodoRepository todoRepository;
    private final Logger logger = LoggerFactory.getLogger(TodoController.class);

    public TodoController(TodoRepository todoRepository) {
        this.todoRepository = todoRepository;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Todo createTodo(@RequestBody Todo todo) {
        var newTodo = todoRepository.save(todo);
        logger.info("Created new todo {}", newTodo.getId());
        return newTodo;
    }

    @GetMapping
    public Iterable<Todo> getTodos() {
        logger.info("Querying all todos");
        return todoRepository.findAll();
    }

    @GetMapping("{id}")
    public Optional<Todo> getTodo(@PathVariable Long id) {
        logger.info("Querying todo {}", id);
        var todo = todoRepository.findById(id);
        if (todo.isEmpty()) {
            logger.info("Todo {} not found", id);
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
        return todo;
    }

    @ResponseStatus(HttpStatus.NO_CONTENT)
    @DeleteMapping("{id}")
    public void deleteTodo(@PathVariable Long id) {
        if (!todoRepository.existsById(id)) {
            logger.info("Todo {} not found", id);
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
        logger.info("Deleting todo {}", id);
        todoRepository.deleteById(id);
    }
}