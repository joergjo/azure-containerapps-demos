package router

import (
	"bytes"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/model"
)

func TestRespond(t *testing.T) {
	type args struct {
		data   any
		header []header
		body   string
	}
	tests := []struct {
		name string
		args
	}{
		{
			name: "single_todo_no_header",
			args: args{
				data:   model.Todo{Id: 1, Description: "test", Details: "a test", Done: false},
				header: nil,
				body:   `{"id":1,"description":"test","details":"a test","done":false}`,
			},
		},
		{
			name: "single_todo_location_header",
			args: args{
				data:   model.Todo{Id: 1, Description: "test", Details: "a test", Done: false},
				header: []header{{name: "Location", val: "/todo/1"}},
				body:   `{"id":1,"description":"test","details":"a test","done":false}`,
			},
		},
		{
			name: "single_todo_multiple_headers",
			args: args{
				data: model.Todo{Id: 1, Description: "test", Details: "a test", Done: false},
				header: []header{
					{name: "Location", val: "/todo/1"},
					{name: "Cache-Control", val: "no-cache"},
				},
				body: `{"id":1,"description":"test","details":"a test","done":false}`,
			},
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rec := httptest.NewRecorder()
			respond(rec, tc.data, http.StatusOK, tc.header...)
			res := rec.Result()
			if res.StatusCode != http.StatusOK {
				t.Errorf("Want HTTP 200 OK, got %v", rec.Code)
			}
			if ct := res.Header.Get("Content-Type"); ct != "application/json" {
				t.Errorf("Want application/json, go %q", ct)
			}
			for _, h := range tc.header {
				hv := res.Header.Get(h.name)
				if hv != h.val {
					t.Errorf("Want HTTP header %q with value %q, got %q", h.name, h.val, hv)
				}
			}
			b, err := io.ReadAll(res.Body)
			if err != nil {
				t.Fatalf("Fatal error reading response body: %v", err)
			}
			body := string(b)
			if body != tc.body {
				t.Errorf("Want response body %q, got %q", tc.body, body)
			}
		})
	}
}

func TestBind(t *testing.T) {
	objTests := []bindTestCase[model.Todo]{
		{
			name: "bind_todo_object",
			args: bindTestArgs[model.Todo]{
				body:   `{"id":1,"description":"test","details":"a test","done":false}`,
				target: model.Todo{},
			},
			wantErr: false,
		},
		{
			name: "bind_invalid_type",
			args: bindTestArgs[model.Todo]{
				body:   `{"foo":"fail"}`,
				target: model.Todo{},
			},
			wantErr: true,
		},
		{
			name: "bind_null",
			args: bindTestArgs[model.Todo]{
				body:   `null`,
				target: model.Todo{},
			},
			wantErr: false,
		},
	}
	sliceTests := []bindTestCase[[]model.Todo]{
		{
			name: "bind_todo_array",
			args: bindTestArgs[[]model.Todo]{
				body:   `[{"id":1,"description":"test","details":"a test","done":false},{"id":2,"description":"test 2","details":"another test","done":false}]`,
				target: []model.Todo{},
			},
			wantErr: false,
		},
		{
			name: "bind_empty_array",
			args: bindTestArgs[[]model.Todo]{
				body:   `[]`,
				target: []model.Todo{},
			},
			wantErr: false,
		},
		{
			name: "bind_invalid_type",
			args: bindTestArgs[[]model.Todo]{
				body:   `{"foo":"fail"}`,
				target: []model.Todo{},
			},
			wantErr: true,
		},
	}
	testBind(t, objTests...)
	testBind(t, sliceTests...)
}

type bindTestArgs[T any] struct {
	body   string
	target T
}

type bindTestCase[T any] struct {
	name    string
	args    bindTestArgs[T]
	wantErr bool
}

// testBind uses generics to support JSON marshalling to a concrete type. If we were to call
// bind(req, &tc.args.target) with tc.args.target of type any, this would result in a map.
func testBind[T any](t *testing.T, tests ...bindTestCase[T]) {
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var buf bytes.Buffer
			buf.WriteString(tc.args.body)
			req := httptest.NewRequest(http.MethodPost, "/", &buf)
			if err := bind(req, &tc.args.target); (err != nil) != tc.wantErr {
				t.Errorf("Want error %v, got error %v", tc.wantErr, err)
			}
		})
	}
}
