package router

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/model"
)

type mockTodoStore struct {
	findFn   func(ctx context.Context, id int) (model.Todo, error)
	listFn   func(ctx context.Context, offset int, limit int) ([]model.Todo, error)
	createFn func(ctx context.Context, item model.Todo) (model.Todo, error)
	updateFn func(ctx context.Context, item model.Todo) (model.Todo, error)
	deleteFn func(ctx context.Context, id int) error
	pingFn   func(ctx context.Context) error
}

func (m *mockTodoStore) Find(ctx context.Context, id int) (model.Todo, error) {
	return m.findFn(ctx, id)
}

func (m *mockTodoStore) List(ctx context.Context, offset int, limit int) ([]model.Todo, error) {
	return m.listFn(ctx, offset, limit)
}

func (m *mockTodoStore) Create(ctx context.Context, item model.Todo) (model.Todo, error) {
	return m.createFn(ctx, item)
}

func (m *mockTodoStore) Update(ctx context.Context, item model.Todo) (model.Todo, error) {
	return m.updateFn(ctx, item)
}

func (m *mockTodoStore) Delete(ctx context.Context, id int) error {
	return m.deleteFn(ctx, id)
}

func (m *mockTodoStore) Ping(ctx context.Context) error {
	return m.pingFn(ctx)
}

func TestGetManyBooks(t *testing.T) {
	tests := []struct {
		name   string
		err    error
		result []model.Todo
		want   int
	}{
		{
			name: "get_many_books_three",
			err:  nil,
			result: []model.Todo{
				{
					Id:          1,
					Description: "test1",
					Details:     "test1",
					Done:        false,
				},
				{
					Id:          2,
					Description: "test2",
					Details:     "test2",
					Done:        false,
				},
				{
					Id:          3,
					Description: "test3",
					Details:     "test3",
					Done:        false,
				},
			},
			want: http.StatusOK,
		},
		{
			name: "get_many_books_one",
			err:  nil,
			result: []model.Todo{
				{
					Id:          1,
					Description: "test1",
					Details:     "test1",
					Done:        false,
				},
			},
			want: http.StatusOK,
		},
		{
			name:   "get_many_books_none",
			err:    nil,
			result: []model.Todo{},
			want:   http.StatusOK,
		},
		// TODO: Verify nil behavior
		{
			name:   "get_many_books_nil",
			err:    nil,
			result: nil,
			want:   http.StatusOK,
		},
		{
			name:   "get_many_books_error",
			err:    errors.New("test error"),
			result: nil,
			want:   http.StatusInternalServerError,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			r := httptest.NewRequest(http.MethodGet, "/todo", nil)
			ts := &mockTodoStore{
				listFn: func(ctx context.Context, offset int, limit int) ([]model.Todo, error) {
					return tc.result, nil
				},
			}
			getManyHandler(ts).ServeHTTP(w, r)
			got := w.Result().StatusCode
			want := http.StatusOK
			if got != want {
				t.Fatalf("Want status code %d, got %d", want, got)
			}

		})
	}
}

func TestGetBook(t *testing.T) {
	tests := []struct {
		name   string
		result model.Todo
		err    error
		want   int
	}{
		{
			name: "get_single_book",
			result: model.Todo{
				Id:          1,
				Description: "test1",
				Details:     "test1",
				Done:        false,
			},
			err:  nil,
			want: http.StatusOK,
		},
		{
			name:   "get_single_book_not_found",
			result: model.Todo{},
			err:    model.ErrEmptyResultSet,
			want:   http.StatusNotFound,
		},
		{
			name:   "get_single_book_error",
			result: model.Todo{},
			err:    errors.New("test error"),
			want:   http.StatusInternalServerError,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			r := httptest.NewRequest(http.MethodGet, "/todo/1", nil)
			ts := &mockTodoStore{
				findFn: func(ctx context.Context, id int) (model.Todo, error) {
					return tc.result, tc.err
				},
			}
			getHandler(ts).ServeHTTP(w, r)
			if got := w.Result().StatusCode; got != tc.want {
				t.Fatalf("Want status code %d, got %d", tc.want, got)
			}
		})
	}
}

func TestPostBook(t *testing.T) {
	invalid := struct {
		Id          int    `json:"id"`
		Title       string `json:"title"`
		IsCompleted bool   `json:"isCompleted"`
	}{
		Id:          0,
		Title:       "test",
		IsCompleted: false,
	}
	tests := []struct {
		name string
		in   any
		err  error
		want int
	}{
		{
			name: "post_book",
			in: &model.Todo{
				Id:          0,
				Description: "test1",
				Details:     "test1",
				Done:        false,
			},
			err:  nil,
			want: http.StatusCreated,
		},
		{
			name: "post_book_error",
			in: &model.Todo{
				Id:          0,
				Description: "test1",
				Details:     "test1",
				Done:        false,
			},
			err:  errors.New("test error"),
			want: http.StatusInternalServerError,
		},
		{
			name: "post_book_invalid",
			in:   &invalid,
			err:  nil,
			want: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			var buf *bytes.Buffer
			if tc.in != nil {
				b, err := json.Marshal(tc.in)
				if err != nil {
					t.Fatalf("marshalling input: %v", err)
				}
				buf = bytes.NewBuffer(b)
			}
			r := httptest.NewRequest(http.MethodPost, "/todo", buf)
			r.Header.Set("Content-Type", "application/json")
			ts := &mockTodoStore{
				createFn: func(ctx context.Context, item model.Todo) (model.Todo, error) {
					return item, tc.err
				},
			}
			mux := NewMux(ts)
			mux.ServeHTTP(w, r)
			if got := w.Result().StatusCode; got != tc.want {
				t.Fatalf("Want status code %d, got %d", tc.want, got)
			}
		})
	}
}

