package router_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	pg "github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/postgres"
	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/router"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
)

func runPostgres(ctx context.Context, img string) (*postgres.PostgresContainer, error) {
	path := filepath.Join("..", "..", "migrations")
	entries, err := os.ReadDir(path)
	if err != nil {
		return nil, err
	}
	var initScripts []string
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".up.sql") {
			continue
		}
		initScripts = append(initScripts, filepath.Join(path, entry.Name()))
	}
	// Sort initScripts by filename.
	// This is important to ensure that the migrations are applied in the correct order.
	slices.SortFunc(entries, func(i, j os.DirEntry) int {
		return strings.Compare(i.Name(), j.Name())
	})
	pg, err := postgres.Run(ctx, img,
		postgres.WithDatabase("todo-test"), postgres.WithUsername("postgres"),
		postgres.WithPassword("postgres"), postgres.WithOrderedInitScripts(initScripts...),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").WithOccurrence(2).WithStartupTimeout(5*time.Second)))
	return pg, err
}

func TestGetManyTodo(t *testing.T) {
	ctx := context.Background()
	pgContainer, err := runPostgres(ctx, "postgres:16-alpine")
	if err != nil {
		t.Fatalf("failed to initialize Postgres container: %v", err)
	}
	t.Cleanup(func() {
		if err := pgContainer.Terminate(ctx); err != nil {
			t.Errorf("failed to terminate Postgres container: %v", err)
		}
	})

	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("failed to get connection string: %v", err)
	}

	tests := []struct {
		name  string
		limit string
		count int
		want  int
	}{
		{
			name:  "get_todo_all",
			limit: "",
			count: 3,
			want:  http.StatusOK,
		},
		{
			name:  "get_todo_limit_1",
			limit: "1",
			count: 1,
			want:  http.StatusOK,
		},
		{
			name:  "get_todo_limit_2",
			limit: "2",
			count: 2,
			want:  http.StatusOK,
		},
		{
			name:  "get_todo_limit_100",
			limit: "100",
			count: 3,
			want:  http.StatusOK,
		},
		{
			name:  "get_todo_limit_-1",
			limit: "-1",
			count: 3,
			want:  http.StatusOK,
		},
		{
			name:  "get_todo_limit_x",
			limit: "x",
			count: 3,
			want:  http.StatusOK,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			ts, err := pg.NewStore(ctx, connStr)
			if err != nil {
				t.Fatalf("failed to create TodoStore: %v", err)
			}
			t.Cleanup(func() {
				ts.Close(ctx)
			})

			srv := httptest.NewServer(router.NewMux(ts))
			t.Cleanup(func() {
				srv.Close()
			})

			client := srv.Client()
			url := srv.URL + "/todo"
			if tc.limit != "" {
				url = fmt.Sprintf("%s?limit=%s", url, tc.limit)
			}

			resp, err := client.Get(url)
			if err != nil {
				t.Fatalf("failed to get todo: %v", err)
			}
			t.Cleanup(func() {
				resp.Body.Close()
			})

			if resp.StatusCode != tc.want {
				t.Errorf("want status code %d, got %d", tc.want, resp.StatusCode)
			}

			body, err := io.ReadAll(resp.Body)
			if err != nil {
				t.Fatalf("failed to read response body: %v", err)
			}

			items := []json.RawMessage{}
			json.Unmarshal(body, &items) // Just to check if the response is valid JSON
			if err != nil {
				t.Fatalf("failed to unmarshal response body: %v", err)
			}

			if tc.count != len(items) {
				t.Errorf("want %d items, got %d", tc.count, len(items))
			}
		})
	}
}

