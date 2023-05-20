package main

import (
	"context"
	"errors"
)

var errEmptyResultSet = errors.New("query or statement produced empty result")

type todo struct {
	Id          int64  `json:"id"`
	Description string `json:"description"`
	Details     string `json:"details"`
	Done        bool   `json:"done"`
}

type todoStore interface {
	find(ctx context.Context, id int) (todo, error)
	list(ctx context.Context, offset int, limit int) ([]todo, error)
	create(ctx context.Context, item todo) (todo, error)
	update(ctx context.Context, item todo) (todo, error)
	delete(ctx context.Context, id int) error
	ping(ctx context.Context) error
}