func TestPutBook(t *testing.T) {
	invalid := struct {
		Id          int    `json:"id"`
		Title       string `json:"title"`
		IsCompleted bool   `json:"isCompleted"`
	}{
		Id:          0,
		Title:       "test",
		IsCompleted: false,
	}
	tests := []struct {
		name string
		in   any
		err  error
		want int
	}{
		{
			name: "put_book",
			in: &model.Todo{
				Id:          0,
				Description: "test1",
				Details:     "test1",
				Done:        false,
			},
			err:  nil,
			want: http.StatusOK,
		},
		{
			name: "put_book_error",
			in: &model.Todo{
				Id:          0,
				Description: "test1",
				Details:     "test1",
				Done:        false,
			},
			err:  errors.New("test error"),
			want: http.StatusInternalServerError,
		},
		{
			name: "put_book_invalid",
			in:   &invalid,
			err:  nil,
			want: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			var buf *bytes.Buffer
			if tc.in != nil {
				b, err := json.Marshal(tc.in)
				if err != nil {
					t.Fatalf("marshalling input: %v", err)
				}
				buf = bytes.NewBuffer(b)
			}
			r := httptest.NewRequest(http.MethodPut, "/todo/1", buf)
			r.Header.Set("Content-Type", "application/json")
			ts := &mockTodoStore{
				updateFn: func(ctx context.Context, item model.Todo) (model.Todo, error) {
					return item, tc.err
				},
			}
			mux := NewMux(ts)
			mux.ServeHTTP(w, r)
			if got := w.Result().StatusCode; got != tc.want {
				t.Fatalf("Want status code %d, got %d", tc.want, got)
			}
		})
	}
}

func TestDeleteBook(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want int
	}{
		{
			name: "delete_book",
			err:  nil,
			want: http.StatusNoContent,
		},
		{
			name: "delete_book_not_found",
			err:  model.ErrEmptyResultSet,
			want: http.StatusNotFound,
		},
		{
			name: "delete_book_error",
			err:  errors.New("test error"),
			want: http.StatusInternalServerError,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			r := httptest.NewRequest(http.MethodDelete, "/todo/1", nil)
			ts := &mockTodoStore{
				deleteFn: func(ctx context.Context, id int) error {
					return tc.err
				},
			}
			mux := NewMux(ts)
			mux.ServeHTTP(w, r)
			if got := w.Result().StatusCode; got != tc.want {
				t.Fatalf("Want status code %d, got %d", tc.want, got)
			}
		})
	}
}

func TestURLParams(t *testing.T) {
	tests := []struct {
		name  string
		param string
		want  int
	}{
		{
			name:  "string_param",
			param: "abCD",
			want:  http.StatusNotFound,
		},
		{
			name:  "negative_int_param",
			param: "-1",
			want:  http.StatusNotFound,
		},
		{
			name:  "float_param",
			param: "1.1",
			want:  http.StatusNotFound,
		},
		{
			name:  "leading_zero_param",
			param: "0123",
			want:  http.StatusOK,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			r := httptest.NewRequest(http.MethodGet, "/todo/"+tc.param, nil)
			ts := &mockTodoStore{
				findFn: func(ctx context.Context, id int) (model.Todo, error) {
					return model.Todo{}, nil
				},
			}
			mux := NewMux(ts)
			mux.ServeHTTP(w, r)
			if got := w.Result().StatusCode; got != tc.want {
				t.Fatalf("Want status code %d, got %d", tc.want, got)
			}
		})
	}
}

func TestLiveness(t *testing.T) {
	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodGet, "/healthz/live", nil)
	ts := &mockTodoStore{}
	mux := NewMux(ts)
	mux.ServeHTTP(w, r)
	want := http.StatusOK
	if got := w.Result().StatusCode; got != want {
		t.Fatalf("Want status code %d, got %d", want, got)
	}
}

func TestReadiness(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want int
	}{
		{
			name: "ready",
			err:  nil,
			want: http.StatusOK,
		},
		{
			name: "ready_down",
			err:  errors.New("test error"),
			want: http.StatusInternalServerError,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			r := httptest.NewRequest(http.MethodGet, "/healthz/ready", nil)
			ts := &mockTodoStore{
				pingFn: func(ctx context.Context) error {
					return tc.err
				},
			}
			mux := NewMux(ts)
			mux.ServeHTTP(w, r)
			if got := w.Result().StatusCode; got != tc.want {
				t.Fatalf("Want status code %d, got %d", tc.want, got)
			}
		})
	}
}