func TestGetSingleTodo(t *testing.T) {
	ctx := context.Background()
	pgContainer, err := runPostgres(ctx, "postgres:16-alpine")
	if err != nil {
		t.Fatalf("failed to initialize Postgres container: %v", err)
	}
	t.Cleanup(func() {
		if err := pgContainer.Terminate(ctx); err != nil {
			t.Errorf("failed to terminate Postgres container: %v", err)
		}
	})

	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("failed to get connection string: %v", err)
	}

	tests := []struct {
		name string
		id   string
		want int
	}{
		{
			name: "get_todo_1_ok",
			id:   "1",
			want: http.StatusOK,
		},
		{
			name: "get_todo_2_ok",
			id:   "2",
			want: http.StatusOK,
		},
		{
			name: "get_todo_100_not_found",
			id:   "100",
			want: http.StatusNotFound,
		},
		{
			name: "get_todo_-1_not_found",
			id:   "-1",
			want: http.StatusNotFound,
		},
		{
			name: "get_todo_x_not_found",
			id:   "x",
			want: http.StatusNotFound,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			ts, err := pg.NewStore(ctx, connStr)
			if err != nil {
				t.Fatalf("failed to create TodoStore: %v", err)
			}
			t.Cleanup(func() {
				ts.Close(ctx)
			})

			srv := httptest.NewServer(router.NewMux(ts))
			t.Cleanup(func() {
				srv.Close()
			})

			client := srv.Client()
			resp, err := client.Get(srv.URL + "/todo/" + tc.id)
			if err != nil {
				t.Fatalf("failed to get todo: %v", err)
			}
			t.Cleanup(func() {
				resp.Body.Close()
			})

			if resp.StatusCode != tc.want {
				t.Errorf("want status code %d, got %d", tc.want, resp.StatusCode)
			}

			if resp.StatusCode == http.StatusOK {
				body, err := io.ReadAll(resp.Body)
				if err != nil {
					t.Fatalf("failed to read response body: %v", err)
				}
				var item json.RawMessage
				if err := json.Unmarshal(body, &item); err != nil {
					t.Errorf("failed to unmarshal response body: %v", err)
				}
			}
		})
	}
}

func TestPostTodo(t *testing.T) {
	ctx := context.Background()
	pgContainer, err := runPostgres(ctx, "postgres:16-alpine")
	if err != nil {
		t.Fatalf("failed to initialize Postgres container: %v", err)
	}
	t.Cleanup(func() {
		if err := pgContainer.Terminate(ctx); err != nil {
			t.Errorf("failed to terminate Postgres container: %v", err)
		}
	})

	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("failed to get connection string: %v", err)
	}

	tests := []struct {
		name        string
		item        json.RawMessage // Use json.RawMessage to handle arbitrary JSON input
		contentType string
		want        int
	}{
		{
			name:        "post_todo_1_created",
			item:        []byte(`{"description": "New todo 1", "details": "This is a test todo item", "done":false}`),
			contentType: "application/json",
			want:        http.StatusCreated,
		},
		{
			name:        "post_todo_2_created",
			item:        []byte(`{"description": "New todo 2", "details": "This is a test todo item", "done":true}`),
			contentType: "application/json",
			want:        http.StatusCreated,
		},
		{
			name:        "post_todo_unsupported_media_type",
			item:        []byte(`{"description": "New todo 3", "details": "This is a test todo item", "done":true}`),
			contentType: "application/text",
			want:        http.StatusUnsupportedMediaType,
		},
		{
			name:        "post_todo_json_syntax_error",
			item:        []byte(`{"description": "New todo 4", "details": "This is a test todo item", "done":true, }`),
			contentType: "application/json",
			want:        http.StatusBadRequest,
		},
		{
			name:        "post_todo_json_extra_field",
			item:        []byte(`{"description": "New todo 4", "details": "This is a test todo item", "done":true, "extraField": "unexpected"}`),
			contentType: "application/json",
			want:        http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			ts, err := pg.NewStore(ctx, connStr)
			if err != nil {
				t.Fatalf("failed to create TodoStore: %v", err)
			}
			t.Cleanup(func() {
				ts.Close(ctx)
			})

			srv := httptest.NewServer(router.NewMux(ts))
			t.Cleanup(func() {
				srv.Close()
			})

			client := srv.Client()
			resp, err := client.Post(srv.URL+"/todo", tc.contentType, bytes.NewBuffer(tc.item))
			if err != nil {
				t.Fatalf("failed to post todo: %v", err)
			}
			t.Cleanup(func() {
				resp.Body.Close()
			})

			if resp.StatusCode != tc.want {
				t.Errorf("want status code %d, got %d", tc.want, resp.StatusCode)
			}
		})
	}
}

