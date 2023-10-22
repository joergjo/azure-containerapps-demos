package model

import (
	"context"
	"errors"
)

var ErrEmptyResultSet = errors.New("query or statement produced empty result")

type Todo struct {
	Id          int64  `json:"id"`
	Description string `json:"description"`
	Details     string `json:"details"`
	Done        bool   `json:"done"`
}

type TodoStore interface {
	Find(ctx context.Context, id int) (Todo, error)
	List(ctx context.Context, offset int, limit int) ([]Todo, error)
	Create(ctx context.Context, item Todo) (Todo, error)
	Update(ctx context.Context, item Todo) (Todo, error)
	Delete(ctx context.Context, id int) error
	Ping(ctx context.Context) error
}