func TestPutTodo(t *testing.T) {
	ctx := context.Background()
	pgContainer, err := runPostgres(ctx, "postgres:16-alpine")
	if err != nil {
		t.Fatalf("failed to initialize Postgres container: %v", err)
	}
	t.Cleanup(func() {
		if err := pgContainer.Terminate(ctx); err != nil {
			t.Errorf("failed to terminate Postgres container: %v", err)
		}
	})

	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("failed to get connection string: %v", err)
	}

	tests := []struct {
		name        string
		id          string
		item        json.RawMessage // Use json.RawMessage to handle arbitrary JSON input
		contentType string
		want        int
	}{
		{
			name:        "put_todo_1_ok",
			id:          "1",
			item:        []byte(`{"id":1, "description": "Update todo 1", "details": "This is a test todo item", "done":false}`),
			contentType: "application/json",
			want:        http.StatusOK,
		},
		{
			name:        "put_todo_2_ok_no_id_in_body",
			id:          "2",
			item:        []byte(`{"description": "Update todo 2", "details": "This is a test todo item", "done":true}`),
			contentType: "application/json",
			want:        http.StatusOK,
		},
		{
			name:        "put_todo_unsupported_media_type",
			id:          "1",
			item:        []byte(`{"id": 1, "description": "Update todo 1", "details": "This is a test todo item", "done":true}`),
			contentType: "application/text",
			want:        http.StatusUnsupportedMediaType,
		},
		{
			name:        "put_todo_json_syntax_error",
			id:          "1",
			item:        []byte(`{"id": 1, "description": "Update todo 1", "details": "This is a test todo item", "done":true, }`),
			contentType: "application/json",
			want:        http.StatusBadRequest,
		},
		{
			name:        "put_todo_json_extra_field",
			id:          "1",
			item:        []byte(`{"id": 1, "description": "New todo 4", "details": "This is a test todo item", "done":true, "extraField": "unexpected"}`),
			contentType: "application/json",
			want:        http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			ts, err := pg.NewStore(ctx, connStr)
			if err != nil {
				t.Fatalf("failed to create TodoStore: %v", err)
			}
			t.Cleanup(func() {
				ts.Close(ctx)
			})

			srv := httptest.NewServer(router.NewMux(ts))
			t.Cleanup(func() {
				srv.Close()
			})

			client := srv.Client()
			req, err := http.NewRequest(http.MethodPut, srv.URL+"/todo/"+tc.id, bytes.NewBuffer(tc.item))
			if err != nil {
				t.Fatalf("failed to create request: %v", err)
			}
			req.Header.Set("Content-Type", tc.contentType)

			resp, err := client.Do(req)
			if err != nil {
				t.Fatalf("failed to post todo: %v", err)
			}
			t.Cleanup(func() {
				resp.Body.Close()
			})

			if resp.StatusCode != tc.want {
				t.Errorf("want status code %d, got %d", tc.want, resp.StatusCode)
			}

			if resp.StatusCode == http.StatusOK {
				body, err := io.ReadAll(resp.Body)
				if err != nil {
					t.Fatalf("failed to read response body: %v", err)
				}
				var item json.RawMessage
				if err := json.Unmarshal(body, &item); err != nil {
					t.Errorf("failed to unmarshal response body: %v", err)
				}
			}
		})
	}
}

func TestDeleteTodo(t *testing.T) {
	ctx := context.Background()
	pgContainer, err := runPostgres(ctx, "postgres:16-alpine")
	if err != nil {
		t.Fatalf("failed to initialize Postgres container: %v", err)
	}
	t.Cleanup(func() {
		if err := pgContainer.Terminate(ctx); err != nil {
			t.Errorf("failed to terminate Postgres container: %v", err)
		}
	})

	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("failed to get connection string: %v", err)
	}

	tests := []struct {
		name string
		id   string
		want int
	}{
		{
			name: "delete_todo_1_no_content",
			id:   "1",
			want: http.StatusNoContent,
		},
		{
			name: "delete_todo_100_not_found",
			id:   "100",
			want: http.StatusNotFound,
		},
		{
			name: "delete_todo_-1_not_found",
			id:   "-1",
			want: http.StatusNotFound,
		},
		{
			name: "delete_todo_x_not_found",
			id:   "x",
			want: http.StatusNotFound,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			ts, err := pg.NewStore(ctx, connStr)
			if err != nil {
				t.Fatalf("failed to create TodoStore: %v", err)
			}
			t.Cleanup(func() {
				ts.Close(ctx)
			})

			srv := httptest.NewServer(router.NewMux(ts))
			t.Cleanup(func() {
				srv.Close()
			})

			client := srv.Client()
			req, err := http.NewRequest(http.MethodDelete, srv.URL+"/todo/"+tc.id, nil)
			if err != nil {
				t.Fatalf("failed to create request: %v", err)
			}
			resp, err := client.Do(req)
			if err != nil {
				t.Fatalf("failed to post todo: %v", err)
			}
			t.Cleanup(func() {
				resp.Body.Close()
			})

			if resp.StatusCode != tc.want {
				t.Errorf("want status code %d, got %d", tc.want, resp.StatusCode)
			}
		})
	}
}
